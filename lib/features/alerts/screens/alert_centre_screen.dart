import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/sms_service.dart';
import '../../../data/models/sms_alert_queue_item.dart';

class AlertCentreScreen extends ConsumerStatefulWidget {
  const AlertCentreScreen({super.key});

  @override
  ConsumerState<AlertCentreScreen> createState() => _AlertCentreScreenState();
}

class _AlertCentreScreenState extends ConsumerState<AlertCentreScreen> {
  // 8 Required Alert Categories
  static const List<String> _categories = [
    'High Temperature',
    'Low Temperature',
    'High Humidity',
    'Low Humidity',
    'Increased Gas-Sensor Response',
    'Sensor Failure',
    'Controller Disconnected',
    'Ventilation Fault',
  ];

  String _selectedCategory = 'High Temperature';
  bool _isDispatching = false;
  SmsDispatchResult? _lastResult;

  String _generateMessagePreview(String category) {
    final sensorState = ref.read(sensorNotifierProvider);
    final settings = ref.read(settingsNotifierProvider);
    final reading = sensorState.latestReading;

    final tempStr = reading != null ? '${reading.temperature.toStringAsFixed(1)}°C' : '36.2°C';
    final humStr = reading != null ? '${reading.humidity.toStringAsFixed(1)}%' : '78.5%';
    final gasDeltaStr = reading != null ? '+${reading.mq3DeltaPercent.toStringAsFixed(1)}%' : '+32.4%';

    switch (category) {
      case 'High Temperature':
        return '🧅 *OnionGuard Alert [HIGH TEMP]:* Storage temperature reached *$tempStr*, exceeding threshold limit of *${settings.triggerTemp}°C*. Automated exhaust ventilation activated.';
      case 'Low Temperature':
        return '🧅 *OnionGuard Warning [LOW TEMP]:* Storage temperature dropped to *$tempStr*, below recommended conservation limit (${settings.resetTemp}°C). Check room insulation.';
      case 'High Humidity':
        return '🧅 *OnionGuard Warning [HIGH HUMIDITY]:* Relative humidity reached *$humStr* (safety limit: ${settings.maxHumiditySafety}%). High risk of condensation and fungal spore growth. Humidifier locked OFF.';
      case 'Low Humidity':
        return '🧅 *OnionGuard Notice [LOW HUMIDITY]:* Relative humidity dropped to *$humStr*, causing excessive bulb dehydration and moisture loss.';
      case 'Increased Gas-Sensor Response':
        return '🧅 *OnionGuard Alert [GAS SPIKE]:* MQ-3 volatile organic vapour response spiked *$gasDeltaStr* above baseline. Potential spoilage or rotting bulbs detected.';
      case 'Sensor Failure':
        return '🧅 *OnionGuard System Error [SENSOR FAULT]:* DHT11 or MQ-3 telemetry datastream interrupted. Readings offline or failing checksum validation.';
      case 'Controller Disconnected':
        return '🧅 *OnionGuard Warning [CONTROLLER OFFLINE]:* Communication link with ESP32 hardware lost. No telemetry received over Wi-Fi/USB/BLE.';
      case 'Ventilation Fault':
        return '🧅 *OnionGuard Actuator Fault [VENTILATION]:* Exhaust fan relay command failed or safety interlock prevented required thermal ventilation.';
      default:
        return '🧅 *OnionGuard Storage Notice:* Routine agricultural storage monitoring notification.';
    }
  }

  SmsEventType _mapCategoryToEventType(String category) {
    switch (category) {
      case 'High Temperature':
        return SmsEventType.tempHigh;
      case 'Low Temperature':
        return SmsEventType.tempNormal;
      case 'High Humidity':
        return SmsEventType.humidityHigh;
      case 'Low Humidity':
        return SmsEventType.systemTest;
      case 'Increased Gas-Sensor Response':
        return SmsEventType.gasSpike;
      case 'Sensor Failure':
        return SmsEventType.sensorDisconnected;
      case 'Controller Disconnected':
        return SmsEventType.sensorDisconnected;
      case 'Ventilation Fault':
        return SmsEventType.fanActivated;
      default:
        return SmsEventType.systemTest;
    }
  }

