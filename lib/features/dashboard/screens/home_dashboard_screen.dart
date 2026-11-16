import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/sensor_reading.dart';
import '../../../shared/widgets/onion_logo.dart';
import '../../../shared/widgets/wifi_connection_dialog.dart';
import '../../../shared/widgets/usb_connection_dialog.dart';
import '../../../shared/widgets/ble_scan_dialog.dart';
import '../../live_sensors/widgets/live_chart_painter.dart';
import '../widgets/circular_env_gauge.dart';
import '../widgets/animated_fan_widget.dart';
import '../widgets/gas_response_card.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  // Secret multi-tap gesture tracking for hidden demonstration control
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  String _timeRange = '5m';
  int _activeChartIndex = 0; // 0: Temp, 1: Humidity, 2: Gas ADC

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!).inMilliseconds > 2000) {
      _secretTapCount = 1;
    } else {
      _secretTapCount++;
    }
    _lastTapTime = now;

    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      final sim = ref.read(simulationServiceProvider);
      if (sim.isActive) {
        sim.stopSimulation();
      } else {
        sim.startSimulation();
      }
      HapticFeedback.heavyImpact();
    }
  }

  void _showConnectionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.deepForest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppConstants.borderEmerald, width: 1),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sensors, color: AppConstants.emerald, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Hardware Controller Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.cream,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppConstants.mutedGreenGrey, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildConnectionOption(
              icon: Icons.wifi,
              title: 'ESP32 Wi-Fi SoftAP / Local Network',
              subtitle: 'Direct high-speed HTTP REST polling & commands (192.168.4.1)',
              onTap: () {
                Navigator.pop(ctx);
                showWifiConnectionModal(context, ref);
              },
            ),
            const SizedBox(height: 10),
            _buildConnectionOption(
              icon: Icons.usb,
              title: 'ESP32 USB-C CDC Serial',
              subtitle: 'Direct hardware connection via USB-C OTG cable @ 115200 Baud',
              onTap: () {
                Navigator.pop(ctx);
                showUsbConnectionModal(context, ref);
              },
            ),
            const SizedBox(height: 10),
            _buildConnectionOption(
              icon: Icons.bluetooth_searching,
              title: 'Bluetooth LE (BLE GATT)',
              subtitle: 'Wireless secondary peripheral monitoring channel',
              onTap: () {
                Navigator.pop(ctx);
                showBleScanModal(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppConstants.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConstants.borderEmerald, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppConstants.emerald, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.cream,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppConstants.mutedGreenGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppConstants.mutedGreenGrey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sensorState = ref.watch(sensorNotifierProvider);
    final actuator = ref.watch(actuatorNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final reading = sensorState.latestReading;

    final double temp = reading?.temperature ?? 0.0;
    final double hum = reading?.humidity ?? 0.0;
    final int rawGas = reading?.mq3RawAdc ?? 300;
    final double deltaGas = reading?.mq3DeltaPercent ?? 0.0;

    final bool isTempHigh = temp >= settings.triggerTemp;
    final bool isHumHigh = hum >= settings.maxHumiditySafety;
    final bool isGasSpike = deltaGas >= settings.mq3TriggerDeltaPercent;

    // Active Warnings check
    final List<String> activeWarnings = [];
    if (reading != null) {
      if (isTempHigh) {
        activeWarnings.add('Temperature ${temp.toStringAsFixed(1)}°C exceeds threshold (${settings.triggerTemp}°C) - Ventilation active');
      }
      if (isHumHigh) {
        activeWarnings.add('High Humidity Alert (${hum.toStringAsFixed(1)}% >= ${settings.maxHumiditySafety}%) - Risk of condensation & fungal rot');
      }
      if (isGasSpike) {
        activeWarnings.add('Volatile Spoilage Gas Spike (+${deltaGas.toStringAsFixed(1)}%) - Secondary demonstration response active');
      }
    }

    final bool isCritical = isTempHigh || isHumHigh;
    final bool isAttention = !isCritical && isGasSpike;
    final String envStatusLabel = isCritical
        ? 'CRITICAL ATTENTION'
        : (isAttention ? 'ELEVATED GAS DETECTED' : 'STORAGE ENVIRONMENT STABLE');
    final Color envStatusColor = isCritical
        ? AppConstants.statusCritical
        : (isAttention ? AppConstants.warmGold : AppConstants.emerald);

    // Filter history for live chart
    final history = sensorState.history;
    List<SensorReading> filteredHistory = history;
    if (_timeRange == '5m') {
      filteredHistory = history.length > 30 ? history.sublist(history.length - 30) : history;
    } else if (_timeRange == '30m') {
      filteredHistory = history.length > 70 ? history.sublist(history.length - 70) : history;
    }

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).viewPadding.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==============================================================
              // 1. TOP HEADER (BRANDING + SECRET DEMO TRIGGER)
              // ==============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Onion Guard Logo with Secret Multi-Tap Demonstration Switch
                      AnimatedOnionLogo(
                        size: 38,
                        animateRings: true,
                        showOrbitalRings: false,
                        onTap: _handleLogoTap,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                AppConstants.appName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: AppConstants.cream,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: sensorState.isHardwareConnected
                                      ? AppConstants.emerald
                                      : (sensorState.isSimulation ? AppConstants.lime : AppConstants.statusCritical),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (sensorState.isHardwareConnected ? AppConstants.emerald : AppConstants.lime)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('EEE, d MMM • HH:mm:ss').format(DateTime.now()),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: AppConstants.mutedGreenGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Hardware Link Button / Connection Badge
                  InkWell(
                    onTap: () => _showConnectionModal(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppConstants.darkCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sensorState.isHardwareConnected
                              ? AppConstants.emerald.withValues(alpha: 0.6)
                              : AppConstants.borderEmerald,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sensorState.isWifiConnected
                                ? Icons.wifi
                                : (sensorState.isUsbConnected
                                    ? Icons.usb
                                    : (sensorState.isBleConnected
                                        ? Icons.bluetooth
                                        : Icons.sensors_off)),
                            size: 14,
                            color: sensorState.isHardwareConnected ? AppConstants.emerald : AppConstants.mutedGreenGrey,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            sensorState.isWifiConnected
                                ? 'WI-FI'
                                : (sensorState.isUsbConnected
                                    ? 'USB-C'
                                    : (sensorState.isBleConnected
                                        ? 'BLE'
                                        : 'CONNECT')),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: sensorState.isHardwareConnected ? AppConstants.emerald : AppConstants.mutedGreenGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ==============================================================
              // 2. ENVIRONMENTAL STATUS BANNER
              // ==============================================================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: envStatusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: envStatusColor.withValues(alpha: 0.45), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: envStatusColor,
                        boxShadow: [
                          BoxShadow(color: envStatusColor.withValues(alpha: 0.6), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            envStatusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: envStatusColor,
                            ),
                          ),
                          Text(
                            isCritical
                                ? 'Storage limits violated. Automated exhaust ventilation active.'
                                : 'Temperature & humidity within optimal conservation parameters.',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppConstants.cream,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==============================================================
              // 3. HERO SECTION: CIRCULAR ENVIRONMENTAL GAUGES
              // ==============================================================
              Row(
                children: [
                  Expanded(
                    child: CircularEnvGauge(
                      label: 'Temperature',
                      value: temp,
                      minValue: 10,
                      maxValue: 45,
                      thresholdValue: settings.triggerTemp,
                      unit: '°C',
                      icon: Icons.thermostat,
                      activeColor: isTempHigh ? AppConstants.statusCritical : AppConstants.emerald,
                      glowColor: isTempHigh
                          ? AppConstants.statusCritical.withValues(alpha: 0.25)
                          : AppConstants.glowEmerald,
                      statusText: isTempHigh ? 'EXCEEDS ${settings.triggerTemp}°C' : 'SAFE (<${settings.triggerTemp}°C)',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CircularEnvGauge(
                      label: 'Humidity',
                      value: hum,
                      minValue: 30,
                      maxValue: 100,
                      thresholdValue: settings.maxHumiditySafety,
                      unit: '% RH',
                      icon: Icons.water_drop_outlined,
                      activeColor: isHumHigh ? AppConstants.warmGold : const Color(0xFF38BDF8),
                      glowColor: const Color(0xFF38BDF8).withValues(alpha: 0.20),
                      statusText: isHumHigh ? 'INTERLOCK ACTIVE' : 'OPTIMAL (<${settings.maxHumiditySafety}%)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ==============================================================
              // 4. GAS-SENSOR RESPONSE (ALCOHOL / SPOILAGE PROXY)
              // ==============================================================
              GasResponseCard(
                rawAdc: rawGas,
                baselineAdc: settings.mq3Baseline,
                deltaPercent: deltaGas,
                triggerDeltaThreshold: settings.mq3TriggerDeltaPercent,
                isTriggered: isGasSpike,
              ),
              const SizedBox(height: 12),

              // ==============================================================
              // 5. SYSTEM STATUS & ACTUATOR CONTROLS
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
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SYSTEM ACTUATORS & HARDWARE STATE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppConstants.mutedGreenGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Exhaust Fan Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppConstants.darkCardSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: actuator.fanState
                                    ? AppConstants.emerald.withValues(alpha: 0.5)
                                    : AppConstants.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedFanWidget(
                                  isRunning: actuator.fanState,
                                  size: 36,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Exhaust Fan',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.cream),
                                      ),
                                      Text(
                                        actuator.fanState ? 'RUNNING (ON)' : 'IDLE (OFF)',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: actuator.fanState ? AppConstants.emerald : AppConstants.mutedGreenGrey,
                                        ),
                                      ),
                                    ],
                                  ),
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
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Humidifier / Demonstration Relay Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppConstants.darkCardSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: actuator.humidifierState
                                    ? AppConstants.lime.withValues(alpha: 0.5)
                                    : AppConstants.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cyclone,
                                  size: 26,
                                  color: actuator.humidifierState ? AppConstants.lime : AppConstants.mutedGreenGrey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Actuator',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.cream),
                                      ),
                                      Text(
                                        actuator.humidifierState ? 'ACTIVE' : 'IDLE',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: actuator.humidifierState ? AppConstants.lime : AppConstants.mutedGreenGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: actuator.humidifierState,
                                  activeColor: AppConstants.lime,
                                  onChanged: isHumHigh
                                      ? null
                                      : (val) {
                                          ref.read(actuatorNotifierProvider.notifier).toggleHumidifier(val);
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ==============================================================
              // 6. LIVE ENVIRONMENTAL GRAPH
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
                    // Graph Header & Tabs
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildChartTab(0, 'Temp', Icons.thermostat),
                            const SizedBox(width: 6),
                            _buildChartTab(1, 'Humidity', Icons.water_drop_outlined),
                            const SizedBox(width: 6),
                            _buildChartTab(2, 'Gas ADC', Icons.science_outlined),
                          ],
                        ),
                        // Time Range Selector
                        Row(
                          children: [
                            _buildTimeRangeButton('5m'),
                            _buildTimeRangeButton('30m'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Chart Canvas
                    SizedBox(
                      height: 150,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _createChartPainter(filteredHistory, settings),
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

  Widget _buildChartTab(int index, String label, IconData icon) {
    final bool isSelected = _activeChartIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeChartIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.emerald.withValues(alpha: 0.20) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppConstants.emerald.withValues(alpha: 0.7), width: 1)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: isSelected ? AppConstants.emerald : AppConstants.mutedGreenGrey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppConstants.cream : AppConstants.mutedGreenGrey,
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.emerald.withValues(alpha: 0.25) : AppConstants.darkCardSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          range,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppConstants.emerald : AppConstants.mutedGreenGrey,
          ),
        ),
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

    if (points.isEmpty) {
      points = [22.0, 22.0];
    }

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
