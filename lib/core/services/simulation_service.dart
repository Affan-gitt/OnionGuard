import 'dart:async';
import 'dart:math';
import '../../data/models/sensor_reading.dart';
import '../../data/models/activity_event.dart';
import 'storage_service.dart';
import 'notification_service.dart';

enum SimulationScenario {
  normalStorage,
  temperatureSpike,
  gasResponse,
  highHumidity,
  extendedStorage,
  sensorFailure,
  recovery,
}

extension SimulationScenarioExtension on SimulationScenario {
  String get displayName {
    switch (this) {
      case SimulationScenario.normalStorage:
        return 'A. Normal Storage';
      case SimulationScenario.temperatureSpike:
        return 'B. Temperature Spike & Ventilation';
      case SimulationScenario.gasResponse:
        return 'C. Gas Response Demonstration';
      case SimulationScenario.highHumidity:
        return 'D. High Humidity & Safety Interlock';
      case SimulationScenario.extendedStorage:
        return 'E. Extended Multi-Day Storage';
      case SimulationScenario.sensorFailure:
        return 'F. Hardware Sensor Disconnect';
      case SimulationScenario.recovery:
        return 'G. Environmental Recovery';
    }
  }

  String get description {
    switch (this) {
      case SimulationScenario.normalStorage:
        return 'Stable optimal room conditions (21.5°C, 63% RH, nominal baseline). Exhaust idle.';
      case SimulationScenario.temperatureSpike:
        return 'Ambient temp gradually climbs crossing 26.0°C. Demonstrates automated fan activation.';
      case SimulationScenario.gasResponse:
        return 'MQ-3 gas proxy reading spikes +45% above baseline. Triggers demonstration actuator.';
      case SimulationScenario.highHumidity:
        return 'Relative humidity rises to 78%. Triggers emergency safety interlock stopping humidifier.';
      case SimulationScenario.extendedStorage:
        return 'Simulates 14-day cumulative stress accumulation and spoilage progression curve.';
      case SimulationScenario.sensorFailure:
        return 'Simulates DHT11/MQ-3 hardware cable disconnection and system failsafe alerts.';
      case SimulationScenario.recovery:
        return 'Exhaust cools storage down below 24.0°C reset threshold; actuators safely return to standby.';
    }
  }
}

class SimulationService {
  final StorageService _storageService;
  final NotificationService _notificationService;

  bool _isActive = false;
  bool _isPaused = false;
  SimulationScenario _currentScenario = SimulationScenario.normalStorage;
  double _speedMultiplier = 1.0;

  // Manual override sliders
  double _simTemp = 21.5;
  double _simHumidity = 63.0;
  int _simGasAdc = 850;

  bool _simFanState = false;
  bool _simHumidifierState = false;

  Timer? _simTimer;
  int _stepCounter = 0;

  final _simReadingController = StreamController<SensorReading>.broadcast();
  final _stateChangeController = StreamController<bool>.broadcast();

  SimulationService(this._storageService, this._notificationService);

  bool get isActive => _isActive;
  bool get isPaused => _isPaused;
  SimulationScenario get currentScenario => _currentScenario;
  double get speedMultiplier => _speedMultiplier;

  double get simTemp => _simTemp;
  double get simHumidity => _simHumidity;
  int get simGasAdc => _simGasAdc;
  bool get simFanState => _simFanState;
  bool get simHumidifierState => _simHumidifierState;

  Stream<SensorReading> get simReadingStream => _simReadingController.stream;
  Stream<bool> get stateChangeStream => _stateChangeController.stream;

  void toggleSimulation() {
    if (_isActive) {
      stopSimulation();
    } else {
      startSimulation();
    }
  }

  void setManualFanState(bool isOn) {
    _simFanState = isOn;
    _emitReading();
  }

  void setManualHumidifierState(bool isOn) {
    _simHumidifierState = isOn;
    _emitReading();
  }

  void startSimulation() {
    _isActive = true;
    _isPaused = false;
    _stepCounter = 0;
    _applyScenarioDefaults(_currentScenario);
    _stateChangeController.add(true);
    _emitReading();

    _simTimer?.cancel();
    final intervalMs = (1000 / _speedMultiplier).round().clamp(100, 2000);
    _simTimer = Timer.periodic(Duration(milliseconds: intervalMs), _onTick);

    _storageService.addEvent(
      ActivityEvent(
        id: 'SIM-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        category: EventCategory.simulation,
        severity: EventSeverity.info,
        title: 'Simulation Session Started',
        description: 'Scenario: ${_currentScenario.displayName} @ ${_speedMultiplier}x speed.',
        triggerSource: 'Developer Console',
        operatingMode: 'SIMULATION',
      ),
    );
  }

