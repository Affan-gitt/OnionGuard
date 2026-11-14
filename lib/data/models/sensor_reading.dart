class SensorReading {
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final int mq3RawAdc;
  final int mq3Baseline;
  final double mq3DeltaPercent;
  final bool fanActive;
  final bool humidifierActive;
  final String sensorStatus; // "OK", "WARMING_UP", "GAS_TRIGGER", "DISCONNECTED"
  final bool isSimulated;

  SensorReading({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.mq3RawAdc,
    required this.mq3Baseline,
    required this.mq3DeltaPercent,
    required this.fanActive,
    required this.humidifierActive,
    this.sensorStatus = 'OK',
    this.isSimulated = false,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'temperature': temperature,
    'humidity': humidity,
    'mq3RawAdc': mq3RawAdc,
    'mq3Baseline': mq3Baseline,
    'mq3DeltaPercent': mq3DeltaPercent,
    'fanActive': fanActive,
    'humidifierActive': humidifierActive,
    'sensorStatus': sensorStatus,
    'isSimulated': isSimulated,
  };

  factory SensorReading.fromJson(Map<String, dynamic> json) => SensorReading(
    timestamp: DateTime.parse(json['timestamp'] as String),
    temperature: (json['temperature'] as num).toDouble(),
    humidity: (json['humidity'] as num).toDouble(),
    mq3RawAdc: json['mq3RawAdc'] as int,
    mq3Baseline: json['mq3Baseline'] as int,
    mq3DeltaPercent: (json['mq3DeltaPercent'] as num).toDouble(),
    fanActive: json['fanActive'] as bool,
    humidifierActive: json['humidifierActive'] as bool,
    sensorStatus: json['sensorStatus'] as String? ?? 'OK',
    isSimulated: json['isSimulated'] as bool? ?? false,
  );
}
