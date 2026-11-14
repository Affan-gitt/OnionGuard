import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/sensor_reading.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/ble_scan_dialog.dart';
import '../../../shared/widgets/usb_connection_dialog.dart';
import '../widgets/live_chart_painter.dart';

class LiveSensorsScreen extends ConsumerStatefulWidget {
  const LiveSensorsScreen({super.key});

  @override
  ConsumerState<LiveSensorsScreen> createState() => _LiveSensorsScreenState();
}

class _LiveSensorsScreenState extends ConsumerState<LiveSensorsScreen> {
  String _timeRange = '5m'; // 5m, 30m, 1h, 24h, 7d
  int _activeChartIndex = 0; // 0: Temp, 1: Humidity, 2: Gas ADC

  @override
  Widget build(BuildContext context) {
    final sensorState = ref.watch(sensorNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);

    final reading = sensorState.latestReading;
    final bool isDisconnected = !sensorState.isHardwareConnected && !sensorState.isSimulation;
    final bool isWaiting = sensorState.isHardwareConnected && reading == null && !sensorState.isSimulation;

    // Filter history based on time range
    final history = sensorState.history;
    List<SensorReading> filteredHistory = history;
    if (_timeRange == '5m') {
      filteredHistory = history.length > 30 ? history.sublist(history.length - 30) : history;
    } else if (_timeRange == '30m') {
      filteredHistory = history.length > 70 ? history.sublist(history.length - 70) : history;
    }

    // Min, Max, Avg calculations
    double minTemp = 0, maxTemp = 0, avgTemp = 0;
    double minHum = 0, maxHum = 0, avgHum = 0;
    int minGas = 0, maxGas = 0, avgGas = 0;

    if (filteredHistory.isNotEmpty) {
      final temps = filteredHistory.map((r) => r.temperature).where((t) => t > -100).toList();
      final hums = filteredHistory.map((r) => r.humidity).where((h) => h > -100).toList();
      final gases = filteredHistory.map((r) => r.mq3RawAdc).where((g) => g > 0).toList();

      if (temps.isNotEmpty) {
        minTemp = temps.reduce(min);
        maxTemp = temps.reduce(max);
        avgTemp = temps.reduce((a, b) => a + b) / temps.length;
      }
      if (hums.isNotEmpty) {
        minHum = hums.reduce(min);
        maxHum = hums.reduce(max);
        avgHum = hums.reduce((a, b) => a + b) / hums.length;
      }
      if (gases.isNotEmpty) {
        minGas = gases.reduce(min);
        maxGas = gases.reduce(max);
        avgGas = (gases.reduce((a, b) => a + b) / gases.length).round();
      }
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Live Room Sensors', showBack: true),
      body: SafeArea(
        top: false,
        bottom: true,
        child: isDisconnected
            ? _buildDisconnectedState(context)
            : isWaiting
                ? _buildWaitingForDataState(context)
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(14, 14, 14, MediaQuery.of(context).viewPadding.bottom + 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // Status & Timestamp Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppConstants.subtleBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: sensorState.isSimulation
                                          ? AppConstants.statusAmber
                                          : AppConstants.statusGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      sensorState.isSimulation
                                          ? 'SIMULATED DATASTREAM'
                                          : (sensorState.isUsbConnected
                                              ? 'ESP32-H2 USB-C CDC FEED'
                                              : 'ESP32-H2 BLE FEED'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: sensorState.isSimulation
                                            ? AppConstants.statusAmber
                                            : AppConstants.statusGreen,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              reading != null
                                  ? 'Updated: ${DateFormat('HH:mm:ss').format(reading.timestamp)}'
                                  : 'Waiting for stream...',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 12),

                  // 3 Key Metrics Cards
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: 'Temperature',
                          value: reading != null ? reading.temperature.toStringAsFixed(1) : '--',
                          unit: '°C',
                          subtitle: 'Target: ${settings.targetTemp}°C',
                          icon: Icons.thermostat,
                          color: reading != null && reading.temperature >= settings.triggerTemp
                              ? AppConstants.statusRed
                              : AppConstants.primaryForest,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricCard(
                          title: 'Relative Humidity',
                          value: reading != null ? reading.humidity.toStringAsFixed(1) : '--',
                          unit: '%',
                          subtitle: 'Target: ${settings.targetHumidity}%',
                          icon: Icons.water_drop_outlined,
                          color: reading != null && reading.humidity >= settings.maxHumiditySafety
                              ? AppConstants.statusRed
                              : const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: 'MQ-3 Raw ADC',
                          value: reading != null ? reading.mq3RawAdc.toString() : '--',
                          unit: 'ADC',
                          subtitle: 'Baseline: ${settings.mq3Baseline}',
                          icon: Icons.science_outlined,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricCard(
                          title: 'Gas Proxy Δ',
                          value: reading != null ? '${reading.mq3DeltaPercent > 0 ? "+" : ""}${reading.mq3DeltaPercent.toStringAsFixed(1)}' : '--',
                          unit: '%',
                          subtitle: 'Trigger: +${settings.mq3TriggerDeltaPercent}%',
                          icon: Icons.trending_up,
                          color: reading != null && reading.mq3DeltaPercent >= settings.mq3TriggerDeltaPercent
                              ? AppConstants.statusAmber
                              : AppConstants.primaryForest,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Interactive Chart Section
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
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildChartTab(0, 'Temperature', Icons.thermostat),
                              const SizedBox(width: 6),
                              _buildChartTab(1, 'Humidity', Icons.water_drop),
                              const SizedBox(width: 6),
                              _buildChartTab(2, 'Gas ADC', Icons.science),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Time range selectors
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildTimeRangeButton('5m'),
                              _buildTimeRangeButton('30m'),
                              _buildTimeRangeButton('1h'),
                              _buildTimeRangeButton('24h'),
                              _buildTimeRangeButton('7d'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Render Canvas Chart
                        SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _createChartPainter(filteredHistory, settings),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Min / Avg / Max Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppConstants.subtleBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Min', _getStatValue(minTemp, minHum, minGas)),
                              const VerticalDivider(width: 16),
                              _buildStatItem('Avg', _getStatValue(avgTemp, avgHum, avgGas.toDouble())),
                              const VerticalDivider(width: 16),
                              _buildStatItem('Max', _getStatValue(maxTemp, maxHum, maxGas)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sensor Scientific Disclaimer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Engineering Disclaimer: The MQ-3 is an alcohol-vapour sensor utilized as a qualitative volatile gas proxy. It is not an ethylene-specific gas chromatograph. Raw ADC readings reflect relative resistance shifts.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
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

  Widget _buildDisconnectedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.usb_off, size: 48, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'HARDWARE DISCONNECTED',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            const Text(
              'No physical link detected with ESP32-H2.\nIn Live Mode, readings are strictly hardware-sourced and never synthesized.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.usb, size: 16),
              label: const Text('Connect via USB-C (Primary)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryForest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showUsbConnectionModal(context, ref),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.bluetooth_searching, size: 16),
              label: const Text('Scan & Connect over BLE'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showBleScanModal(context, ref),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Icons.play_circle_outline, size: 16),
              label: const Text('Launch Interactive Demo Mode'),
              onPressed: () {
                ref.read(simulationServiceProvider).startSimulation();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Demonstration Mode activated! Live simulated telemetry streaming.'),
                    backgroundColor: AppConstants.statusAmber,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForDataState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.statusAmber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppConstants.statusAmber),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'WAITING FOR SENSOR DATA',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
            ),
            const SizedBox(height: 8),
            const Text(
              'ESP32-H2 physical link established.\nAwaiting DHT11 and MQ-3 newline-delimited JSON telemetry frame...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTab(int index, String label, IconData icon) {
    final bool isSelected = _activeChartIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeChartIndex = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryForest : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeButton(String range) {
    final bool isSelected = _timeRange == range;
    return InkWell(
      onTap: () => setState(() => _timeRange = range),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.lightGrey : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          range,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppConstants.primaryForest : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  LiveChartPainter _createChartPainter(List<SensorReading> history, settings) {
    List<double> points = [];
    Color color = AppConstants.primaryForest;
    double? threshold;
    double minY = 0, maxY = 50;
    String unit = '°C';

    if (_activeChartIndex == 0) {
      points = history.map((r) => r.temperature).where((t) => t > -100).toList();
      color = AppConstants.primaryForest;
      threshold = settings.triggerTemp;
      minY = 15.0;
      maxY = 35.0;
      unit = '°C';
    } else if (_activeChartIndex == 1) {
      points = history.map((r) => r.humidity).where((h) => h > -100).toList();
      color = const Color(0xFF0284C7);
      threshold = settings.maxHumiditySafety;
      minY = 40.0;
      maxY = 90.0;
      unit = '%';
    } else {
      points = history.map((r) => r.mq3RawAdc.toDouble()).where((g) => g > 0).toList();
      color = Colors.purple;
      threshold = (settings.mq3Baseline * (1 + settings.mq3TriggerDeltaPercent / 100)).toDouble();
      minY = 600.0;
      maxY = 2000.0;
      unit = 'ADC';
    }

    if (points.isEmpty) {
      points = [22.0, 22.0];
    }

    return LiveChartPainter(
      dataPoints: points,
      lineColor: color,
      thresholdLine: threshold,
      thresholdColor: AppConstants.statusAmber,
      minY: minY,
      maxY: maxY,
      unit: unit,
    );
  }

  String _getStatValue(num temp, num hum, num gas) {
    if (_activeChartIndex == 0) return '${temp.toStringAsFixed(1)} °C';
    if (_activeChartIndex == 1) return '${hum.toStringAsFixed(1)} %';
    return '$gas ADC';
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }
}
