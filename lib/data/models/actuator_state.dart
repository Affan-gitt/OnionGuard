import '../../core/constants/app_constants.dart';

class ActuatorState {
  final bool fanState;
  final String fanMode; // "AUTO" or "MANUAL"
  final double fanTriggerTemp;
  final double fanResetTemp;
  final DateTime? fanLastActivated;
  final int fanTotalRuntimeSeconds;

  final bool humidifierState;
  final String humidifierMode; // "AUTO" or "MANUAL"
  final double humidifierTriggerPercent;
  final double humidifierMaxHumidityLimit;
  final DateTime? humidifierLastTrigger;
  final int humidifierTotalRuntimeSeconds;
  final bool safetyInterlockActive;

  ActuatorState({
    this.fanState = false,
    this.fanMode = 'AUTO',
    this.fanTriggerTemp = AppConstants.defaultTriggerTemp,
    this.fanResetTemp = AppConstants.defaultResetTemp,
    this.fanLastActivated,
    this.fanTotalRuntimeSeconds = 0,
    this.humidifierState = false,
    this.humidifierMode = 'AUTO',
    this.humidifierTriggerPercent = AppConstants.defaultMq3TriggerDeltaPercent,
    this.humidifierMaxHumidityLimit = AppConstants.defaultMaxHumiditySafety,
    this.humidifierLastTrigger,
    this.humidifierTotalRuntimeSeconds = 0,
    this.safetyInterlockActive = false,
  });

  ActuatorState copyWith({
    bool? fanState,
    String? fanMode,
    double? fanTriggerTemp,
    double? fanResetTemp,
    DateTime? fanLastActivated,
    int? fanTotalRuntimeSeconds,
    bool? humidifierState,
    String? humidifierMode,
    double? humidifierTriggerPercent,
    double? humidifierMaxHumidityLimit,
    DateTime? humidifierLastTrigger,
    int? humidifierTotalRuntimeSeconds,
    bool? safetyInterlockActive,
  }) {
    return ActuatorState(
      fanState: fanState ?? this.fanState,
      fanMode: fanMode ?? this.fanMode,
      fanTriggerTemp: fanTriggerTemp ?? this.fanTriggerTemp,
      fanResetTemp: fanResetTemp ?? this.fanResetTemp,
      fanLastActivated: fanLastActivated ?? this.fanLastActivated,
      fanTotalRuntimeSeconds: fanTotalRuntimeSeconds ?? this.fanTotalRuntimeSeconds,
      humidifierState: humidifierState ?? this.humidifierState,
      humidifierMode: humidifierMode ?? this.humidifierMode,
      humidifierTriggerPercent: humidifierTriggerPercent ?? this.humidifierTriggerPercent,
      humidifierMaxHumidityLimit: humidifierMaxHumidityLimit ?? this.humidifierMaxHumidityLimit,
      humidifierLastTrigger: humidifierLastTrigger ?? this.humidifierLastTrigger,
      humidifierTotalRuntimeSeconds: humidifierTotalRuntimeSeconds ?? this.humidifierTotalRuntimeSeconds,
      safetyInterlockActive: safetyInterlockActive ?? this.safetyInterlockActive,
    );
  }

  Map<String, dynamic> toJson() => {
    'fanState': fanState,
    'fanMode': fanMode,
    'fanTriggerTemp': fanTriggerTemp,
    'fanResetTemp': fanResetTemp,
    'fanLastActivated': fanLastActivated?.toIso8601String(),
    'fanTotalRuntimeSeconds': fanTotalRuntimeSeconds,
    'humidifierState': humidifierState,
    'humidifierMode': humidifierMode,
    'humidifierTriggerPercent': humidifierTriggerPercent,
    'humidifierMaxHumidityLimit': humidifierMaxHumidityLimit,
    'humidifierLastTrigger': humidifierLastTrigger?.toIso8601String(),
    'humidifierTotalRuntimeSeconds': humidifierTotalRuntimeSeconds,
    'safetyInterlockActive': safetyInterlockActive,
  };

  factory ActuatorState.fromJson(Map<String, dynamic> json) => ActuatorState(
    fanState: json['fanState'] as bool? ?? false,
    fanMode: json['fanMode'] as String? ?? 'AUTO',
    fanTriggerTemp: (json['fanTriggerTemp'] as num?)?.toDouble() ?? AppConstants.defaultTriggerTemp,
    fanResetTemp: (json['fanResetTemp'] as num?)?.toDouble() ?? AppConstants.defaultResetTemp,
    fanLastActivated: json['fanLastActivated'] != null ? DateTime.parse(json['fanLastActivated'] as String) : null,
    fanTotalRuntimeSeconds: json['fanTotalRuntimeSeconds'] as int? ?? 0,
    humidifierState: json['humidifierState'] as bool? ?? false,
    humidifierMode: json['humidifierMode'] as String? ?? 'AUTO',
    humidifierTriggerPercent: (json['humidifierTriggerPercent'] as num?)?.toDouble() ?? AppConstants.defaultMq3TriggerDeltaPercent,
    humidifierMaxHumidityLimit: (json['humidifierMaxHumidityLimit'] as num?)?.toDouble() ?? AppConstants.defaultMaxHumiditySafety,
    humidifierLastTrigger: json['humidifierLastTrigger'] != null ? DateTime.parse(json['humidifierLastTrigger'] as String) : null,
    humidifierTotalRuntimeSeconds: json['humidifierTotalRuntimeSeconds'] as int? ?? 0,
    safetyInterlockActive: json['safetyInterlockActive'] as bool? ?? false,
  );
}
