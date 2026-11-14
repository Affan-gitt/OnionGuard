import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/storage_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/sms_service.dart';
import '../core/services/ble_service.dart';
import '../core/services/usb_serial_service.dart';
import '../core/services/simulation_service.dart';
import '../core/services/inbound_api_receiver_service.dart';
import '../core/utilities/risk_calculator.dart';
import '../data/models/sensor_reading.dart';
import '../data/models/actuator_state.dart';
import '../data/models/app_settings.dart';
import '../data/models/onion_item.dart';
import '../data/models/activity_event.dart';
import '../data/models/hygiene_entry.dart';
import '../data/models/sms_alert_queue_item.dart';
import '../data/repositories/onion_repository.dart';

// Foundation Services
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in main() with initialized instance');
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return NotificationService(storage);
});

final smsServiceProvider = Provider<SmsService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SmsService(storage);
});

// Primary USB CDC-ACM Serial Hardware Service
final usbSerialServiceProvider = Provider<UsbSerialService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final notification = ref.watch(notificationServiceProvider);
  final service = UsbSerialService(storage, notification);
  ref.onDispose(() => service.dispose());
  return service;
});

// Secondary BLE GATT Service
final bleServiceProvider = Provider<BleService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final notification = ref.watch(notificationServiceProvider);
  return BleService(storage, notification);
});

// Strictly Isolated Simulation Service (Cannot command physical hardware)
final simulationServiceProvider = Provider<SimulationService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final notification = ref.watch(notificationServiceProvider);
  return SimulationService(storage, notification);
});

// Inbound Sensor API Receiver (Listens for incoming sensor HTTP POST payloads)
final inboundApiReceiverServiceProvider = Provider<InboundApiReceiverService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final service = InboundApiReceiverService(storage);
  final settings = storage.getSettings();
  if (settings.inboundApiEnabled) {
    service.startServer(port: settings.inboundApiPort);
  }
  ref.onDispose(() => service.dispose());
  return service;
});

final onionRepositoryProvider = Provider<OnionRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return OnionRepository(storage);
});

// App Settings Notifier
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return ref.watch(storageServiceProvider).getSettings();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;
    await ref.read(storageServiceProvider).saveSettings(newSettings);
  }
}

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ============================================================================
// SENSOR STATE (STRICTLY HARDWARE-FIRST)
// ============================================================================
class SensorState {
  final SensorReading? latestReading;
  final List<SensorReading> history;
  final bool isUsbConnected;
  final bool isBleConnected;
  final bool isSimulation;
  final String hardwareStatusText;
  final RiskBreakdown? riskBreakdown;

  SensorState({
    this.latestReading,
    this.history = const [],
    this.isUsbConnected = false,
    this.isBleConnected = false,
    this.isSimulation = false,
    this.hardwareStatusText = 'HARDWARE DISCONNECTED',
    this.riskBreakdown,
  });

  bool get isHardwareConnected => isUsbConnected || isBleConnected;
  bool get hasValidData => latestReading != null && latestReading!.temperature > -100;

  SensorState copyWith({
    SensorReading? latestReading,
    List<SensorReading>? history,
    bool? isUsbConnected,
    bool? isBleConnected,
    bool? isSimulation,
    String? hardwareStatusText,
    RiskBreakdown? riskBreakdown,
  }) {
    return SensorState(
      latestReading: latestReading ?? this.latestReading,
      history: history ?? this.history,
      isUsbConnected: isUsbConnected ?? this.isUsbConnected,
      isBleConnected: isBleConnected ?? this.isBleConnected,
      isSimulation: isSimulation ?? this.isSimulation,
      hardwareStatusText: hardwareStatusText ?? this.hardwareStatusText,
      riskBreakdown: riskBreakdown ?? this.riskBreakdown,
    );
  }
}

class SensorNotifier extends Notifier<SensorState> {
  StreamSubscription? _usbConnSub;
  StreamSubscription? _usbDataSub;
  StreamSubscription? _bleConnSub;
  StreamSubscription? _simSub;
  StreamSubscription? _inboundSub;

  bool _wasTempHigh = false;
  bool _wasSensorDisconnected = false;