  void pauseSimulation() {
    _isPaused = true;
    _simTimer?.cancel();
    _stateChangeController.add(true);
  }

  void resumeSimulation() {
    if (!_isActive) return;
    _isPaused = false;
    _stateChangeController.add(true);
    final intervalMs = (1000 / _speedMultiplier).round().clamp(100, 2000);
    _simTimer = Timer.periodic(Duration(milliseconds: intervalMs), _onTick);
  }

  void stopSimulation() {
    _isActive = false;
    _isPaused = false;
    _simTimer?.cancel();
    _simFanState = false;
    _simHumidifierState = false;
    _stateChangeController.add(false);

    _storageService.addEvent(
      ActivityEvent(
        id: 'SIM-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        category: EventCategory.simulation,
        severity: EventSeverity.info,
        title: 'Simulation Session Ended',
        description: 'Returned to live standby mode.',
        triggerSource: 'Developer Console',
        operatingMode: 'SIMULATION',
      ),
    );
  }

  void setScenario(SimulationScenario scenario) {
    _currentScenario = scenario;
    _stepCounter = 0;
    _applyScenarioDefaults(scenario);
    _stateChangeController.add(true);
  }

  void setSpeedMultiplier(double speed) {
    _speedMultiplier = speed;
    if (_isActive && !_isPaused) {
      _simTimer?.cancel();
      final intervalMs = (1000 / _speedMultiplier).round().clamp(100, 2000);
      _simTimer = Timer.periodic(Duration(milliseconds: intervalMs), _onTick);
    }
  }

  void setManualTemp(double t) {
    _simTemp = t;
    _evaluateActuationLogic();
  }

  void setManualHumidity(double h) {
    _simHumidity = h;
    _evaluateActuationLogic();
  }

  void setManualGasAdc(int adc) {
    _simGasAdc = adc;
    _evaluateActuationLogic();
  }

  void _applyScenarioDefaults(SimulationScenario scenario) {
    switch (scenario) {
      case SimulationScenario.normalStorage:
        _simTemp = 21.4;
        _simHumidity = 63.5;
        _simGasAdc = 852;
        _simFanState = false;
        _simHumidifierState = false;
        break;
      case SimulationScenario.temperatureSpike:
        _simTemp = 25.2; // Rises to 27.5+
        _simHumidity = 65.0;
        _simGasAdc = 860;
        break;
      case SimulationScenario.gasResponse:
        _simTemp = 22.0;
        _simHumidity = 64.0;
        _simGasAdc = 850; // Will climb to 1250
        break;
      case SimulationScenario.highHumidity:
        _simTemp = 21.0;
        _simHumidity = 72.0; // Climbs to 79%
        _simGasAdc = 855;
        _simHumidifierState = true;
        break;
      case SimulationScenario.extendedStorage:
        _simTemp = 23.5;
        _simHumidity = 68.0;
        _simGasAdc = 910;
        break;
      case SimulationScenario.sensorFailure:
        _simTemp = -999.0;
        _simHumidity = -999.0;
        _simGasAdc = 0;
        break;
      case SimulationScenario.recovery:
        _simTemp = 26.8; // Cools down below 24.0
        _simHumidity = 66.0;
        _simGasAdc = 1100;
        _simFanState = true;
        break;
    }
  }

  void _onTick(Timer timer) {
    if (!_isActive || _isPaused) return;
    _stepCounter++;

    final random = Random();

    // Scenario progression dynamics
    switch (_currentScenario) {
      case SimulationScenario.normalStorage:
        _simTemp = 21.4 + (random.nextDouble() * 0.4 - 0.2);
        _simHumidity = 63.5 + (random.nextDouble() * 0.8 - 0.4);
        _simGasAdc = 850 + (random.nextInt(10) - 5);
        break;

      case SimulationScenario.temperatureSpike:
        if (_simTemp < 28.5) {
          _simTemp += 0.25;
        } else {
          _simTemp += (random.nextDouble() * 0.2 - 0.1);
        }
        break;

      case SimulationScenario.gasResponse:
        if (_stepCounter < 10) {
          _simGasAdc += 40;
        } else if (_stepCounter < 25) {
          _simGasAdc = 1240 + random.nextInt(30);
        } else {
          _simGasAdc = max(860, _simGasAdc - 35);
        }
        break;

      case SimulationScenario.highHumidity:
        if (_simHumidity < 80.0) {
          _simHumidity += 0.4;
        }
        break;

      case SimulationScenario.extendedStorage:
        _simTemp = 22.0 + sin(_stepCounter * 0.1) * 3.0;
        _simHumidity = 65.0 + cos(_stepCounter * 0.08) * 6.0;
        _simGasAdc = 850 + (_stepCounter * 3);
        break;

      case SimulationScenario.sensorFailure:
        // Stays disconnected
        break;

      case SimulationScenario.recovery:
        if (_simTemp > 23.2) {
          _simTemp -= 0.3; // Actively cooled by fan
        }
        if (_simGasAdc > 855) {
          _simGasAdc -= 30;
        }
        break;
    }

    _emitReading();
  }

