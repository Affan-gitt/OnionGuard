import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/models/sensor_reading.dart';
import 'storage_service.dart';

class InboundApiReceiverService {
  final StorageService _storageService;
  HttpServer? _server;
  final StreamController<SensorReading> _sensorStreamController = StreamController<SensorReading>.broadcast();

  bool _isRunning = false;
  int _port = 8088;
  String _lastReceivedInfo = 'No inbound API packets received yet.';
  DateTime? _lastReceivedTime;
  int _totalPacketsReceived = 0;

  InboundApiReceiverService(this._storageService);

  Stream<SensorReading> get sensorStream => _sensorStreamController.stream;
  bool get isRunning => _isRunning;
  int get port => _port;
  String get lastReceivedInfo => _lastReceivedInfo;
  DateTime? get lastReceivedTime => _lastReceivedTime;
  int get totalPacketsReceived => _totalPacketsReceived;

  Future<bool> startServer({int port = 8088}) async {
    if (_isRunning) return true;
    _port = port;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;
      debugPrint('[InboundAPI] Server listening on http://0.0.0.0:$_port');

      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('[InboundAPI] Server error: $e');
      });
      return true;
    } catch (e) {
      debugPrint('[InboundAPI] Failed to bind port $_port: $e');
      _isRunning = false;
      return false;
    }
  }

  Future<void> stopServer() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _isRunning = false;
  }

  void _handleRequest(HttpRequest request) async {
    // Enable CORS for web clients / Postman
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path.toLowerCase();

    if (request.method == 'POST' && (path == '/api/sensor' || path == '/sensor' || path == '/api/reading')) {
      try {
        final bodyStr = await utf8.decoder.bind(request).join();
        final json = jsonDecode(bodyStr) as Map<String, dynamic>;

        final temp = (json['temperature'] as num?)?.toDouble() ??
            (json['temp'] as num?)?.toDouble() ??
            0.0;
        final hum = (json['humidity'] as num?)?.toDouble() ??
            (json['hum'] as num?)?.toDouble() ??
            0.0;
        final mq3Raw = (json['mq3_raw'] as num?)?.toInt() ??
            (json['mq3_adc'] as num?)?.toInt() ??
            (json['gas'] as num?)?.toInt() ??
            300;

        final settings = _storageService.getSettings();
        final deltaPercent = settings.mq3Baseline > 0
            ? ((mq3Raw - settings.mq3Baseline) / settings.mq3Baseline) * 100.0
            : 0.0;

        final reading = SensorReading(
          timestamp: DateTime.now(),
          temperature: temp,
          humidity: hum,
          mq3RawAdc: mq3Raw,
          mq3Baseline: settings.mq3Baseline,
          mq3DeltaPercent: deltaPercent,
          fanActive: (json['fan'] as bool?) ?? false,
          humidifierActive: (json['humidifier'] as bool?) ?? false,
          sensorStatus: 'OK',
          isSimulated: false,
        );

        _totalPacketsReceived++;
        _lastReceivedTime = DateTime.now();
        _lastReceivedInfo = 'T: ${temp.toStringAsFixed(1)}°C  H: ${hum.toStringAsFixed(1)}%  Gas: $mq3Raw ADC';

        _sensorStreamController.add(reading);

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'success',
          'message': 'Sensor data received by OnionGuard',
          'received': {
            'temperature': temp,
            'humidity': hum,
            'mq3_raw': mq3Raw,
          },
          'timestamp': DateTime.now().toIso8601String(),
        }));
      } catch (e) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'error',
          'message': 'Invalid JSON payload: $e',
        }));
      }
    } else if (request.method == 'GET' && path == '/api/status') {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'online',
        'service': 'OnionGuard Inbound Sensor API Receiver',
        'version': '2.4.0',
        'port': _port,
        'packets_received': _totalPacketsReceived,
        'last_reading': _lastReceivedInfo,
      }));
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'error': 'Not Found',
        'usage': 'POST /api/sensor with {"temperature": 28.5, "humidity": 62.0, "mq3_raw": 420}',
      }));
    }

    await request.response.close();
  }

  /// Sends a sample test reading to verify the receiver works
  Future<bool> sendSampleInboundReading({
    double temperature = 28.5,
    double humidity = 64.0,
    int mq3Raw = 430,
  }) async {
    try {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:$_port/api/sensor'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'temperature': temperature,
        'humidity': humidity,
        'mq3_raw': mq3Raw,
        'fan': false,
        'humidifier': false,
      }));
      final resp = await req.close();
      client.close();
      return resp.statusCode == HttpStatus.ok;
    } catch (e) {
      debugPrint('[InboundAPI] Self-test error: $e');
      return false;
    }
  }

  void dispose() {
    stopServer();
    _sensorStreamController.close();
  }
}