  @override
  SensorState build() {
    final storage = ref.watch(storageServiceProvider);
    final history = storage.getRecentReadings();
    final latest = history.isNotEmpty ? history.last : null;
    final settings = ref.watch(settingsNotifierProvider);
    final usb = ref.watch(usbSerialServiceProvider);
    final ble = ref.watch(bleServiceProvider);
    final sim = ref.watch(simulationServiceProvider);
    final inbound = ref.watch(inboundApiReceiverServiceProvider);

    RiskBreakdown? risk;
    if (latest != null) {
      risk = RiskCalculator.calculate(reading: latest, settings: settings);
    }

    ref.onDispose(() {
      _usbConnSub?.cancel();
      _usbDataSub?.cancel();
      _bleConnSub?.cancel();
      _simSub?.cancel();
      _inboundSub?.cancel();
    });

    // 1. Listen to USB connection state
    _usbConnSub?.cancel();
    _usbConnSub = usb.connectionStateStream.listen((usbState) {
      final isConn = usbState == UsbConnectionState.connected;
      String statusText = isConn ? 'USB CDC ACTIVE' : 'HARDWARE DISCONNECTED';
      if (ref.read(simulationServiceProvider).isActive) {
        statusText = 'SIMULATED';
      }
      state = state.copyWith(
        isUsbConnected: isConn,
        hardwareStatusText: statusText,
      );
    });

    // 2. Listen to real physical USB sensor telemetry
    _usbDataSub?.cancel();
    _usbDataSub = usb.sensorDataStream.listen((reading) {
      if (!ref.read(simulationServiceProvider).isActive) {
        _onNewReading(reading, isSim: false, source: 'USB CDC');
      }
    });

    // 3. Listen to BLE connection state
    _bleConnSub?.cancel();
    _bleConnSub = ble.connectionStateStream.listen((bleState) {
      final isConn = bleState == BleConnectionState.connected;
      state = state.copyWith(isBleConnected: isConn);
    });

    // 4. Listen to Simulation Stream (Only active when explicitly started)
    _simSub?.cancel();
    _simSub = sim.simReadingStream.listen((reading) {
      if (sim.isActive) {
        _onNewReading(reading, isSim: true, source: 'SIMULATION');
      }
    });

    // 5. Listen to Inbound API stream (Receives HTTP POST telemetry)
    _inboundSub?.cancel();
    _inboundSub = inbound.sensorStream.listen((reading) {
      if (!ref.read(simulationServiceProvider).isActive) {
        _onNewReading(reading, isSim: false, source: 'INBOUND API');
      }
    });

    final bool isUsb = usb.isConnected;
    final bool isBle = ble.isConnected;
    final bool isSim = sim.isActive;

    String initialStatus = 'HARDWARE DISCONNECTED';
    if (isSim) {
      initialStatus = 'SIMULATED';
    } else if (isUsb) {
      initialStatus = 'USB CDC ACTIVE';
    } else if (isBle) {
      initialStatus = 'BLE ACTIVE';
    }

    return SensorState(
      latestReading: latest,
      history: history,
      isUsbConnected: isUsb,
      isBleConnected: isBle,
      isSimulation: isSim,
      hardwareStatusText: initialStatus,
      riskBreakdown: risk,
    );
  }

  void _onNewReading(SensorReading reading, {required bool isSim, required String source}) {
    final settings = ref.read(settingsNotifierProvider);
    final risk = RiskCalculator.calculate(reading: reading, settings: settings);
    final updatedHistory = List<SensorReading>.from(state.history)..add(reading);
    if (updatedHistory.length > 200) {
      updatedHistory.removeAt(0);
    }

    // Check if recovering from previous sensor disconnect
    if (!isSim && _wasSensorDisconnected) {
      _wasSensorDisconnected = false;
      ref.read(notificationServiceProvider).triggerAlert(
        alertKey: 'SENSOR_RECOVERED',
        title: 'Sensor Communication Restored',
        message: 'Telemetry datastream from ESP32-H2 sensors successfully recovered.',
        severity: EventSeverity.info,
        category: EventCategory.system,
      );
      if (settings.whatsappEnabled && !isSim) {
        ref.read(smsServiceProvider).enqueueAlertEvent(
          eventType: SmsEventType.sensorRecovered,
          message: '🧅 *OnionGuard Telemetry Online:* ESP32-H2 sensor link restored. Live storage monitoring active.',
          priority: SmsAlertPriority.low,
        );
      }
    }

    state = state.copyWith(
      latestReading: reading,
      history: updatedHistory,
      isUsbConnected: source == 'USB CDC' || state.isUsbConnected,
      isSimulation: isSim,
      hardwareStatusText: isSim
          ? 'SIMULATED'
          : (source == 'INBOUND API'
              ? 'INBOUND API ACTIVE'
              : (source == 'USB CDC' ? 'LIVE USB FEED' : 'LIVE BLE FEED')),
      riskBreakdown: risk,
    );

    // Evaluate automated threshold alert dispatch
    _checkThresholdsAndAlert(reading, settings, isSim: isSim);
  }

