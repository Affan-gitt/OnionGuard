import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../dashboard/widgets/animated_fan_widget.dart';

class ControlsScreen extends ConsumerStatefulWidget {
  const ControlsScreen({super.key});

  @override
  ConsumerState<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends ConsumerState<ControlsScreen> {
  bool _isCalibrating = false;
  String? _calibrationFeedback;

  Future<void> _handleCalibrate() async {
    setState(() {
      _isCalibrating = true;
      _calibrationFeedback = null;
    });

    final sensorState = ref.read(sensorNotifierProvider);
    final reading = sensorState.latestReading;
    final currentAdc = reading?.mq3RawAdc ?? 850;

    // Save new baseline to settings
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
    final currentSettings = ref.read(settingsNotifierProvider);
    await settingsNotifier.updateSettings(
      currentSettings.copyWith(mq3Baseline: currentAdc),
    );

    // Send calibrate command to ESP32 Wi-Fi if connected
    final wifi = ref.read(wifiEsp32ServiceProvider);
    if (wifi.isConnected) {
      await wifi.sendActuatorCommand(device: 'calibrate', state: true);
    }

    if (mounted) {
      setState(() {
        _isCalibrating = false;
        _calibrationFeedback = 'MQ-3 clean air baseline calibrated to $currentAdc ADC.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Baseline calibrated to $currentAdc ADC successfully.'),
          backgroundColor: AppConstants.emerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actuator = ref.watch(actuatorNotifierProvider);
    final sensorState = ref.watch(sensorNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final reading = sensorState.latestReading;

    final double hum = reading?.humidity ?? 60.0;
    final bool isInterlocked = hum >= settings.maxHumiditySafety;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        title: const Text('System Controls'),
        backgroundColor: AppConstants.darkBg,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.of(context).viewPadding.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==============================================================
              // 1. EXHAUST VENTILATION CONTROL CARD
              // ==============================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: actuator.fanState
                        ? AppConstants.emerald.withValues(alpha: 0.6)
                        : AppConstants.borderEmerald,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            AnimatedFanWidget(
                              isRunning: actuator.fanState,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Exhaust Ventilation Fan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppConstants.cream,
                                  ),
                                ),
                                Text(
                                  actuator.fanState ? 'Relay Active (GPIO 18 HIGH)' : 'Relay Idle (GPIO 18 LOW)',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: actuator.fanState ? AppConstants.emerald : AppConstants.mutedGreenGrey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: actuator.fanState,
                          activeColor: AppConstants.emerald,
                          onChanged: (val) {
                            ref.read(actuatorNotifierProvider.notifier).toggleFan(val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: AppConstants.borderEmerald, height: 1),
                    const SizedBox(height: 10),

                    // Mode Selection: AUTO vs MANUAL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Operating Mode:',
                          style: TextStyle(fontSize: 12, color: AppConstants.mutedGreenGrey),
                        ),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'AUTO', label: Text('AUTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            ButtonSegment(value: 'MANUAL', label: Text('MANUAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          ],
                          selected: {actuator.fanMode},
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppConstants.emerald.withValues(alpha: 0.25);
                              }
                              return AppConstants.darkCardSurface;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppConstants.emerald;
                              }
                              return AppConstants.mutedGreenGrey;
                            }),
                          ),
                          onSelectionChanged: (Set<String> newSelection) {
                            ref.read(actuatorNotifierProvider.notifier).setFanMode(newSelection.first);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==============================================================
              // 2. GAS DEMONSTRATION / HUMIDIFIER ACTUATOR CARD
              // ==============================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isInterlocked
                        ? AppConstants.statusCritical.withValues(alpha: 0.6)
                        : (actuator.humidifierState ? AppConstants.lime.withValues(alpha: 0.6) : AppConstants.borderEmerald),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isInterlocked ? AppConstants.statusCritical : AppConstants.lime).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.cyclone,
                                size: 24,
                                color: isInterlocked ? AppConstants.statusCritical : AppConstants.lime,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Gas-Response Actuator',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppConstants.cream,
                                  ),
                                ),
                                Text(
                                  isInterlocked
                                      ? 'LOCKED BY SAFETY INTERLOCK (RH >= ${settings.maxHumiditySafety}%)'
                                      : (actuator.humidifierState ? 'Active (GPIO 19 HIGH)' : 'Idle (GPIO 19 LOW)'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isInterlocked ? AppConstants.statusCritical : (actuator.humidifierState ? AppConstants.lime : AppConstants.mutedGreenGrey),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: actuator.humidifierState,
                          activeColor: AppConstants.lime,
                          onChanged: isInterlocked
                              ? null
                              : (val) {
                                  ref.read(actuatorNotifierProvider.notifier).toggleHumidifier(val);
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==============================================================
              // 3. MQ-3 SENSOR BASELINE CALIBRATION CARD
              // ==============================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.borderEmerald, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConstants.warmGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune, color: AppConstants.warmGold, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MQ-3 Gas Sensor Calibration',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppConstants.cream,
                                ),
                              ),
                              Text(
                                'Sets baseline in clean, ventilated ambient atmosphere',
                                style: TextStyle(fontSize: 10.5, color: AppConstants.mutedGreenGrey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Baseline: ${settings.mq3Baseline} ADC',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.cream),
                        ),
                        Text(
                          'Live Reading: ${reading?.mq3RawAdc ?? 850} ADC',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.emerald),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.darkCardSurface,
                        foregroundColor: AppConstants.emerald,
                        side: const BorderSide(color: AppConstants.borderEmerald, width: 1),
                        minimumSize: const Size.fromHeight(42),
                      ),
                      icon: _isCalibrating
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.emerald))
                          : const Icon(Icons.auto_fix_high, size: 16),
                      label: Text(_isCalibrating ? 'CALIBRATING...' : 'CALIBRATE TO CURRENT READING'),
                      onPressed: _isCalibrating ? null : _handleCalibrate,
                    ),
                    if (_calibrationFeedback != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _calibrationFeedback!,
                        style: const TextStyle(fontSize: 11, color: AppConstants.emerald, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==============================================================
              // 4. HARDWARE SAFETY INTERLOCK & STATUS
              // ==============================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppConstants.deepForest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.borderEmerald, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SAFETY INTERLOCK & FAILSAFE ARCHITECTURE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppConstants.mutedGreenGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSafetyRow(
                      'High Humidity Safety Cutoff',
                      isInterlocked ? 'ENGAGED (LOCKED OFF)' : 'ARMED (NORMAL)',
                      isInterlocked ? AppConstants.statusCritical : AppConstants.emerald,
                    ),
                    _buildSafetyRow(
                      'Thermal Exhaust Trigger',
                      'Threshold: >= ${settings.triggerTemp}°C (Reset <= ${settings.resetTemp}°C)',
                      AppConstants.cream,
                    ),
                    _buildSafetyRow(
                      'Gas Spike Trigger Limit',
                      '+${settings.mq3TriggerDeltaPercent.toStringAsFixed(0)}% Above Clean Air Baseline',
                      AppConstants.warmGold,
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

  Widget _buildSafetyRow(String title, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey)),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
        ],
      ),
    );
  }
}
