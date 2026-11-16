import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utilities/risk_calculator.dart';
import '../../../data/models/sensor_reading.dart';
import '../../live_sensors/widgets/live_chart_painter.dart';
import '../../onion_inventory/screens/onion_shelves_screen.dart';
import '../../modelling/screens/mathematical_modelling_screen.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _timeFilter = '24h'; // '1h', '6h', '24h', '7d'
  int _activeChartIndex = 0;   // 0: Temp, 1: Humidity, 2: Gas Response

  @override
  Widget build(BuildContext context) {
    final sensorState = ref.watch(sensorNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final actuator = ref.watch(actuatorNotifierProvider);
    final history = sensorState.history;
    final latest = sensorState.latestReading;

    // Filter historical data points
    List<SensorReading> filtered = history;
    if (_timeFilter == '1h' && history.length > 20) {
      filtered = history.sublist(history.length - 20);
    } else if (_timeFilter == '6h' && history.length > 60) {
      filtered = history.sublist(history.length - 60);
    }

    // Mathematical summary calculations
    double minTemp = 0, maxTemp = 0, avgTemp = 0;
    double minHum = 0, maxHum = 0, avgHum = 0;
    int minGas = 0, maxGas = 0, avgGas = 0;
    int pointsOutsideTempLimit = 0;
    int pointsOutsideHumLimit = 0;

    if (filtered.isNotEmpty) {
      final temps = filtered.map((r) => r.temperature).where((t) => t > -100).toList();
      final hums = filtered.map((r) => r.humidity).where((h) => h > -100).toList();
      final gases = filtered.map((r) => r.mq3RawAdc).where((g) => g > 0).toList();

      if (temps.isNotEmpty) {
        minTemp = temps.reduce(min);
        maxTemp = temps.reduce(max);
        avgTemp = temps.reduce((a, b) => a + b) / temps.length;
        pointsOutsideTempLimit = temps.where((t) => t >= settings.triggerTemp).length;
      }
      if (hums.isNotEmpty) {
        minHum = hums.reduce(min);
        maxHum = hums.reduce(max);
        avgHum = hums.reduce((a, b) => a + b) / hums.length;
        pointsOutsideHumLimit = hums.where((h) => h >= settings.maxHumiditySafety).length;
      }
      if (gases.isNotEmpty) {
        minGas = gases.reduce(min);
        maxGas = gases.reduce(max);
        avgGas = (gases.reduce((a, b) => a + b) / gases.length).round();
      }
    }

    // Model-based Spoilage Risk Calculation
    final risk = latest != null
        ? RiskCalculator.calculate(reading: latest, settings: settings)
        : null;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        title: const Text('Environmental Analytics'),
        backgroundColor: AppConstants.darkBg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined, color: AppConstants.emerald, size: 20),
            tooltip: 'Storage Shelves',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OnionShelvesScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.calculate_outlined, color: AppConstants.lime, size: 20),
            tooltip: 'Mathematical Model',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MathematicalModellingScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.of(context).viewPadding.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==============================================================
              // 1. MODEL-BASED ESTIMATE CARD
              // ==============================================================
              if (risk != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: risk.overallScore > 50 ? AppConstants.statusCritical : AppConstants.borderEmerald,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'STORAGE RISK INDEX (ESTIMATE)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppConstants.mutedGreenGrey,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (risk.overallScore > 50 ? AppConstants.statusCritical : AppConstants.emerald).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              risk.classification.displayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: risk.overallScore > 50 ? AppConstants.statusCritical : AppConstants.emerald,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${risk.overallScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: risk.overallScore > 50 ? AppConstants.statusCritical : AppConstants.emerald,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  risk.recommendation,
                                  style: const TextStyle(fontSize: 11.5, color: AppConstants.cream, height: 1.3),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '• Note: Model-based mathematical estimate, not an experimentally verified spoilage probability.',
                                  style: TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: AppConstants.mutedGreenGrey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ==============================================================
              // 2. METRIC SUMMARY CARDS (AVG, MIN, MAX)
              // ==============================================================
              Row(
                children: [
                  Expanded(
                    child: _buildMetricStatsCard(
                      title: 'Temperature',
                      avgVal: '${avgTemp.toStringAsFixed(1)}°C',
                      minVal: '${minTemp.toStringAsFixed(1)}°C',
                      maxVal: '${maxTemp.toStringAsFixed(1)}°C',
                      icon: Icons.thermostat,
                      accentColor: AppConstants.emerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricStatsCard(
                      title: 'Humidity',
                      avgVal: '${avgHum.toStringAsFixed(1)}%',
                      minVal: '${minHum.toStringAsFixed(1)}%',
                      maxVal: '${maxHum.toStringAsFixed(1)}%',
                      icon: Icons.water_drop_outlined,
                      accentColor: const Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildMetricStatsCard(
                title: 'MQ-3 Gas Vapour Proxy',
                avgVal: '$avgGas ADC',
                minVal: '$minGas ADC',
                maxVal: '$maxGas ADC',
                icon: Icons.science_outlined,
                accentColor: AppConstants.warmGold,
              ),
              const SizedBox(height: 12),

              // ==============================================================
              // 3. OPERATING DURATION & THRESHOLD VIOLATION CARD
              // ==============================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppConstants.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.borderEmerald, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SYSTEM OPERATING & COMPLIANCE DURATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppConstants.mutedGreenGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDurationItem(
                          label: 'Exhaust Fan State',
                          value: actuator.fanState ? 'Active (ON)' : 'Idle (Standby)',
                          color: actuator.fanState ? AppConstants.emerald : AppConstants.mutedGreenGrey,
                        ),
                        _buildDurationItem(
                          label: 'Exceeding Temp',
                          value: '$pointsOutsideTempLimit readings',
                          color: pointsOutsideTempLimit > 0 ? AppConstants.statusCritical : AppConstants.emerald,
                        ),
                        _buildDurationItem(
                          label: 'Exceeding RH',
                          value: '$pointsOutsideHumLimit readings',
                          color: pointsOutsideHumLimit > 0 ? AppConstants.warmGold : AppConstants.emerald,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ==============================================================
              // 4. HISTORICAL SENSOR GRAPH
              // ==============================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppConstants.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.borderEmerald, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildTabPill(0, 'Temp', Icons.thermostat),
                            const SizedBox(width: 6),
                            _buildTabPill(1, 'Humidity', Icons.water_drop_outlined),
                            const SizedBox(width: 6),
                            _buildTabPill(2, 'Gas ADC', Icons.science_outlined),
                          ],
                        ),
                        Row(
                          children: [
                            _buildTimeFilterPill('1h'),
                            _buildTimeFilterPill('6h'),
                            _buildTimeFilterPill('24h'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 160,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _createChartPainter(filtered, settings),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricStatsCard({
    required String title,
    required String avgVal,
    required String minVal,
    required String maxVal,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.borderEmerald, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.cream)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Average:', style: TextStyle(fontSize: 10, color: AppConstants.mutedGreenGrey)),
              Text(avgVal, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accentColor)),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Min / Max:', style: TextStyle(fontSize: 10, color: AppConstants.mutedGreenGrey)),
              Text('$minVal / $maxVal', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppConstants.cream)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, color: AppConstants.mutedGreenGrey)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _buildTabPill(int index, String label, IconData icon) {
    final isSelected = _activeChartIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeChartIndex = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.emerald.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? Border.all(color: AppConstants.emerald, width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 11, color: isSelected ? AppConstants.emerald : AppConstants.mutedGreenGrey),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppConstants.cream : AppConstants.mutedGreenGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterPill(String filter) {
    final isSelected = _timeFilter == filter;
    return InkWell(
      onTap: () => setState(() => _timeFilter = filter),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.emerald.withValues(alpha: 0.25) : AppConstants.darkCardSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(filter, style: TextStyle(fontSize: 9.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppConstants.emerald : AppConstants.mutedGreenGrey)),
      ),
    );
  }

  LiveChartPainter _createChartPainter(List<SensorReading> history, settings) {
    List<double> points = [];
    Color color = AppConstants.emerald;
    double? threshold;
    double minY = 0, maxY = 50;
    String unit = '°C';

    if (_activeChartIndex == 0) {
      points = history.map((r) => r.temperature).where((t) => t > -100).toList();
      color = AppConstants.emerald;
      threshold = settings.triggerTemp;
      minY = 15.0;
      maxY = 40.0;
      unit = '°C';
    } else if (_activeChartIndex == 1) {
      points = history.map((r) => r.humidity).where((h) => h > -100).toList();
      color = const Color(0xFF38BDF8);
      threshold = settings.maxHumiditySafety;
      minY = 40.0;
      maxY = 90.0;
      unit = '%';
    } else {
      points = history.map((r) => r.mq3RawAdc.toDouble()).where((g) => g > 0).toList();
      color = AppConstants.warmGold;
      threshold = (settings.mq3Baseline * (1 + settings.mq3TriggerDeltaPercent / 100)).toDouble();
      minY = 200.0;
      maxY = 1500.0;
      unit = 'ADC';
    }

    if (points.isEmpty) points = [22.0, 22.0];

    return LiveChartPainter(
      dataPoints: points,
      lineColor: color,
      thresholdLine: threshold,
      thresholdColor: AppConstants.warmGold,
      minY: minY,
      maxY: maxY,
      unit: unit,
    );
  }
}