  void _checkThresholdsAndAlert(SensorReading reading, AppSettings settings, {required bool isSim}) {
    final notifService = ref.read(notificationServiceProvider);
    final smsService = ref.read(smsServiceProvider);

    // 1. High Temperature & Return to Normal
    if (reading.temperature >= settings.triggerTemp) {
      if (!_wasTempHigh) {
        _wasTempHigh = true;
        notifService.triggerAlert(
          alertKey: 'TEMP_HIGH',
          title: 'High Storage Temperature Warning',
          message: 'Temperature reached ${reading.temperature.toStringAsFixed(1)}°C (threshold: ${settings.triggerTemp}°C). Automated ventilation activated.',
          severity: EventSeverity.critical,
          category: EventCategory.environmental,
          triggerSource: isSim ? 'Simulation' : 'ESP32 DHT11 (Physical)',
          operatingMode: isSim ? 'SIMULATION' : 'LIVE',
          temperature: reading.temperature,
          humidity: reading.humidity,
          gasAdc: reading.mq3RawAdc,
        );

        if (settings.whatsappEnabled && !isSim) {
          smsService.enqueueAlertEvent(
            eventType: SmsEventType.tempHigh,
            message: '🧅 *OnionGuard Warning:* Storage temp *${reading.temperature.toStringAsFixed(1)}°C* exceeds *${settings.triggerTemp}°C* limit! Exhaust fan activated.',
            priority: SmsAlertPriority.high,
          );
        }
      }
    } else if (_wasTempHigh && reading.temperature <= settings.resetTemp) {
      _wasTempHigh = false;
      notifService.triggerAlert(
        alertKey: 'TEMP_NORMAL',
        title: 'Storage Temperature Normalized',
        message: 'Temperature dropped to ${reading.temperature.toStringAsFixed(1)}°C (below reset ${settings.resetTemp}°C). Ventilation idle.',
        severity: EventSeverity.info,
        category: EventCategory.environmental,
        triggerSource: isSim ? 'Simulation' : 'ESP32 DHT11 (Physical)',
        operatingMode: isSim ? 'SIMULATION' : 'LIVE',
        temperature: reading.temperature,
        humidity: reading.humidity,
      );

      if (settings.whatsappEnabled && !isSim) {
        smsService.enqueueAlertEvent(
          eventType: SmsEventType.tempNormal,
          message: '🧅 *OnionGuard Notice:* Storage temp returned to safe level (*${reading.temperature.toStringAsFixed(1)}°C*). Exhaust fan idle.',
          priority: SmsAlertPriority.low,
        );
      }
    }

    // 2. Volatile Gas / Spoilage Vapour Trigger (Alcohol Proxy)
    if (reading.mq3DeltaPercent >= settings.mq3TriggerDeltaPercent) {
      notifService.triggerAlert(
        alertKey: 'GAS_SPIKE',
        title: 'Volatile Decomposition Gas Detected',
        message: 'MQ-3 alcohol proxy response +${reading.mq3DeltaPercent.toStringAsFixed(1)}% above baseline.',
        severity: EventSeverity.warning,
        category: EventCategory.environmental,
        triggerSource: isSim ? 'Simulation' : 'ESP32 MQ-3 (Physical)',
        operatingMode: isSim ? 'SIMULATION' : 'LIVE',
        temperature: reading.temperature,
        humidity: reading.humidity,
        gasAdc: reading.mq3RawAdc,
      );

      if (settings.whatsappEnabled && !isSim) {
        smsService.enqueueAlertEvent(
          eventType: SmsEventType.gasSpike,
          message: '🧅 *OnionGuard Alert:* Volatile spoilage gas spike *+${reading.mq3DeltaPercent.toStringAsFixed(1)}%* detected in storage room.',
          priority: SmsAlertPriority.high,
        );
      }
    }

    // 3. Humidity Safety Interlock
    if (reading.humidity >= settings.maxHumiditySafety) {
      notifService.triggerAlert(
        alertKey: 'HUMIDITY_INTERLOCK',
        title: 'High Humidity Safety Interlock',
        message: 'Relative humidity ${reading.humidity.toStringAsFixed(1)}% reached critical limit (${settings.maxHumiditySafety}%). Actuator locked OFF.',
        severity: EventSeverity.critical,
        category: EventCategory.actuation,
        triggerSource: isSim ? 'Simulation' : 'ESP32 DHT11 (Physical)',
        operatingMode: isSim ? 'SIMULATION' : 'LIVE',
        temperature: reading.temperature,
        humidity: reading.humidity,
      );

      if (settings.whatsappEnabled && !isSim) {
        smsService.enqueueAlertEvent(
          eventType: SmsEventType.humidityHigh,
          message: '🧅 *OnionGuard Safety:* Relative humidity *${reading.humidity.toStringAsFixed(1)}%* exceeded safe limit! Humidifier locked OFF.',
          priority: SmsAlertPriority.high,
        );
      }
    }
  }
}

