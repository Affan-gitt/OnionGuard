import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/models/sensor_reading.dart';
import 'storage_service.dart';
import 'usb_serial_service.dart' show CommandAckResult;

enum WifiConnectionState {
  disconnected,
  connecting,
  connected;

  String get displayName {
    switch (this) {
      case WifiConnectionState.disconnected:
        return 'DISCONNECTED';
      case WifiConnectionState.connecting:
        return 'CONNECTING...';
      case WifiConnectionState.connected:
        return 'CONNECTED (WI-FI)';
    }
  }
}

class WifiEsp32Service {
  final StorageService _storageService;

  WifiConnectionState _state = WifiConnectionState.disconnected;
  String _espIp = '192.168.4.1';
  int _port = 80;

  Timer? _pollTimer;
  int _consecutiveFailures = 0;
  DateTime? _lastPollTime;

  final StreamController<WifiConnectionState> _connStateController =
      StreamController<WifiConnectionState>.broadcast();
  final StreamController<SensorReading> _sensorDataController =
      StreamController<SensorReading>.broadcast();

  WifiEsp32Service(this._storageService) {
    final settings = _storageService.getSettings();
    _espIp = settings.espWifiIp.isNotEmpty ? settings.espWifiIp : '192.168.4.1';
  }

  WifiConnectionState get state => _state;
  bool get isConnected => _state == WifiConnectionState.connected;
  String get espIp => _espIp;
  int get port => _port;
  DateTime? get lastPollTime => _lastPollTime;

  Stream<WifiConnectionState> get connectionStateStream => _connStateController.stream;
  Stream<SensorReading> get sensorDataStream => _sensorDataController.stream;

  /// Attempts to connect to the ESP32 Wi-Fi HTTP API
  Future<bool> connect({String? ip, int? port}) async {
    if (ip != null && ip.trim().isNotEmpty) {
      _espIp = ip.trim();
    }
    if (port != null && port > 0) {
      _port = port;
    }

    _setState(WifiConnectionState.connecting);

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      final url = Uri.parse('http://$_espIp:$_port/api/sensors');
      final req = await client.getUrl(url);
      final resp = await req.close();

      if (resp.statusCode == HttpStatus.ok) {
        final body = await resp.transform(utf8.decoder).join();
        client.close();

        _consecutiveFailures = 0;
        _setState(WifiConnectionState.connected);
        _parseAndEmitSensorJson(body);

        _startPeriodicPolling();

        // Save IP to persistent settings
        final currentSettings = _storageService.getSettings();
        await _storageService.saveSettings(currentSettings.copyWith(espWifiIp: _espIp));

        return true;
      } else {
        client.close();
        _setState(WifiConnectionState.disconnected);
        return false;
      }
    } catch (e) {
      debugPrint('[WiFi ESP32] Connection failed: $e');
      _setState(WifiConnectionState.disconnected);
      return false;
    }
  }

  void _startPeriodicPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _pollSensors());
  }

  Future<void> _pollSensors() async {
    if (!isConnected) return;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);

      final url = Uri.parse('http://$_espIp:$_port/api/sensors');
      final req = await client.getUrl(url);
      final resp = await req.close();

      if (resp.statusCode == HttpStatus.ok) {
        final body = await resp.transform(utf8.decoder).join();
        client.close();

        _consecutiveFailures = 0;
        _lastPollTime = DateTime.now();
        _parseAndEmitSensorJson(body);
      } else {
        client.close();
        _handlePollFailure();
      }
    } catch (e) {
      _handlePollFailure();
    }
  }

  void _handlePollFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= 3) {
      debugPrint('[WiFi ESP32] 3 consecutive poll failures, disconnecting');
      disconnect();
    }
  }

  void _parseAndEmitSensorJson(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final temp = (json['temperature'] as num?)?.toDouble() ?? 0.0;
      final hum = (json['humidity'] as num?)?.toDouble() ?? 0.0;
      final mq3Raw = (json['mq3_raw'] as num?)?.toInt() ?? 300;

      final settings = _storageService.getSettings();
      final delta = settings.mq3Baseline > 0
          ? ((mq3Raw - settings.mq3Baseline) / settings.mq3Baseline) * 100.0
          : 0.0;

      final reading = SensorReading(
        timestamp: DateTime.now(),
        temperature: temp,
        humidity: hum,
        mq3RawAdc: mq3Raw,
        mq3Baseline: settings.mq3Baseline,
        mq3DeltaPercent: delta,
        fanActive: (json['fan'] as bool?) ?? false,
        humidifierActive: (json['humidifier'] as bool?) ?? false,
        sensorStatus: json['sensor_status'] as String? ?? 'OK',
        isSimulated: false,
      );

      _sensorDataController.add(reading);
    } catch (e) {
      debugPrint('[WiFi ESP32] JSON parse error: $e');
    }
  }

  /// Sends physical actuator command (fan / humidifier) to ESP32 over Wi-Fi HTTP POST
  Future<CommandAckResult> sendActuatorCommand({
    required String device,
    required bool state,
  }) async {
    if (!isConnected) {
      return CommandAckResult(
        success: false,
        device: device,
        requestedState: state,
        actualState: false,
        error: 'HARDWARE DISCONNECTED: ESP32 Wi-Fi not reachable.',
        seq: -1,
      );
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      final url = Uri.parse('http://$_espIp:$_port/api/command');
      final req = await client.postUrl(url);
      req.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'type': 'command',
        'device': device,
        'state': state,
      });

      req.write(payload);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();

      if (resp.statusCode == HttpStatus.ok) {
        final ack = jsonDecode(body) as Map<String, dynamic>;
        final success = ack['success'] as bool? ?? false;
        final actual = ack['actual_state'] as bool? ?? (ack['state'] as bool? ?? state);
        final err = ack['error'] as String?;

        return CommandAckResult(
          success: success,
          device: device,
          requestedState: state,
          actualState: actual,
          error: err,
          seq: 0,
        );
      } else {
        return CommandAckResult(
          success: false,
          device: device,
          requestedState: state,
          actualState: false,
          error: 'HTTP ${resp.statusCode}: $body',
          seq: -1,
        );
      }
    } catch (e) {
      return CommandAckResult(
        success: false,
        device: device,
        requestedState: state,
        actualState: false,
        error: 'Network exception: $e',
        seq: -1,
      );
    }
  }

  void disconnect() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _setState(WifiConnectionState.disconnected);
  }

  void _setState(WifiConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _connStateController.add(newState);
    }
  }

  void dispose() {
    disconnect();
    _connStateController.close();
    _sensorDataController.close();
  }
}
