import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/models/activity_event.dart';
import 'storage_service.dart';
import 'notification_service.dart';

enum UsbConnectionState {
  disconnected,
  permissionRequired,
  connecting,
  connected,
  error,
}

class DiscoveredUsbDevice {
  final String deviceName;
  final int vendorId;
  final int productId;
  final String productName;
  final String manufacturerName;
  final bool isEsp32;
  final bool hasPermission;

  DiscoveredUsbDevice({
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.productName,
    required this.manufacturerName,
    required this.isEsp32,
    required this.hasPermission,
  });

  factory DiscoveredUsbDevice.fromMap(Map<dynamic, dynamic> map) {
    return DiscoveredUsbDevice(
      deviceName: map['deviceName'] as String? ?? 'USB Device',
      vendorId: map['vendorId'] as int? ?? 0,
      productId: map['productId'] as int? ?? 0,
      productName: map['productName'] as String? ?? 'USB Device',
      manufacturerName: map['manufacturerName'] as String? ?? '',
      isEsp32: map['isEsp32'] as bool? ?? false,
      hasPermission: map['hasPermission'] as bool? ?? false,
    );
  }
}

class CommandAckResult {
  final bool success;
  final String device;
  final bool requestedState;
  final bool actualState;
  final String? error;
  final int seq;

  CommandAckResult({
    required this.success,
    required this.device,
    required this.requestedState,
    required this.actualState,
    this.error,
    required this.seq,
  });
}

class UsbSerialService {
  final StorageService _storageService;
  final NotificationService _notificationService;

  static const MethodChannel _methodChannel = MethodChannel('com.onionguard.onionguard/usb');
  static const EventChannel _eventChannel = EventChannel('com.onionguard.onionguard/usb_stream');

  UsbConnectionState _state = UsbConnectionState.disconnected;
  String? _connectedDeviceName;
  String _firmwareVersion = '--';
  DateTime? _lastDataReceivedTimestamp;
  DateTime? _lastHeartbeatTimestamp;
  Timer? _watchdogTimer;

  int _sequenceNumber = 100;
  final Map<int, Completer<CommandAckResult>> _pendingCommandAcks = {};

  final _connectionStateController = StreamController<UsbConnectionState>.broadcast();
  final _sensorDataController = StreamController<SensorReading>.broadcast();
  final _rawJsonStreamController = StreamController<String>.broadcast();
  final _ackController = StreamController<CommandAckResult>.broadcast();

  StreamSubscription? _nativeEventSub;

  UsbSerialService(this._storageService, this._notificationService) {
    _initNativeEventListener();
    _startWatchdog();
  }

  UsbConnectionState get state => _state;
  bool get isConnected => _state == UsbConnectionState.connected;
  String? get connectedDeviceName => _connectedDeviceName;
  String get firmwareVersion => _firmwareVersion;
  DateTime? get lastDataReceivedTimestamp => _lastDataReceivedTimestamp;
  DateTime? get lastHeartbeatTimestamp => _lastHeartbeatTimestamp;

  Stream<UsbConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<SensorReading> get sensorDataStream => _sensorDataController.stream;
  Stream<String> get rawJsonStream => _rawJsonStreamController.stream;
  Stream<CommandAckResult> get ackStream => _ackController.stream;