final sensorNotifierProvider = NotifierProvider<SensorNotifier, SensorState>(SensorNotifier.new);

// ============================================================================
// ACTUATOR STATE NOTIFIER (STRICT PHYSICAL VERIFICATION)
// ============================================================================
class ActuatorNotifier extends Notifier<ActuatorState> {
  @override
  ActuatorState build() {
    return ref.watch(storageServiceProvider).getActuatorState();
  }

  Future<void> setFanMode(String mode) async {
    final updated = state.copyWith(fanMode: mode);
    state = updated;
    await ref.read(storageServiceProvider).saveActuatorState(updated);
  }

  /// Toggles physical exhaust fan via USB CDC with strict ACK verification
  Future<bool> toggleFan(bool isOn) async {
    final isSim = ref.read(simulationServiceProvider).isActive;

    if (isSim) {
      // In simulation mode, strictly toggle local state without commanding physical hardware
      final updated = state.copyWith(
        fanState: isOn,
        fanMode: 'MANUAL',
        fanLastActivated: isOn ? DateTime.now() : state.fanLastActivated,
      );
      state = updated;
      await ref.read(storageServiceProvider).saveActuatorState(updated);
      return true;
    }

    // LIVE HARDWARE MODE: Command physical ESP32 over USB CDC
    final usb = ref.read(usbSerialServiceProvider);
    if (!usb.isConnected) {
      ref.read(notificationServiceProvider).triggerAlert(
        alertKey: 'fan_cmd_error',
        title: 'COMMAND FAILED',
        message: 'Cannot toggle exhaust fan: HARDWARE DISCONNECTED.',
        severity: EventSeverity.warning,
        category: EventCategory.actuation,
        forceBypassCooldown: true,
      );
      return false;
    }

    final ack = await usb.sendActuatorCommand(device: 'fan', state: isOn);
    if (ack.success) {
      final updated = state.copyWith(
        fanState: ack.actualState,
        fanMode: 'MANUAL',
        fanLastActivated: ack.actualState ? DateTime.now() : state.fanLastActivated,
      );
      state = updated;
      await ref.read(storageServiceProvider).saveActuatorState(updated);

      if (isOn && ref.read(settingsNotifierProvider).smsEnabled) {
        ref.read(smsServiceProvider).enqueueAlertEvent(
          eventType: SmsEventType.fanActivated,
          message: 'OnionGuard Notice: Exhaust fan activated for storage ventilation.',
          priority: SmsAlertPriority.medium,
        );
      }

      return true;
    } else {
      ref.read(notificationServiceProvider).triggerAlert(
        alertKey: 'fan_cmd_failed',
        title: 'COMMAND FAILED',
        message: ack.error ?? 'ESP32 failed to switch exhaust fan relay.',
        severity: EventSeverity.critical,
        category: EventCategory.actuation,
        forceBypassCooldown: true,
      );
      return false;
    }
  }

