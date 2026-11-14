import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utilities/risk_calculator.dart';
import '../../../data/models/sensor_reading.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';

class MathematicalModellingScreen extends ConsumerStatefulWidget {
  const MathematicalModellingScreen({super.key});

  @override
  ConsumerState<MathematicalModellingScreen> createState() => _MathematicalModellingScreenState();
}

class _MathematicalModellingScreenState extends ConsumerState<MathematicalModellingScreen> {
  int _simulatedStorageDays = 14;

  @override
  Widget build(BuildContext context) {
    final sensorState = ref.watch(sensorNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);

    final reading = sensorState.latestReading ?? SensorReading(
      timestamp: DateTime.now(),
      temperature: 22.5,
      humidity: 64.0,
      mq3RawAdc: 855,
      mq3Baseline: 850,
      mq3DeltaPercent: 0.6,
      fanActive: false,
      humidifierActive: false,
      isSimulated: true,
    );

    final risk = RiskCalculator.calculate(reading: reading, settings: settings);

    final spoilageEstimate = RiskCalculator.estimateSpoilageProgression(
      avgTemp: reading.temperature,
      avgHumidity: reading.humidity,
      storageDays: _simulatedStorageDays,
    );

    Color scoreColor = AppConstants.statusGreen;
    if (risk.classification == HealthClassification.critical) {
      scoreColor = AppConstants.statusRed;
    } else if (risk.classification == HealthClassification.highRisk) {
      scoreColor = Colors.deepOrange;
    } else if (risk.classification == HealthClassification.attentionRequired) {
      scoreColor = AppConstants.statusAmber;
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Mathematical Modelling', showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overall Risk Score Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.subtleBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Composite Environmental Risk Score',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Multi-criteria weighted index (0–100)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      StatusBadge(label: risk.classification.displayName, color: scoreColor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${risk.overallScore}',
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: scoreColor),
                      ),
                      const SizedBox(width: 8),
                      const Text('/ 100', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Primary Stress Contributor: ${risk.primaryContributingFactor}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      risk.recommendation,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: scoreColor, fontWeight: FontWeight.w500, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Component Breakdown Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Risk Component Breakdown',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                  ),
                  const SizedBox(height: 12),
                  _buildRiskBar('Temperature Risk (Wt: ${(settings.weightTemp * 100).round()}%)', risk.tempRisk, AppConstants.primaryForest, 'Δ: ${risk.tempDeviation > 0 ? "+" : ""}${risk.tempDeviation}°C'),
                  const SizedBox(height: 10),
                  _buildRiskBar('Humidity Risk (Wh: ${(settings.weightHumidity * 100).round()}%)', risk.humidityRisk, const Color(0xFF0284C7), 'Δ: ${risk.humidityDeviation > 0 ? "+" : ""}${risk.humidityDeviation}%'),
                  const SizedBox(height: 10),
                  _buildRiskBar('Gas Proxy Risk (Wg: ${(settings.weightGas * 100).round()}%)', risk.gasRisk, Colors.purple, 'Δ: +${reading.mq3DeltaPercent.toStringAsFixed(1)}%'),
                  const SizedBox(height: 10),
                  _buildRiskBar('Ventilation Risk (Wv: ${(settings.weightVentilation * 100).round()}%)', risk.ventilationRisk, Colors.orange, reading.fanActive ? 'Fan Active' : 'Fan Idle'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Conceptual Spoilage Progression Estimator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conceptual Spoilage Progression Model',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Simulates cumulative thermal & moisture stress integration over storage duration.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Storage Duration:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('$_simulatedStorageDays Days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _simulatedStorageDays.toDouble(),
                    min: 1.0,
                    max: 60.0,
                    divisions: 59,
                    activeColor: AppConstants.primaryForest,
                    onChanged: (val) => setState(() => _simulatedStorageDays = val.round()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Estimated Spoilage Stress Index:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$spoilageEstimate %', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: spoilageEstimate > 20 ? AppConstants.statusAmber : AppConstants.statusGreen)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (spoilageEstimate / 100.0).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: spoilageEstimate > 20 ? AppConstants.statusAmber : AppConstants.statusGreen,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Mathematical Equations Reference Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppConstants.subtleBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mathematical Formulation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.primaryForest),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Risk Score = (Wt × Rtemp) + (Wh × Rhumid) + (Wg × Rgas) + (Wv × Rvent)\n'
                    '• Deviation ΔT = Tcurrent - Ttarget (Target: 20.0°C)\n'
                    '• Deviation ΔH = Hcurrent - Htarget (Target: 65.0% RH)\n'
                    '• Constraints: Wt + Wh + Wg + Wv = 1.0\n'
                    '• Risk Classifications: Good (<25), Attention (25-49), High (50-74), Critical (75-100)',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.4, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBar(String title, double score, Color color, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            Text('$score / 100 ($sub)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (score / 100.0).clamp(0.0, 1.0),
          backgroundColor: const Color(0xFFF1F5F9),
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
