import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/wifi_connection_dialog.dart';
import '../../../shared/widgets/usb_connection_dialog.dart';

class FanControlScreen extends ConsumerWidget {
  const FanControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actuator = ref.watch(actuatorNotifierProvider);
    final sensorState = ref.watch(sensorNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final reading = sensorState.latestReading;

    final currentTemp = reading?.temperature ?? 22.0;
    final currentHum = reading?.humidity ?? 64.0;
    final bool isInterlocked = currentHum >= settings.maxHumiditySafety;
    final bool isDisconnected = !sensorState.isHardwareConnected && !sensorState.isSimulation;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Fan, Cooling & Gas Response', showBack: true),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(14, 14, 14, MediaQuery.of(context).viewPadding.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Hardware Status Warning Banner
            if (isDisconnected) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Color(0xFFB45309), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HARDWARE DISCONNECTED',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Actuator toggles require physical ESP32 link. Connect via Wi-Fi or USB-C to operate relays.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primaryForest,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.wifi, size: 14),
                                label: const Text('Connect via Wi-Fi'),
                                onPressed: () => showWifiConnectionModal(context, ref),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.usb, size: 14),
                                label: const Text('USB-C'),
                                onPressed: () => showUsbConnectionModal(context, ref),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Exhaust Fan Section
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
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (actuator.fanState ? AppConstants.statusGreen : Colors.grey).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.mode_fan_off,
                                color: actuator.fanState ? AppConstants.statusGreen : Colors.grey,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Automated Exhaust Fan',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Ventilation & Thermal Control',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: actuator.fanState ? 'RUNNING' : 'STANDBY',
                        color: actuator.fanState ? AppConstants.statusGreen : AppConstants.statusGrey,
                        icon: actuator.fanState ? Icons.check_circle : Icons.pause_circle_outline,
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Mode Selector
                  Row(
                    children: [
                      const Text('Operating Mode:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      const Spacer(),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'AUTO', label: Text('Auto (Hysteresis)', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'MANUAL', label: Text('Manual', style: TextStyle(fontSize: 11))),
                            ],
                            selected: {actuator.fanMode},
                            onSelectionChanged: (val) {
                              ref.read(actuatorNotifierProvider.notifier).setFanMode(val.first);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Metrics Grid
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFBFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppConstants.subtleBorder),
                    ),
                    child: Column(
                      children: [
                        _buildRow('Trigger Threshold', '>= ${actuator.fanTriggerTemp}°C'),
                        const SizedBox(height: 6),
                        _buildRow('Reset (Hysteresis)', '<= ${actuator.fanResetTemp}°C'),
                        const SizedBox(height: 6),
                        _buildRow('Current Temperature', '${currentTemp.toStringAsFixed(1)} °C'),
                        const SizedBox(height: 6),
                        _buildRow(
                          'Last Activation',
                          actuator.fanLastActivated != null
                              ? DateFormat('HH:mm:ss').format(actuator.fanLastActivated!)
                              : 'None recorded',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Manual Control Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: actuator.fanState ? Colors.grey.shade300 : AppConstants.primaryForest,
                            foregroundColor: actuator.fanState ? Colors.black87 : Colors.white,
                          ),
                          icon: const Icon(Icons.power_settings_new, size: 16),
                          label: const Text('Manual ON'),
                          onPressed: actuator.fanState
                              ? null
                              : () async {
                                  final success = await ref.read(actuatorNotifierProvider.notifier).toggleFan(true);
                                  if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('COMMAND FAILED: Exhaust fan activation could not be verified by ESP32-H2.'),
                                        backgroundColor: AppConstants.statusRed,
                                      ),
                                    );
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppConstants.statusRed,
                            side: const BorderSide(color: AppConstants.statusRed),
                          ),
                          icon: const Icon(Icons.stop_circle_outlined, size: 16),
                          label: const Text('Manual OFF'),
                          onPressed: !actuator.fanState
                              ? null
                              : () async {
                                  final success = await ref.read(actuatorNotifierProvider.notifier).toggleFan(false);
                                  if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('COMMAND FAILED: Exhaust fan shutdown could not be verified by ESP32-H2.'),
                                        backgroundColor: AppConstants.statusRed,
                                      ),
                                    );
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Demonstration Gas Response Actuator
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
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (actuator.humidifierState ? Colors.purple : Colors.grey).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.air,
                                color: actuator.humidifierState ? Colors.purple : Colors.grey,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Gas-Response Actuator',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Demonstration Filtration Actuator',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: isInterlocked
                            ? 'INTERLOCK'
                            : (actuator.humidifierState ? 'ACTIVE' : 'STANDBY'),
                        color: isInterlocked
                            ? AppConstants.statusRed
                            : (actuator.humidifierState ? Colors.purple : AppConstants.statusGrey),
                        icon: isInterlocked ? Icons.lock : Icons.shield_outlined,
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Humidifier Safety Interlock Warning Banner
                  if (isInterlocked) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.statusRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppConstants.statusRed.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppConstants.statusRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Humidity Safety Interlock Engaged (${currentHum.toStringAsFixed(1)}% >= ${settings.maxHumiditySafety}%).\nActuator forced OFF to prevent bulb condensation and mould.',
                              style: const TextStyle(fontSize: 11, color: AppConstants.statusRed, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Mode Selector
                  Row(
                    children: [
                      const Text('Operating Mode:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      const Spacer(),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'AUTO', label: Text('Auto Gas Response', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'MANUAL', label: Text('Manual', style: TextStyle(fontSize: 11))),
                            ],
                            selected: {actuator.humidifierMode},
                            onSelectionChanged: isInterlocked
                                ? null
                                : (val) {
                                    ref.read(actuatorNotifierProvider.notifier).setHumidifierMode(val.first);
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Metrics Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFBFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppConstants.subtleBorder),
                    ),
                    child: Column(
                      children: [
                        _buildRow('Trigger Threshold', '+${actuator.humidifierTriggerPercent}% above baseline'),
                        const SizedBox(height: 6),
                        _buildRow('Humidity Safety Limit', '<= ${settings.maxHumiditySafety}% RH'),
                        const SizedBox(height: 6),
                        _buildRow('Current Humidity', '${currentHum.toStringAsFixed(1)}% RH'),
                        const SizedBox(height: 6),
                        _buildRow(
                          'Last Triggered',
                          actuator.humidifierLastTrigger != null
                              ? DateFormat('HH:mm:ss').format(actuator.humidifierLastTrigger!)
                              : 'None recorded',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Controls
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text('Test Trigger (10s)'),
                          onPressed: isInterlocked
                              ? null
                              : () async {
                                  final success = await ref.read(actuatorNotifierProvider.notifier).toggleHumidifier(true);
                                  if (!success) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('COMMAND FAILED: Humidifier actuator command rejected or hardware disconnected.'),
                                          backgroundColor: AppConstants.statusRed,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  Future.delayed(const Duration(seconds: 10), () {
                                    ref.read(actuatorNotifierProvider.notifier).toggleHumidifier(false);
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Demonstration gas response actuator triggered for 10s.')),
                                    );
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppConstants.statusRed,
                            side: const BorderSide(color: AppConstants.statusRed),
                          ),
                          icon: const Icon(Icons.stop, size: 16),
                          label: const Text('Force Stop'),
                          onPressed: !actuator.humidifierState
                              ? null
                              : () => ref.read(actuatorNotifierProvider.notifier).toggleHumidifier(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Future Ethylene Clarification Note
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Technical Note: This actuator serves as a physical proof-of-concept for gas-triggered response. A commercial onion storage system deploys potassium permanganate (KMnO4) catalytic filtration beads or activated alumina air scrubbers to oxidize ethylene, not moisture misting.',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF475569), height: 1.3),
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

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }
}