  Future<void> setHumidifierMode(String mode) async {
    final updated = state.copyWith(humidifierMode: mode);
    state = updated;
    await ref.read(storageServiceProvider).saveActuatorState(updated);
  }

  /// Toggles physical humidifier demonstration actuator via USB CDC
  Future<bool> toggleHumidifier(bool isOn) async {
    final isSim = ref.read(simulationServiceProvider).isActive;

    if (isSim) {
      final updated = state.copyWith(
        humidifierState: isOn,
        humidifierMode: 'MANUAL',
        humidifierLastTrigger: isOn ? DateTime.now() : state.humidifierLastTrigger,
      );
      state = updated;
      await ref.read(storageServiceProvider).saveActuatorState(updated);
      return true;
    }

    // LIVE HARDWARE MODE: Command physical ESP32 over USB CDC
    final usb = ref.read(usbSerialServiceProvider);
    if (!usb.isConnected) {
      ref.read(notificationServiceProvider).triggerAlert(
        alertKey: 'hum_cmd_error',
        title: 'COMMAND FAILED',
        message: 'Cannot toggle actuator: HARDWARE DISCONNECTED.',
        severity: EventSeverity.warning,
        category: EventCategory.actuation,
        forceBypassCooldown: true,
      );
      return false;
    }

    final ack = await usb.sendActuatorCommand(device: 'humidifier', state: isOn);
    if (ack.success) {
      final updated = state.copyWith(
        humidifierState: ack.actualState,
        humidifierMode: 'MANUAL',
        humidifierLastTrigger: ack.actualState ? DateTime.now() : state.humidifierLastTrigger,
      );
      state = updated;
      await ref.read(storageServiceProvider).saveActuatorState(updated);

      if (isOn && ref.read(settingsNotifierProvider).smsEnabled) {
        ref.read(smsServiceProvider).enqueueAlertEvent(
          eventType: SmsEventType.humidifierActivated,
          message: 'OnionGuard Notice: Gas-response demonstration actuator activated.',
          priority: SmsAlertPriority.medium,
        );
      }

      return true;
    } else {
      ref.read(notificationServiceProvider).triggerAlert(
        alertKey: 'hum_cmd_failed',
        title: 'COMMAND FAILED',
        message: ack.error ?? 'ESP32 rejected humidifier command (Safety interlock active).',
        severity: EventSeverity.critical,
        category: EventCategory.actuation,
        forceBypassCooldown: true,
      );
      return false;
    }
  }
}

final actuatorNotifierProvider = NotifierProvider<ActuatorNotifier, ActuatorState>(ActuatorNotifier.new);

// ============================================================================
// HARDWARE CONNECTIVITY NOTIFIER (SECTION E: SEPARATE CONNECTION STATES)
// ============================================================================
class HardwareConnectivityState {
  final String phoneInternetStatus; // "Offline-First (Standby)"
  final String backendStatus;       // "Local Host (Offline-First)"
  final String esp32UsbStatus;      // "Connected (USB CDC)" / "HARDWARE DISCONNECTED"
  final String esp32BleStatus;      // "Connected" / "Disconnected"
  final String sensorDataStatus;    // "Live Telemetry Active" / "WAITING FOR SENSOR DATA" / "HARDWARE DISCONNECTED"
  final String smsCapabilityStatus; // "Phone SIM Ready" / "SMS PERMISSION DENIED" / "SMS UNAVAILABLE"

  HardwareConnectivityState({
    required this.phoneInternetStatus,
    required this.backendStatus,
    required this.esp32UsbStatus,
    required this.esp32BleStatus,
    required this.sensorDataStatus,
    required this.smsCapabilityStatus,
  });
}

class ConnectivityNotifier extends Notifier<HardwareConnectivityState> {
  Timer? _refreshTimer;
  String _cachedSmsStatus = 'Phone SIM Ready';

  @override
  HardwareConnectivityState build() {
    ref.onDispose(() => _refreshTimer?.cancel());
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => refresh());
    _checkSms();