  void _initNativeEventListener() {
    try {
      _nativeEventSub?.cancel();
      _nativeEventSub = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final type = event['type'] as String?;
            final payload = event['payload'];

            switch (type) {
              case 'ATTACHED':
                debugPrint('[USB] Device Attached: $payload');
                // Auto-connect if an ESP32 is attached
                scanAndConnectEsp32();
                break;

              case 'DETACHED':
                debugPrint('[USB] Device Detached: $payload');
                _handleDisconnected('USB cable disconnected');
                break;

              case 'CONNECTED':
                _handleConnected(payload);
                break;

              case 'PERMISSION_DENIED':
                _state = UsbConnectionState.permissionRequired;
                _connectionStateController.add(_state);
                _notificationService.triggerAlert(
                  alertKey: 'usb_permission_denied',
                  title: 'USB Permission Denied',
                  message: 'Android USB host permission was not granted for ESP32.',
                  severity: EventSeverity.warning,
                  category: EventCategory.system,
                );
                break;

              case 'DATA':
                if (payload is String) {
                  _processIncomingSerialLine(payload);
                }
                break;

              case 'ERROR':
                debugPrint('[USB] Error: $payload');
                _state = UsbConnectionState.error;
                _connectionStateController.add(_state);
                break;
            }
          }
        },
        onError: (dynamic error) {
          debugPrint('[USB] Native EventChannel error: $error');
          _handleDisconnected('EventChannel communication error');
        },
      );
    } catch (e) {
      debugPrint('[USB] EventChannel stream subscribe error: $e');
    }
  }

  void _handleConnected(dynamic payload) {
    _state = UsbConnectionState.connected;
    if (payload is Map) {
      _connectedDeviceName = payload['deviceName'] as String?;
    }
    _connectionStateController.add(_state);

    _notificationService.triggerAlert(
      alertKey: 'usb_connected',
      title: 'ESP32-H2 USB Connected',
      message: 'Direct USB CDC-ACM serial link established (115200 Baud).',
      severity: EventSeverity.info,
      category: EventCategory.system,
      forceBypassCooldown: true,
    );
  }

  void _handleDisconnected(String reason) {
    _state = UsbConnectionState.disconnected;
    _connectedDeviceName = null;
    _lastDataReceivedTimestamp = null;
    _lastHeartbeatTimestamp = null;
    _connectionStateController.add(_state);

    _notificationService.triggerAlert(
      alertKey: 'usb_disconnected',
      title: 'HARDWARE DISCONNECTED',
      message: reason,
      severity: EventSeverity.warning,
      category: EventCategory.system,
      forceBypassCooldown: true,
    );
  }

  /// Lists real USB devices connected to the Android USB Host port
  Future<List<DiscoveredUsbDevice>> getConnectedUsbDevices() async {
    try {
      final res = await _methodChannel.invokeMethod<List<dynamic>>('listUsbDevices');
      if (res != null) {
        return res.map((item) => DiscoveredUsbDevice.fromMap(item as Map)).toList();
      }
    } catch (e) {
      debugPrint('[USB] listUsbDevices error: $e');
    }
    return [];
  }

  /// Automatically discovers and connects to the attached ESP32-H2 board
  Future<bool> scanAndConnectEsp32() async {
    try {
      _state = UsbConnectionState.connecting;
      _connectionStateController.add(_state);

      final res = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('connectUsbDevice');
      if (res != null) {
        final status = res['status'] as String?;
        if (status == 'CONNECTED') {
          _handleConnected(res);
          return true;
        } else if (status == 'REQUESTING_PERMISSION') {
          _state = UsbConnectionState.permissionRequired;
          _connectionStateController.add(_state);
          return false;
        }
      }
    } catch (e) {
      debugPrint('[USB] connectUsbDevice error: $e');
      _handleDisconnected('Failed to open USB device: $e');
    }
    return false;
  }

  /// Disconnects the USB host link
  Future<void> disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnectUsb');
    } catch (_) {}
    _handleDisconnected('User disconnected USB');
  }

  /// Sends a structured newline-delimited command JSON to the ESP32 and awaits physical confirmation
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
        error: 'HARDWARE DISCONNECTED',
        seq: -1,
      );
    }

    final seq = ++_sequenceNumber;
    final cmdDoc = {
      'type': 'command',
      'device': device,
      'state': state,
      'seq': seq,
    };

    final jsonPayload = '${jsonEncode(cmdDoc)}\n';
    final completer = Completer<CommandAckResult>();
    _pendingCommandAcks[seq] = completer;

    // Timeout after 3 seconds if hardware doesn't ACK
    Timer(const Duration(milliseconds: 3000), () {
      if (!completer.isCompleted) {
        _pendingCommandAcks.remove(seq);
        completer.complete(
          CommandAckResult(
            success: false,
            device: device,
            requestedState: state,
            actualState: false,
            error: 'COMMAND TIMEOUT: No ACK received from ESP32',
            seq: seq,
          ),
        );
      }
    });

    try {
      final written = await _methodChannel.invokeMethod<bool>('sendUsbData', {'data': jsonPayload});
      if (written != true) {
        _pendingCommandAcks.remove(seq);
        return CommandAckResult(
          success: false,
          device: device,
          requestedState: state,
          actualState: false,
          error: 'USB WRITE FAILED',
          seq: seq,
        );
      }
    } catch (e) {
      _pendingCommandAcks.remove(seq);
      return CommandAckResult(
        success: false,
        device: device,
        requestedState: state,
        actualState: false,
        error: 'USB EXCEPTION: $e',
        seq: seq,
      );
    }

    return completer.future;
  }

  /// Parses incoming newline-delimited JSON messages from physical ESP32
  void _processIncomingSerialLine(String line) {
    _rawJsonStreamController.add(line);

    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return;

      final type = decoded['type'] as String?;

      if (type == 'sensor') {
        _handleSensorPacket(decoded);
      } else if (type == 'ack') {
        _handleAckPacket(decoded);
      } else if (type == 'heartbeat') {
        _handleHeartbeatPacket(decoded);
      } else if (type == 'boot') {
        _firmwareVersion = decoded['fw'] as String? ?? '1.2.0';
        debugPrint('[USB] ESP32 Boot Announce: FW $_firmwareVersion');
      }
    } catch (e) {
      debugPrint('[USB] Failed to parse serial JSON line: $e -> "$line"');
    }
  }

  void _handleSensorPacket(Map<dynamic, dynamic> data) {
    _lastDataReceivedTimestamp = DateTime.now();

    final rawTemp = data['temperature'];
    final rawHum = data['humidity'];
    final rawMq3 = data['mq3_raw'];

    // If physical sensor is disconnected or has not produced a reading yet
    if (rawTemp == null || rawHum == null || rawMq3 == null) {
      debugPrint('[USB] Physical sensor reported null: WAITING FOR SENSOR DATA');
      return;
    }

    final double temp = (rawTemp as num).toDouble();
    final double hum = (rawHum as num).toDouble();
    final int mq3 = (rawMq3 as num).toInt();
    final double delta = (data['mq3_delta'] as num?)?.toDouble() ?? 0.0;
    final bool fan = data['fan'] as bool? ?? false;
    final bool humState = data['humidifier'] as bool? ?? false;
    final String status = data['sensor_status'] as String? ?? 'OK';

    if (data.containsKey('fw')) {
      _firmwareVersion = data['fw'] as String? ?? _firmwareVersion;
    }

    final reading = SensorReading(
      timestamp: DateTime.now(),
      temperature: temp,
      humidity: hum,
      mq3RawAdc: mq3,
      mq3Baseline: _storageService.getSettings().mq3Baseline,
      mq3DeltaPercent: delta,
      fanActive: fan,
      humidifierActive: humState,
      sensorStatus: status,
      isSimulated: false, // STRICTLY REAL PHYSICAL SENSOR DATA
    );

    _sensorDataController.add(reading);

    // Persist real reading in recent storage
    final recent = _storageService.getRecentReadings();
    recent.add(reading);
    if (recent.length > 200) recent.removeAt(0);
    _storageService.saveRecentReadings(recent);
  }

  void _handleAckPacket(Map<dynamic, dynamic> data) {
    final seq = (data['seq'] as num?)?.toInt() ?? 0;
    final success = data['success'] as bool? ?? false;
    final device = data['device'] as String? ?? '';
    final state = data['state'] as bool? ?? false;
    final actualState = data['actual_state'] as bool? ?? state;
    final error = data['error'] as String?;

    final result = CommandAckResult(
      success: success,
      device: device,
      requestedState: state,
      actualState: actualState,
      error: error,
      seq: seq,
    );

    _ackController.add(result);

    // Resolve pending command Future
    final completer = _pendingCommandAcks.remove(seq);
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }

    // Record verified command event
    _storageService.addEvent(
      ActivityEvent(
        id: 'EVT-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        category: EventCategory.actuation,
        severity: success ? EventSeverity.info : EventSeverity.warning,
        title: success ? 'Actuator Confirmed (Physical USB ACK)' : 'COMMAND FAILED',
        description: 'Device: $device • Actual State: ${actualState ? "ON" : "OFF"}${error != null ? " • Error: $error" : ""}',
        triggerSource: 'ESP32-H2 USB CDC Hardware',
        operatingMode: 'LIVE',
      ),
    );
  }

  void _handleHeartbeatPacket(Map<dynamic, dynamic> data) {
    _lastHeartbeatTimestamp = DateTime.now();
    if (data.containsKey('fw')) {
      _firmwareVersion = data['fw'] as String? ?? _firmwareVersion;
    }
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (isConnected) {
        final now = DateTime.now();
        // If no packet received for more than 7 seconds while marked connected
        if (_lastDataReceivedTimestamp != null && now.difference(_lastDataReceivedTimestamp!).inSeconds > 7) {
          debugPrint('[USB WATCHDOG] No sensor packet received in 7s: Stale stream.');
        }
      }
    });
  }

  void dispose() {
    _watchdogTimer?.cancel();
    _nativeEventSub?.cancel();
    _connectionStateController.close();
    _sensorDataController.close();
    _rawJsonStreamController.close();
    _ackController.close();
  }
}
