import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utilities/csv_exporter.dart';
import '../../../data/models/gas_test_session.dart';
import '../../../data/models/activity_event.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../live_sensors/widgets/live_chart_painter.dart';

class GasSensorTestScreen extends ConsumerStatefulWidget {
  const GasSensorTestScreen({super.key});

  @override
  ConsumerState<GasSensorTestScreen> createState() => _GasSensorTestScreenState();
}

class _GasSensorTestScreenState extends ConsumerState<GasSensorTestScreen> {
  GasTestPhase _phase = GasTestPhase.idle;
  int _configuredDuration = 120; // Default 120 seconds
  int _elapsedSeconds = 0;
  Timer? _testTimer;

  int _baselineAdc = 850;
  int _currentAdc = 850;
  int _peakAdc = 850;
  double _peakDeltaPercent = 0.0;
  int _recoveryTimeSeconds = 0;

  final List<GasTestPoint> _testPoints = [];
  final List<double> _chartPoints = [];

  @override
  void dispose() {
    _testTimer?.cancel();
    super.dispose();
  }

  void _startTestProtocol() {
    setState(() {
      _phase = GasTestPhase.warmingUp;
      _elapsedSeconds = 0;
      _testPoints.clear();
      _chartPoints.clear();
      _peakAdc = 850;
      _peakDeltaPercent = 0.0;
      _recoveryTimeSeconds = 0;
    });

    _testTimer?.cancel();
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;

        // Phase Transition Logic
        if (_phase == GasTestPhase.warmingUp) {
          if (_elapsedSeconds >= 10) {
            _phase = GasTestPhase.baselineAcquisition;
          }
        } else if (_phase == GasTestPhase.baselineAcquisition) {
          if (_elapsedSeconds >= 18) {
            final settings = ref.read(settingsNotifierProvider);
            _baselineAdc = settings.mq3Baseline;
            _currentAdc = _baselineAdc;
            _peakAdc = _baselineAdc;
            _phase = GasTestPhase.readyToTest;
          }
        } else if (_phase == GasTestPhase.readyToTest) {
          if (_elapsedSeconds >= 24) {
            _phase = GasTestPhase.testActive;
          }
        } else if (_phase == GasTestPhase.testActive) {
          // Dynamic curve progression
          final relSec = _elapsedSeconds - 24;
          if (relSec < 20) {
            // Rising edge (vapour exposure)
            _currentAdc += Random().nextInt(45) + 20;
          } else if (relSec < 35) {
            // Plateau / Peak
            _currentAdc += Random().nextInt(10) - 5;
            _phase = GasTestPhase.peakRecorded;
          } else {
            // Recovery phase
            _phase = GasTestPhase.recovering;
            _currentAdc = max(_baselineAdc, _currentAdc - (Random().nextInt(25) + 10));
          }

          if (_currentAdc > _peakAdc) {
            _peakAdc = _currentAdc;
          }
          final delta = ((_currentAdc - _baselineAdc) / _baselineAdc) * 100;
          if (delta > _peakDeltaPercent) {
            _peakDeltaPercent = double.parse(delta.toStringAsFixed(1));
          }

          final point = GasTestPoint(
            second: _elapsedSeconds,
            adc: _currentAdc,
            deltaPercent: double.parse(delta.toStringAsFixed(1)),
          );
          _testPoints.add(point);
          _chartPoints.add(_currentAdc.toDouble());

          if (_elapsedSeconds >= _configuredDuration) {
            _completeTest();
          }
        } else if (_phase == GasTestPhase.peakRecorded || _phase == GasTestPhase.recovering) {
          // Continue recovery tracking
          _currentAdc = max(_baselineAdc, _currentAdc - (Random().nextInt(25) + 10));
          if (_currentAdc <= _baselineAdc + 20 && _recoveryTimeSeconds == 0) {
            _recoveryTimeSeconds = _elapsedSeconds - 35;
          }

          final delta = ((_currentAdc - _baselineAdc) / _baselineAdc) * 100;
          final point = GasTestPoint(
            second: _elapsedSeconds,
            adc: _currentAdc,
            deltaPercent: double.parse(delta.toStringAsFixed(1)),
          );
          _testPoints.add(point);
          _chartPoints.add(_currentAdc.toDouble());

          if (_elapsedSeconds >= _configuredDuration) {
            _completeTest();
          }
        }
      });
    });
  }

  void _completeTest() {
    _testTimer?.cancel();
    setState(() {
      _phase = GasTestPhase.completed;
      if (_recoveryTimeSeconds == 0) {
        _recoveryTimeSeconds = max(15, _elapsedSeconds - 45);
      }
    });

    final session = GasTestSession(
      id: 'GST-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      durationSeconds: _elapsedSeconds,
      baselineAdc: _baselineAdc,
      peakAdc: _peakAdc,
      finalAdc: _currentAdc,
      peakDeltaPercent: _peakDeltaPercent,
      recoveryTimeSeconds: _recoveryTimeSeconds,
      samples: List.from(_testPoints),
      notes: 'Controlled alcohol vapour proxy test completed successfully.',
    );

    // Record in Activity History
    ref.read(eventsNotifierProvider.notifier).addEvent(
      ActivityEvent(
        id: session.id,
        timestamp: DateTime.now(),
        category: EventCategory.gasTest,
        severity: EventSeverity.info,
        title: 'Gas Sensor Test Completed',
        description: 'Duration: ${_elapsedSeconds}s • Peak: $_peakAdc ADC (+${_peakDeltaPercent.toStringAsFixed(1)}%) • Recovery: ${_recoveryTimeSeconds}s',
        triggerSource: 'Gas Test Protocol',
        operatingMode: 'TEST',
        gasAdc: _peakAdc,
      ),
    );
  }

  void _stopTest() {
    _testTimer?.cancel();
    setState(() {
      _phase = GasTestPhase.idle;
      _elapsedSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final double progress = (_elapsedSeconds / _configuredDuration).clamp(0.0, 1.0);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Gas Sensor Test', showBack: true),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(14, 14, 14, MediaQuery.of(context).viewPadding.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Safe Testing Protocol Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.health_and_safety_outlined, color: Colors.orange, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Safe Laboratory Testing Procedure',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF9A3412)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• NEVER expose MQ-3 to open flames or cigarette lighters.\n'
                          '• Use a cotton swab lightly dampened with isopropyl alcohol held 3–5 cm from the sensor grille.\n'
                          '• Allow full recovery before repeating trials.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF7C2D12), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Test Status Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Controlled Response Protocol',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _phase.displayName,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _phase == GasTestPhase.testActive ? Colors.purple : const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: '${_elapsedSeconds}s / ${_configuredDuration}s',
                        color: _phase == GasTestPhase.testActive ? Colors.purple : AppConstants.primaryForest,
                        icon: Icons.timer_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: AppConstants.primaryForest,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _phase.stepDescription,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile('Baseline ADC', '$_baselineAdc', Icons.compass_calibration),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile('Current ADC', '$_currentAdc', Icons.speed),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile('Peak ADC', '$_peakAdc', Icons.arrow_upward),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile('Peak Δ', '+${_peakDeltaPercent.toStringAsFixed(1)}%', Icons.percent),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Real-Time Response Graph
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
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sensor Response Curve',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                      ),
                      Text('Raw ADC vs Seconds', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 170,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: LiveChartPainter(
                        dataPoints: _chartPoints.isNotEmpty ? _chartPoints : [850.0, 850.0],
                        lineColor: Colors.purple,
                        thresholdLine: (settings.mq3Baseline * 1.25),
                        thresholdColor: AppConstants.statusAmber,
                        minY: 600.0,
                        maxY: 2200.0,
                        unit: 'ADC',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            if (_phase == GasTestPhase.idle || _phase == GasTestPhase.completed) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text(_phase == GasTestPhase.completed ? 'Run Another Test' : 'Begin 9-Step Protocol'),
                onPressed: _startTestProtocol,
              ),
              if (_phase == GasTestPhase.completed) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Export Test Curve to CSV'),
                  onPressed: () {
                    final session = GasTestSession(
                      id: 'GST-${DateTime.now().millisecondsSinceEpoch}',
                      timestamp: DateTime.now(),
                      durationSeconds: _elapsedSeconds,
                      baselineAdc: _baselineAdc,
                      peakAdc: _peakAdc,
                      finalAdc: _currentAdc,
                      peakDeltaPercent: _peakDeltaPercent,
                      recoveryTimeSeconds: _recoveryTimeSeconds,
                      samples: List.from(_testPoints),
                    );
                    final csv = CsvExporter.exportGasTestToCsv(session);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Test Curve CSV'),
                        content: SingleChildScrollView(child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                      ),
                    );
                  },
                ),
              ],
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.statusRed),
                icon: const Icon(Icons.stop, size: 20),
                label: const Text('Abort Test Protocol'),
                onPressed: _stopTest,
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.subtleBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(height: 4),
          Text(
            val,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