  Future<void> _handleManualDispatch() async {
    setState(() {
      _isDispatching = true;
      _lastResult = null;
    });

    final message = _generateMessagePreview(_selectedCategory);
    final eventType = _mapCategoryToEventType(_selectedCategory);
    final smsService = ref.read(smsServiceProvider);

    final result = await smsService.enqueueAlertEvent(
      eventType: eventType,
      message: message,
      priority: SmsAlertPriority.high,
      isTest: true, // Manual operator test bypasses cooldown
    );

    if (mounted) {
      setState(() {
        _isDispatching = false;
        _lastResult = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Alert delivered successfully via ${ref.read(settingsNotifierProvider).whatsappProvider}.'
                : 'Delivery response: ${result.detailMessage}',
          ),
          backgroundColor: result.success ? AppConstants.emerald : AppConstants.statusCritical,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final smsService = ref.watch(smsServiceProvider);
    final queue = smsService.alertQueue.reversed.toList();
    final messagePreview = _generateMessagePreview(_selectedCategory);

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        title: const Text('WhatsApp / SMS Alert Centre'),
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
              // 1. DELIVERY STATUS & RECIPIENT INFORMATION
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppConstants.emerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.send_to_mobile, color: AppConstants.emerald, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Configured Notification Gateway',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppConstants.cream,
                                  ),
                                ),
                                Text(
                                  settings.whatsappEnabled ? 'Channel: ${settings.whatsappProvider}' : 'Notifications Disabled in Settings',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: settings.whatsappEnabled ? AppConstants.emerald : AppConstants.statusCritical,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (settings.whatsappEnabled ? AppConstants.emerald : AppConstants.statusGrey).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            settings.whatsappEnabled ? 'READY' : 'INACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: settings.whatsappEnabled ? AppConstants.emerald : AppConstants.statusGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppConstants.borderEmerald, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recipient Phone:', style: TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey)),
                        Text(
                          settings.whatsappPhoneNumber.isNotEmpty
                              ? settings.whatsappPhoneNumber
                              : (settings.alertPhoneNumber.isNotEmpty ? settings.alertPhoneNumber : 'Not Configured'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.cream),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Alert Cooldown:', style: TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey)),
                        Text('${settings.alertCooldownMinutes} minutes per category', style: const TextStyle(fontSize: 11.5, color: AppConstants.cream)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==============================================================
              // 2. MANUAL CATEGORY SELECTION & DISPATCH
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
                    const Text(
                      'MANUAL ALERT CATEGORY DISPATCH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppConstants.mutedGreenGrey,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Dropdown for selecting alert category
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppConstants.darkCardSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.borderEmerald, width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          dropdownColor: AppConstants.darkCardSurface,
                          icon: const Icon(Icons.arrow_drop_down, color: AppConstants.emerald),
                          items: _categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(
                                cat,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.cream,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (newVal) {
                            if (newVal != null) {
                              setState(() {
                                _selectedCategory = newVal;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Formatted Message Preview Box
                    const Text(
                      'MESSAGE PREVIEW',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppConstants.mutedGreenGrey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.darkBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.borderSubtle, width: 1),
                      ),
                      child: Text(
                        messagePreview,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppConstants.cream,
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dispatch Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.emerald,
                        foregroundColor: AppConstants.darkBg,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isDispatching
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.darkBg))
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(_isDispatching ? 'DISPATCHING TO RECIPIENT...' : 'DISPATCH THIS NOTIFICATION NOW'),
                      onPressed: _isDispatching ? null : _handleManualDispatch,
                    ),

                    if (_lastResult != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (_lastResult!.success ? AppConstants.emerald : AppConstants.statusCritical).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_lastResult!.success ? AppConstants.emerald : AppConstants.statusCritical).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _lastResult!.success ? Icons.check_circle : Icons.error_outline,
                              size: 16,
                              color: _lastResult!.success ? AppConstants.emerald : AppConstants.statusCritical,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _lastResult!.detailMessage,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _lastResult!.success ? AppConstants.emerald : AppConstants.statusCritical,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==============================================================
              // 3. RECENT NOTIFICATION AUDIT LOG
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'RECENT ALERT AUDIT TRAIL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppConstants.mutedGreenGrey,
                          ),
                        ),
                        Text(
                          '${queue.length} Logged',
                          style: const TextStyle(fontSize: 10.5, color: AppConstants.emerald, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (queue.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No notifications dispatched yet.',
                            style: TextStyle(fontSize: 12, color: AppConstants.mutedGreenGrey),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: queue.take(8).length,
                        separatorBuilder: (_, __) => const Divider(color: AppConstants.borderEmerald, height: 12),
                        itemBuilder: (context, index) {
                          final item = queue[index];
                          final isSuccess = item.status == SmsAlertStatus.delivered || item.status == SmsAlertStatus.submitted;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSuccess ? AppConstants.emerald : AppConstants.statusCritical,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item.eventType.displayName,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.cream),
                                        ),
                                        Text(
                                          DateFormat('HH:mm:ss • d MMM').format(item.timestamp),
                                          style: const TextStyle(fontSize: 9.5, color: AppConstants.mutedGreenGrey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Result: ${item.providerResponse ?? item.status.displayName}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: isSuccess ? AppConstants.emerald : AppConstants.statusCritical,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
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
}