    return _computeState();
  }

  Future<void> _checkSms() async {
    try {
      final sms = ref.read(smsServiceProvider);
      final cap = await sms.checkCapability();
      _cachedSmsStatus = cap.displayStatus;
      state = _computeState();
    } catch (_) {
      _cachedSmsStatus = 'SMS UNAVAILABLE';
      state = _computeState();
    }
  }

  void refresh() {
    _checkSms();
    state = _computeState();
  }

  HardwareConnectivityState _computeState() {
    final usb = ref.read(usbSerialServiceProvider);
    final ble = ref.read(bleServiceProvider);
    final sensor = ref.read(sensorNotifierProvider);

    final usbStatus = usb.isConnected ? 'Connected (USB CDC)' : 'HARDWARE DISCONNECTED';
    final bleStatus = ble.isConnected ? 'Connected' : 'Disconnected';

    String dataStatus = 'HARDWARE DISCONNECTED';
    if (sensor.isSimulation) {
      dataStatus = 'SIMULATED DATASTREAM';
    } else if (usb.isConnected || ble.isConnected) {
      dataStatus = sensor.hasValidData ? 'Live Telemetry Active' : 'WAITING FOR SENSOR DATA';
    }

    return HardwareConnectivityState(
      phoneInternetStatus: 'Offline-First (Standby)',
      backendStatus: 'Local Host (Offline-First)',
      esp32UsbStatus: usbStatus,
      esp32BleStatus: bleStatus,
      sensorDataStatus: dataStatus,
      smsCapabilityStatus: _cachedSmsStatus,
    );
  }
}

final connectivityNotifierProvider = NotifierProvider<ConnectivityNotifier, HardwareConnectivityState>(ConnectivityNotifier.new);

// Onion Inventory State Notifier
class OnionInventoryNotifier extends Notifier<List<OnionItem>> {
  @override
  List<OnionItem> build() {
    return ref.watch(onionRepositoryProvider).getAllOnions();
  }

  void refresh() {
    state = ref.read(onionRepositoryProvider).getAllOnions();
  }

  Future<void> addOnion(OnionItem item) async {
    await ref.read(onionRepositoryProvider).saveOnion(item);
    refresh();
  }

  Future<void> updateCondition({
    required String id,
    required OnionCondition newCondition,
    required String note,
    double? newWeight,
  }) async {
    await ref.read(onionRepositoryProvider).updateCondition(
      id: id,
      newCondition: newCondition,
      note: note,
      newWeight: newWeight,
    );
    refresh();
  }

  Future<void> moveOnion({
    required String id,
    required String newRack,
    required int newShelf,
    required int newSpot,
  }) async {
    await ref.read(onionRepositoryProvider).moveOnion(
      id: id,
      newRack: newRack,
      newShelf: newShelf,
      newSpot: newSpot,
    );
    refresh();
  }

  Future<void> deleteOnion(String id) async {
    await ref.read(onionRepositoryProvider).removeOnion(id);
    refresh();
  }
}

final onionInventoryNotifierProvider = NotifierProvider<OnionInventoryNotifier, List<OnionItem>>(OnionInventoryNotifier.new);

// Events State Notifier
class EventsNotifier extends Notifier<List<ActivityEvent>> {
  @override
  List<ActivityEvent> build() {
    return ref.watch(storageServiceProvider).getEvents();
  }

  void refresh() {
    state = ref.read(storageServiceProvider).getEvents();
  }

  Future<void> addEvent(ActivityEvent event) async {
    await ref.read(storageServiceProvider).addEvent(event);
    refresh();
  }
}

final eventsNotifierProvider = NotifierProvider<EventsNotifier, List<ActivityEvent>>(EventsNotifier.new);

// Hygiene State Notifier
class HygieneNotifier extends Notifier<List<HygieneEntry>> {
  @override
  List<HygieneEntry> build() {
    return ref.watch(storageServiceProvider).getHygieneEntries();
  }

  void refresh() {
    state = ref.read(storageServiceProvider).getHygieneEntries();
  }

  Future<void> addEntry(HygieneEntry entry) async {
    final storage = ref.read(storageServiceProvider);
    final list = storage.getHygieneEntries();
    list.insert(0, entry);
    await storage.saveHygieneEntries(list);
    refresh();
  }
}

final hygieneNotifierProvider = NotifierProvider<HygieneNotifier, List<HygieneEntry>>(HygieneNotifier.new);
