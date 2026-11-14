import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utilities/risk_calculator.dart';
import '../../../data/models/onion_item.dart';
import '../../../data/models/activity_event.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/wifi_connection_dialog.dart';
import '../../../shared/widgets/ble_scan_dialog.dart';
import '../../../shared/widgets/usb_connection_dialog.dart';

import '../../live_sensors/screens/live_sensors_screen.dart';
import '../../fan_control/screens/fan_control_screen.dart';
import '../../gas_sensor/screens/gas_sensor_test_screen.dart';
import '../../onion_inventory/screens/onion_shelves_screen.dart';
import '../../activity_history/screens/activity_history_screen.dart';
import '../../help_guide/screens/help_setup_screen.dart';
import '../../hygiene/screens/hygiene_checklist_screen.dart';
import '../../modelling/screens/mathematical_modelling_screen.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorState = ref.watch(sensorNotifierProvider);
    final actuator = ref.watch(actuatorNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final allOnions = ref.watch(onionInventoryNotifierProvider);
    final events = ref.watch(eventsNotifierProvider);

    final reading = sensorState.latestReading;
    final risk = sensorState.riskBreakdown ?? (reading != null
        ? RiskCalculator.calculate(reading: reading, settings: settings)
        : null);

    // Active Warnings check
    final List<String> warnings = [];
    if (reading != null) {
      if (reading.temperature >= settings.triggerTemp) {
        warnings.add('High Temperature (${reading.temperature}°C >= ${settings.triggerTemp}°C) - Exhaust ventilation active');
      }
      if (reading.humidity >= settings.maxHumiditySafety) {
        warnings.add('High Humidity Alert (${reading.humidity}% >= ${settings.maxHumiditySafety}%) - Risk of condensation & fungal growth');
      }
      if (reading.mq3DeltaPercent >= settings.mq3TriggerDeltaPercent) {
        warnings.add('Gas Proxy Detection (+${reading.mq3DeltaPercent}% above baseline) - Demonstration actuator triggered');
      }
    }
    final int rotCount = allOnions.where((o) => o.condition == OnionCondition.visibleRot || o.condition == OnionCondition.mouldObserved).length;
    if (rotCount > 0) {
      warnings.add('Quarantine Alert: $rotCount onion(s) have visible rot or mould observed in storage shelves.');
    }

    return Scaffold(
      appBar: const CustomAppBar(title: AppConstants.appName),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(14, 12, 14, MediaQuery.of(context).viewPadding.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Warnings Banner
              if (warnings.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.statusRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppConstants.statusRed.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppConstants.statusRed, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Active Storage Alerts',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.statusRed),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...warnings.map((w) => Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text('• $w', style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), height: 1.3)),
                          )),
                    ],
                  ),
                ),
              ],

              // Quick Environmental Summary Bar
              Container(
                padding: const EdgeInsets.all(14),
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
                        const Text(
                          'Current Storage Environment',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                        ),
                        if (sensorState.isSimulation)
                          const StatusBadge(label: 'SIMULATED', color: Colors.orange, isSmall: true)
                        else if (sensorState.isWifiConnected)
                          const StatusBadge(label: 'LIVE WI-FI', color: AppConstants.statusGreen, isSmall: true)
                        else if (sensorState.isUsbConnected)
                          const StatusBadge(label: 'LIVE USB', color: AppConstants.statusGreen, isSmall: true)
                        else if (sensorState.isBleConnected)
                          const StatusBadge(label: 'LIVE BLE', color: AppConstants.statusGreen, isSmall: true)
                        else
                          const StatusBadge(label: 'OFFLINE', color: Colors.grey, isSmall: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickPill(
                            icon: Icons.thermostat,
                            label: 'Temp',
                            value: reading != null ? '${reading.temperature.toStringAsFixed(1)}°C' : '--',
                            color: reading != null && reading.temperature >= settings.triggerTemp ? AppConstants.statusRed : AppConstants.primaryForest,
                          ),
                        ),
                        Expanded(
                          child: _buildQuickPill(
                            icon: Icons.water_drop_outlined,
                            label: 'Humidity',
                            value: reading != null ? '${reading.humidity.toStringAsFixed(1)}%' : '--',
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                        Expanded(
                          child: _buildQuickPill(
                            icon: Icons.science_outlined,
                            label: 'Gas Δ',
                            value: reading != null ? '${reading.mq3DeltaPercent > 0 ? "+" : ""}${reading.mq3DeltaPercent.toStringAsFixed(1)}%' : '--',
                            color: Colors.purple,
                          ),
                        ),
                        Expanded(
                          child: _buildQuickPill(
                            icon: Icons.mode_fan_off,
                            label: 'Exhaust',
                            value: actuator.fanState ? 'ON' : 'IDLE',
                            color: actuator.fanState ? AppConstants.statusGreen : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (!sensorState.isHardwareConnected && !sensorState.isSimulation) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'HARDWARE DISCONNECTED • Connect ESP32 via Wi-Fi or launch Demo Mode',
                                style: TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (sensorState.isHardwareConnected && reading == null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB45309)),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'WAITING FOR SENSOR DATA • ESP32 connected, awaiting DHT11 / MQ-3 packets...',
                                style: TextStyle(fontSize: 10.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

            // Hardware Disconnected Banner
            if (!sensorState.isHardwareConnected && !sensorState.isSimulation) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Color(0xFFB45309), size: 26),
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
                            'Connect to ESP32 Wi-Fi (OnionGuard-WiFi or local network).',
                            style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primaryForest,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.wifi, size: 14),
                                label: const Text('Connect via Wi-Fi'),
                                onPressed: () => showWifiConnectionModal(context, ref),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.usb, size: 14),
                                label: const Text('USB-C'),
                                onPressed: () => showUsbConnectionModal(context, ref),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.bluetooth, size: 14),
                                label: const Text('Scan BLE'),
                                onPressed: () => showBleScanModal(context, ref),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () {
                                  ref.read(simulationServiceProvider).startSimulation();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Interactive Demonstration Mode active! Live simulated telemetry streaming.'),
                                      backgroundColor: AppConstants.statusAmber,
                                    ),
                                  );
                                },
                                child: const Text('Demo Mode'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Storage Health Summary Card
            if (risk != null) ...[
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MathematicalModellingScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppConstants.subtleBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getRiskColor(risk.classification).withOpacity(0.12),
                          border: Border.all(color: _getRiskColor(risk.classification), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${risk.overallScore.round()}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getRiskColor(risk.classification),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'Storage Health Score',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                StatusBadge(label: risk.classification.displayName, color: _getRiskColor(risk.classification), isSmall: true),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Factor: ${risk.primaryContributingFactor}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Main 6 Navigation Cards (2-column Grid)
            const Text(
              'System Modules',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppConstants.primaryForest,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.94,
              children: [
                _buildModuleCard(
                  context,
                  title: '1. Live Room Sensors',
                  description: 'Monitor temperature, humidity and sensor readings.',
                  icon: Icons.thermostat_outlined,
                  color: AppConstants.primaryForest,
                  targetScreen: const LiveSensorsScreen(),
                ),
                _buildModuleCard(
                  context,
                  title: '2. Fan, Cooling & Gas Response',
                  description: 'Monitor automatic ventilation and control demonstration actuator.',
                  icon: Icons.mode_fan_off,
                  color: AppConstants.primaryLight,
                  targetScreen: const FanControlScreen(),
                ),
                _buildModuleCard(
                  context,
                  title: '3. Gas Sensor Test',
                  description: 'Run controlled 9-step sensor response test with live curve.',
                  icon: Icons.science_outlined,
                  color: Colors.purple,
                  targetScreen: const GasSensorTestScreen(),
                ),
                _buildModuleCard(
                  context,
                  title: '4. Onion Storage Shelves',
                  description: 'Inspect storage racks and track onion conditions.',
                  icon: Icons.grid_view_outlined,
                  color: Colors.deepOrange,
                  targetScreen: const OnionShelvesScreen(),
                ),
                _buildModuleCard(
                  context,
                  title: '5. Activity History',
                  description: 'View chronological events, telemetries, inspections & alerts.',
                  icon: Icons.history_outlined,
                  color: const Color(0xFF0284C7),
                  targetScreen: const ActivityHistoryScreen(),
                ),
                _buildModuleCard(
                  context,
                  title: '6. Help & Setup Guide',
                  description: 'Wiring diagrams, parts list, pinout and troubleshooting.',
                  icon: Icons.help_outline,
                  color: const Color(0xFF475569),
                  targetScreen: const HelpSetupScreen(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Additional Engineering Links Row (Hygiene & Mathematical Modelling)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(color: AppConstants.subtleBorder),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.checklist_rtl, size: 18, color: AppConstants.primaryForest),
                    label: const Text('Hygiene Checklist', style: TextStyle(fontSize: 12, color: AppConstants.primaryForest)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HygieneChecklistScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(color: AppConstants.subtleBorder),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.calculate_outlined, size: 18, color: AppConstants.primaryForest),
                    label: const Text('Risk Modelling', style: TextStyle(fontSize: 12, color: AppConstants.primaryForest)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MathematicalModellingScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Latest Activity Card
            Container(
              padding: const EdgeInsets.all(14),
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
                      const Text(
                        'Latest System Activity',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ActivityHistoryScreen()),
                          );
                        },
                        child: const Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.primaryForest)),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  if (events.isEmpty)
                    const Text('No recent system events.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ...events.take(3).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: e.severity.color),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.title,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildQuickPill({required IconData icon, required String label, required String value, required Color color}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required Widget targetScreen,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => targetScreen),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppConstants.subtleBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(HealthClassification c) {
    switch (c) {
      case HealthClassification.good:
        return AppConstants.statusGreen;
      case HealthClassification.attentionRequired:
        return AppConstants.statusAmber;
      case HealthClassification.highRisk:
        return Colors.deepOrange;
      case HealthClassification.critical:
        return AppConstants.statusRed;
    }
  }
}
