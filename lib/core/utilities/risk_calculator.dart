import 'dart:math';
import '../../data/models/app_settings.dart';
import '../../data/models/sensor_reading.dart';

enum HealthClassification {
  good,
  attentionRequired,
  highRisk,
  critical,
}

extension HealthClassificationExtension on HealthClassification {
  String get displayName {
    switch (this) {
      case HealthClassification.good:
        return 'Good / Optimal';
      case HealthClassification.attentionRequired:
        return 'Attention Required';
      case HealthClassification.highRisk:
        return 'High Risk';
      case HealthClassification.critical:
        return 'Critical Spoilage Danger';
    }
  }

  String get recommendation {
    switch (this) {
      case HealthClassification.good:
        return 'Environmental parameters are within optimal preservation thresholds. Maintain standard monitoring.';
      case HealthClassification.attentionRequired:
        return 'Slight environmental deviation observed. Inspect ventilation pathways and monitor temperature trend.';
      case HealthClassification.highRisk:
        return 'Elevated environmental stress detected. Verify exhaust ventilation and check shelves for soft bulbs.';
      case HealthClassification.critical:
        return 'Severe conditions detected! Manually check onion racks immediately, segregate rotting bulbs, and maximize air circulation.';
    }
  }
}

class RiskBreakdown {
  final double overallScore;
  final double tempRisk;
  final double humidityRisk;
  final double gasRisk;
  final double ventilationRisk;
  final HealthClassification classification;
  final String primaryContributingFactor;
  final String recommendation;
  final double tempDeviation;
  final double humidityDeviation;

  RiskBreakdown({
    required this.overallScore,
    required this.tempRisk,
    required this.humidityRisk,
    required this.gasRisk,
    required this.ventilationRisk,
    required this.classification,
    required this.primaryContributingFactor,
    required this.recommendation,
    required this.tempDeviation,
    required this.humidityDeviation,
  });
}

class RiskCalculator {
  /// Computes transparent, mathematically grounded storage risk scores (0 - 100).
  /// Note: The MQ-3 is an alcohol-vapour sensor acting as a gas response proxy.
  /// This model is a transparent engineering estimation requiring experimental validation.
  static RiskBreakdown calculate({
    required SensorReading reading,
    required AppSettings settings,
  }) {
    // 1. Temperature Deviation & Risk (0-100)
    final tempDev = reading.temperature - settings.targetTemp;
    double tRisk = 0.0;
    if (reading.temperature <= 22.0 && reading.temperature >= 15.0) {
      tRisk = max(0.0, (reading.temperature - settings.targetTemp).abs() * 3.0);
    } else if (reading.temperature > 22.0) {
      // Risk rises steeply as temperature exceeds 22°C up to 35°C
      tRisk = min(100.0, 15.0 + (reading.temperature - 22.0) * 6.5);
    } else {
      // Below 15°C (chilling risk / condensation danger if freezing)
      tRisk = min(100.0, (15.0 - reading.temperature) * 5.0);
    }

    // 2. Humidity Deviation & Risk (0-100)
    final humDev = reading.humidity - settings.targetHumidity;
    double hRisk = 0.0;
    if (reading.humidity >= 60.0 && reading.humidity <= 70.0) {
      hRisk = max(0.0, (reading.humidity - settings.targetHumidity).abs() * 2.0);
    } else if (reading.humidity > 70.0) {
      // High humidity heavily accelerates fungal germination & root emergence
      hRisk = min(100.0, 20.0 + (reading.humidity - 70.0) * 5.5);
    } else {
      // Dry air (<60%) causes desiccating skin shrivel and weight loss
      hRisk = min(100.0, (60.0 - reading.humidity) * 3.5);
    }

    // 3. Gas Response Proxy Risk (MQ-3 relative to baseline) (0-100)
    double gRisk = 0.0;
    if (reading.mq3DeltaPercent <= 5.0) {
      gRisk = max(0.0, reading.mq3DeltaPercent * 2.0);
    } else if (reading.mq3DeltaPercent <= 25.0) {
      gRisk = 10.0 + (reading.mq3DeltaPercent - 5.0) * 1.5;
    } else {
      // Elevated volatile organics / alcohol decomposition proxy
      gRisk = min(100.0, 40.0 + (reading.mq3DeltaPercent - 25.0) * 2.0);
    }

    // 4. Ventilation Risk (0-100)
    double vRisk = 10.0; // Base baseline
    if (reading.temperature >= settings.triggerTemp && !reading.fanActive) {
      // Stagnant hot air without exhaust
      vRisk = 85.0;
    } else if (reading.fanActive) {
      // Active airflow alleviating stagnation
      vRisk = 15.0;
    } else if (reading.humidity > settings.maxHumiditySafety) {
      vRisk = 60.0;
    }

    // Weighted Overall Risk Score
    final totalWeight = settings.weightTemp + settings.weightHumidity + settings.weightGas + settings.weightVentilation;
    final wT = settings.weightTemp / totalWeight;
    final wH = settings.weightHumidity / totalWeight;
    final wG = settings.weightGas / totalWeight;
    final wV = settings.weightVentilation / totalWeight;

    final overall = (tRisk * wT) + (hRisk * wH) + (gRisk * wG) + (vRisk * wV);
    final clampedOverall = overall.clamp(0.0, 100.0);

    // Classification
    HealthClassification classification;
    if (clampedOverall < 25.0) {
      classification = HealthClassification.good;
    } else if (clampedOverall < 50.0) {
      classification = HealthClassification.attentionRequired;
    } else if (clampedOverall < 75.0) {
      classification = HealthClassification.highRisk;
    } else {
      classification = HealthClassification.critical;
    }

    // Primary contributing factor
    final risks = {
      'Elevated Temperature': tRisk * wT,
      'High Humidity / Condensation': hRisk * wH,
      'Gas Proxy Accumulation': gRisk * wG,
      'Stagnant Ventilation': vRisk * wV,
    };
    final primary = risks.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return RiskBreakdown(
      overallScore: double.parse(clampedOverall.toStringAsFixed(1)),
      tempRisk: double.parse(tRisk.clamp(0.0, 100.0).toStringAsFixed(1)),
      humidityRisk: double.parse(hRisk.clamp(0.0, 100.0).toStringAsFixed(1)),
      gasRisk: double.parse(gRisk.clamp(0.0, 100.0).toStringAsFixed(1)),
      ventilationRisk: double.parse(vRisk.clamp(0.0, 100.0).toStringAsFixed(1)),
      classification: classification,
      primaryContributingFactor: primary,
      recommendation: classification.recommendation,
      tempDeviation: double.parse(tempDev.toStringAsFixed(1)),
      humidityDeviation: double.parse(humDev.toStringAsFixed(1)),
    );
  }

  /// Calculates conceptual spoilage progression index (0 - 100%) based on cumulative stress hours.
  static double estimateSpoilageProgression({
    required double avgTemp,
    required double avgHumidity,
    required int storageDays,
  }) {
    // Base aging factor: 0.15% per day under ideal conditions
    double baseRate = storageDays * 0.15;
    // Thermal stress multiplier
    double thermalStress = max(0.0, avgTemp - 20.0) * 0.08 * storageDays;
    // Moisture stress multiplier
    double moistureStress = max(0.0, avgHumidity - 68.0) * 0.10 * storageDays;

    return min(100.0, double.parse((baseRate + thermalStress + moistureStress).toStringAsFixed(1)));
  }
}