  void _emitReading() {
    _evaluateActuationLogic();

    final settings = _storageService.getSettings();
    final double deltaPct = settings.mq3Baseline > 0
        ? double.parse((((_simGasAdc - settings.mq3Baseline) / settings.mq3Baseline) * 100).toStringAsFixed(1))
        : 0.0;

    final String status = _simTemp < -500 ? 'DISCONNECTED' : (_simGasAdc > 1100 ? 'GAS_TRIGGER' : 'OK');

    final reading = SensorReading(
      timestamp: DateTime.now(),
      temperature: double.parse(_simTemp.toStringAsFixed(1)),
      humidity: double.parse(_simHumidity.toStringAsFixed(1)),
      mq3RawAdc: _simGasAdc,
      mq3Baseline: settings.mq3Baseline,
      mq3DeltaPercent: deltaPct,
      fanActive: _simFanState,
      humidifierActive: _simHumidifierState,
      sensorStatus: status,
      isSimulated: true,
    );

    _simReadingController.add(reading);
  }

  void _evaluateActuationLogic() {
    final settings = _storageService.getSettings();

    if (_simTemp < -500) {
      // Hardware failure interlock
      _simFanState = false;
      _simHumidifierState = false;
      return;
    }

    // 1. Fan Hysteresis Control
    if (!_simFanState && _simTemp >= settings.triggerTemp) {
      _simFanState = true;
      _notificationService.triggerAlert(
        alertKey: 'sim_fan_activated',
        title: '[SIM] Exhaust Fan Started',
        message: 'Simulated temp ${_simTemp.toStringAsFixed(1)}°C crossed threshold (${settings.triggerTemp}°C).',
        severity: EventSeverity.warning,
        category: EventCategory.actuation,
        triggerSource: 'Simulation Engine',
        operatingMode: 'SIMULATION',
        temperature: _simTemp,
        humidity: _simHumidity,
      );
    } else if (_simFanState && _simTemp <= settings.resetTemp) {
      _simFanState = false;
      _notificationService.triggerAlert(
        alertKey: 'sim_fan_deactivated',
        title: '[SIM] Exhaust Fan Stopped',
        message: 'Simulated temp ${_simTemp.toStringAsFixed(1)}°C cooled below reset threshold (${settings.resetTemp}°C).',
        severity: EventSeverity.info,
        category: EventCategory.actuation,
        triggerSource: 'Simulation Engine',
        operatingMode: 'SIMULATION',
        temperature: _simTemp,
        humidity: _simHumidity,
      );
    }

    // 2. Humidifier Safety Interlock
    if (_simHumidity >= settings.maxHumiditySafety) {
      if (_simHumidifierState) {
        _simHumidifierState = false;
        _notificationService.triggerAlert(
          alertKey: 'sim_humidity_interlock',
          title: '[SIM] Humidifier Safety Interlock',
          message: 'Safety limit exceeded (${_simHumidity.toStringAsFixed(1)}% >= ${settings.maxHumiditySafety}%). Actuator shut down.',
          severity: EventSeverity.critical,
          category: EventCategory.actuation,
          triggerSource: 'Simulation Engine',
          operatingMode: 'SIMULATION',
          temperature: _simTemp,
          humidity: _simHumidity,
        );
      }
    } else {
      // 3. Gas Response Trigger
      final double deltaPct = ((_simGasAdc - settings.mq3Baseline) / settings.mq3Baseline) * 100;
      if (deltaPct >= settings.mq3TriggerDeltaPercent) {
        if (!_simHumidifierState) {
          _simHumidifierState = true;
          _notificationService.triggerAlert(
            alertKey: 'sim_gas_trigger',
            title: '[SIM] Gas Detection Actuator Triggered',
            message: 'MQ-3 proxy delta +${deltaPct.toStringAsFixed(1)}% exceeded trigger (+${settings.mq3TriggerDeltaPercent}%).',
            severity: EventSeverity.warning,
            category: EventCategory.actuation,
            triggerSource: 'Simulation Engine',
            operatingMode: 'SIMULATION',
            gasAdc: _simGasAdc,
          );
        }
      } else {
        if (_simHumidifierState && _currentScenario != SimulationScenario.highHumidity) {
          _simHumidifierState = false;
        }
      }
    }
  }

  void dispose() {
    _simTimer?.cancel();
    _simReadingController.close();
    _stateChangeController.close();
  }
}
