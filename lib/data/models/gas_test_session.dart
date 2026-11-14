enum GasTestPhase {
  idle,
  warmingUp,
  baselineAcquisition,
  readyToTest,
  testActive,
  peakRecorded,
  recovering,
  completed,
}

extension GasTestPhaseExtension on GasTestPhase {
  String get displayName {
    switch (this) {
      case GasTestPhase.idle:
        return 'Standby / Ready';
      case GasTestPhase.warmingUp:
        return 'Sensor Pre-Heating';
      case GasTestPhase.baselineAcquisition:
        return 'Acquiring Stable Baseline';
      case GasTestPhase.readyToTest:
        return 'Ready for Gas Exposure';
      case GasTestPhase.testActive:
        return 'Test in Progress';
      case GasTestPhase.peakRecorded:
        return 'Peak Response Captured';
      case GasTestPhase.recovering:
        return 'Monitoring Sensor Recovery';
      case GasTestPhase.completed:
        return 'Test Completed';
    }
  }

  String get stepDescription {
    switch (this) {
      case GasTestPhase.idle:
        return 'Click "Begin Test" to initiate the controlled 9-step gas sensor test protocol.';
      case GasTestPhase.warmingUp:
        return 'Step 1/9: Internal heater thermal stabilization. Please wait 15 seconds.';
      case GasTestPhase.baselineAcquisition:
        return 'Step 2/9: Sampling clean ambient air to establish baseline ADC value.';
      case GasTestPhase.readyToTest:
        return 'Step 3/9: Baseline locked. Introduce controlled alcohol vapour proxy near MQ-3.';
      case GasTestPhase.testActive:
        return 'Step 4/9: Recording real-time sensor response curve.';
      case GasTestPhase.peakRecorded:
        return 'Step 6/9: Peak value registered. Remove vapour source immediately.';
      case GasTestPhase.recovering:
        return 'Step 8/9: Tracking resistance recovery back toward baseline.';
      case GasTestPhase.completed:
        return 'Step 9/9: Test finished. Review summary report and metrics below.';
    }
  }
}

class GasTestPoint {
  final int second;
  final int adc;
  final double deltaPercent;

  GasTestPoint({
    required this.second,
    required this.adc,
    required this.deltaPercent,
  });

  Map<String, dynamic> toJson() => {
    'second': second,
    'adc': adc,
    'deltaPercent': deltaPercent,
  };

  factory GasTestPoint.fromJson(Map<String, dynamic> json) => GasTestPoint(
    second: json['second'] as int,
    adc: json['adc'] as int,
    deltaPercent: (json['deltaPercent'] as num).toDouble(),
  );
}

class GasTestSession {
  final String id;
  final DateTime timestamp;
  final int durationSeconds;
  final int baselineAdc;
  final int peakAdc;
  final int finalAdc;
  final double peakDeltaPercent;
  final int recoveryTimeSeconds;
  final List<GasTestPoint> samples;
  final String notes;

  GasTestSession({
    required this.id,
    required this.timestamp,
    required this.durationSeconds,
    required this.baselineAdc,
    required this.peakAdc,
    required this.finalAdc,
    required this.peakDeltaPercent,
    required this.recoveryTimeSeconds,
    required this.samples,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'durationSeconds': durationSeconds,
    'baselineAdc': baselineAdc,
    'peakAdc': peakAdc,
    'finalAdc': finalAdc,
    'peakDeltaPercent': peakDeltaPercent,
    'recoveryTimeSeconds': recoveryTimeSeconds,
    'samples': samples.map((s) => s.toJson()).toList(),
    'notes': notes,
  };

  factory GasTestSession.fromJson(Map<String, dynamic> json) => GasTestSession(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    durationSeconds: json['durationSeconds'] as int,
    baselineAdc: json['baselineAdc'] as int,
    peakAdc: json['peakAdc'] as int,
    finalAdc: json['finalAdc'] as int,
    peakDeltaPercent: (json['peakDeltaPercent'] as num).toDouble(),
    recoveryTimeSeconds: json['recoveryTimeSeconds'] as int,
    samples: (json['samples'] as List<dynamic>)
        .map((s) => GasTestPoint.fromJson(s as Map<String, dynamic>))
        .toList(),
    notes: json['notes'] as String? ?? '',
  );
}
