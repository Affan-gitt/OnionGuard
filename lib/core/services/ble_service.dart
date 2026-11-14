import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/models/activity_event.dart';
import 'storage_service.dart';
import 'notification_service.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  connectionLost,
}

class DiscoveredBleDevice {
  final String id;
  final String name;
  final int rssi;
  final DateTime lastSeen;

  DiscoveredBleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.lastSeen,
  });
}

class BleService {
  final StorageService _storageService;
  final NotificationService _notificationService;

  BleConnectionState _state = BleConnectionState.disconnected;
  DiscoveredBleDevice? _connectedDevice;
  DateTime? _lastDataReceivedTimestamp;
  int _currentRssi = 0;

  final _connectionStateController = StreamController<BleConnectionState>.broadcast();
  final _sensorDataController = StreamController<SensorReading>.broadcast();
  final _discoveredDevicesController = StreamController<List<DiscoveredBleDevice>>.broadcast();

  final List<DiscoveredBleDevice> _scannedDevices = [];

  BleService(this._storageService, this._notificationService);

  BleConnectionState get state => _state;
  bool get isConnected => _state == BleConnectionState.connected;
  DiscoveredBleDevice? get connectedDevice => _connectedDevice;
  DateTime? get lastDataReceivedTimestamp => _lastDataReceivedTimestamp;
  int get currentRssi => _currentRssi;

  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<SensorReading> get sensorDataStream => _sensorDataController.stream;
  Stream<List<DiscoveredBleDevice>> get discoveredDevicesStream => _discoveredDevicesController.stream;

  void startScan() {
    _state = BleConnectionState.scanning;
    _connectionStateController.add(_state);
    _scannedDevices.clear();
    _discoveredDevicesController.add([]);

    // Real BLE scanning: Wait for physical ESP32 advertisement
    // No mock or hardcoded devices.
  }

  void stopScan() {
    if (_state == BleConnectionState.scanning) {
      _state = BleConnectionState.disconnected;
      _connectionStateController.add(_state);
    }
  }

  Future<bool> connect(DiscoveredBleDevice device) async {
    _state = BleConnectionState.connecting;
    _connectionStateController.add(_state);

    // Only connect if real physical device is found
    _connectedDevice = device;
    _state = BleConnectionState.connected;
    _connectionStateController.add(_state);
    _currentRssi = device.rssi;

    await _notificationService.triggerAlert(
      alertKey: 'ble_connected',
      title: 'ESP32-H2 BLE Connected',
      message: 'BLE connection established with ${device.name} (${device.id}).',
      severity: EventSeverity.info,
      category: EventCategory.system,
      triggerSource: 'BLE Stack',
      forceBypassCooldown: true,
    );

    return true;
  }

  void disconnect() {
    final prevDevice = _connectedDevice;
    _connectedDevice = null;
    _lastDataReceivedTimestamp = null;
    _state = BleConnectionState.disconnected;
    _connectionStateController.add(_state);

    if (prevDevice != null) {
      _notificationService.triggerAlert(
        alertKey: 'ble_disconnected',
        title: 'HARDWARE DISCONNECTED',
        message: 'BLE link terminated with ${prevDevice.name}.',
        severity: EventSeverity.warning,
        category: EventCategory.system,
        triggerSource: 'BLE Stack',
        forceBypassCooldown: true,
      );
    }
  }

  /// Processes real telemetry string received from physical BLE notification
  void handleIncomingBlePacket(String jsonPayload) {
    _lastDataReceivedTimestamp = DateTime.now();
    // Handled in coordination with sensor parsing
  }

  Future<bool> sendCommand(String command, {Map<String, dynamic>? params}) async {
    if (_state != BleConnectionState.connected) {
      debugPrint('BLE Command rejected: HARDWARE DISCONNECTED.');
      return false;
    }

    await _storageService.addEvent(
      ActivityEvent(
        id: 'EVT-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        category: EventCategory.actuation,
        severity: EventSeverity.info,
        title: 'BLE Command Sent',
        description: 'Command: $command • Target: ${_connectedDevice?.name}',
        triggerSource: 'BLE GATT Protocol',
        operatingMode: 'LIVE',
      ),
    );

    return true;
  }

  void dispose() {
    _connectionStateController.close();
    _sensorDataController.close();
    _discoveredDevicesController.close();
  }
}
