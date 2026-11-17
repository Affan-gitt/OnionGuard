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

  late final TextEditingController _phoneController;
  String _selectedCategory = 'High Temperature';
  bool _isDispatching = false;
  SmsDispatchResult? _lastResult;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _phoneController = TextEditingController(
      text: settings.whatsappPhoneNumber.isNotEmpty
          ? settings.whatsappPhoneNumber
          : settings.alertPhoneNumber,
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

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
        return '🧅 *OnionGuard Gas Alert [SPOILAGE VAPOUR]:* MQ-3 alcohol proxy response increased by *$gasDeltaStr* over baseline. Potential bulb rot or fermentation detected.';
      case 'Sensor Failure':
        return '🧅 *OnionGuard Hardware Fault [SENSOR OFFLINE]:* DHT11 or MQ-3 communication disrupted. Verify wiring on ESP32-H2 DevKit.';
      case 'Controller Disconnected':
        return '🧅 *OnionGuard System Error [DISCONNECTED]:* ESP32 storage controller disconnected from monitoring gateway. Automatic failsafe monitoring engaged.';
      case 'Ventilation Fault':
        return '🧅 *OnionGuard Actuator Fault [VENTILATION]:* Exhaust fan relay command failed or safety interlock prevented required thermal ventilation.';
      default:
        return '🧅 *OnionGuard System Alert:* Storage status notification.';
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
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      final s = ref.read(settingsNotifierProvider);
      await ref.read(settingsNotifierProvider.notifier).updateSettings(
        s.copyWith(
          whatsappPhoneNumber: phone,
          alertPhoneNumber: phone,
        ),
      );
    }

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

  Widget _buildQuickPhoneChip(String label, String number) {
    final isSelected = _phoneController.text.trim() == number;
    return InkWell(
      onTap: () {
        setState(() {
          _phoneController.text = number;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.emerald.withValues(alpha: 0.25) : AppConstants.darkCardSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppConstants.emerald : AppConstants.borderEmerald.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.phone_outlined,
              size: 12,
              color: isSelected ? AppConstants.emerald : AppConstants.mutedGreenGrey,
            ),
            const SizedBox(width: 4),
            Text(
              '$label: $number',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppConstants.cream : AppConstants.mutedGreenGrey,
              ),
            ),
          ],
        ),
      ),
    );
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
              // 1. DELIVERY STATUS & GATEWAY INFORMATION
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
                        Expanded(
                          child: Row(
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Notification Gateway',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppConstants.cream,
                                      ),
                                    ),
                                    Text(
                                      settings.whatsappEnabled ? settings.whatsappProvider : 'Notifications Disabled in Settings',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: settings.whatsappEnabled ? AppConstants.emerald : AppConstants.statusCritical,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                        const Text('Active Recipient:', style: TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey)),
                        Flexible(
                          child: Text(
                            _phoneController.text.isNotEmpty ? _phoneController.text : 'Not Configured',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.cream),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Anti-Spam Cooldown:', style: TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey)),
                        Text('${settings.alertCooldownMinutes} minutes per category', style: const TextStyle(fontSize: 11.5, color: AppConstants.cream)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==============================================================
              // 2. SWIFT CONTACT INPUT & MANUAL CATEGORY DISPATCH
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
                    const SizedBox(height: 12),

                    // Contact Phone Input placed directly near the dropdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.phone_android_rounded, size: 14, color: AppConstants.emerald),
                            SizedBox(width: 6),
                            Text(
                              'EMERGENCY CONTACT NUMBER',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppConstants.cream,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            final newPhone = _phoneController.text.trim();
                            if (newPhone.isNotEmpty) {
                              final s = ref.read(settingsNotifierProvider);
                              ref.read(settingsNotifierProvider.notifier).updateSettings(
                                s.copyWith(whatsappPhoneNumber: newPhone, alertPhoneNumber: newPhone),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Contact number saved as default!'),
                                  backgroundColor: AppConstants.emerald,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: const Text('Save as Default', style: TextStyle(color: AppConstants.emerald, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppConstants.darkCardSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.borderEmerald, width: 1),
                      ),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.cream,
                          letterSpacing: 0.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter phone (e.g. 919876543210)',
                          hintStyle: TextStyle(color: Color(0xFF5A7266), fontSize: 12.5),
                          prefixIcon: Icon(Icons.phone_outlined, color: AppConstants.emerald, size: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick select numbers
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickPhoneChip('Farm Primary', '919876543210'),
                          const SizedBox(width: 6),
                          _buildQuickPhoneChip('Storage Attendant', '919123456789'),
                          const SizedBox(width: 6),
                          _buildQuickPhoneChip('Manager', '919988776655'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Dropdown
                    const Row(
                      children: [
                        Icon(Icons.category_outlined, size: 14, color: AppConstants.emerald),
                        SizedBox(width: 6),
                        Text(
                          'ALERT EVENT CATEGORY (8 CHANNELS)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppConstants.cream,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                    const SizedBox(height: 14),

                    // Formatted Message Preview Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.darkBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.borderEmerald.withValues(alpha: 0.5), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'FORMATTED DISPATCH PREVIEW',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppConstants.mutedGreenGrey,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppConstants.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'AUTO-COMPOSED',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppConstants.emerald),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            messagePreview,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppConstants.cream,
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dispatch Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.emerald,
                        foregroundColor: AppConstants.darkBg,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isDispatching
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.darkBg))
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        _isDispatching ? 'DISPATCHING NOTIFICATION...' : 'DISPATCH THIS ALERT NOW',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                      ),
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
              // 3. RECENT ALERT AUDIT LOG
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
                          'RECENT ALERT AUDIT LOG',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppConstants.mutedGreenGrey,
                          ),
                        ),
                        Text(
                          '${queue.length} events logged',
                          style: const TextStyle(fontSize: 10.5, color: AppConstants.mutedGreenGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (queue.isEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No notification events dispatched yet.',
                            style: TextStyle(fontSize: 12, color: AppConstants.mutedGreenGrey),
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: queue.length > 5 ? 5 : queue.length,
                        separatorBuilder: (_, __) => const Divider(color: AppConstants.borderEmerald, height: 16),
                        itemBuilder: (context, idx) {
                          final item = queue[idx];
                          final isSuccess = item.status == SmsAlertStatus.delivered || item.status == SmsAlertStatus.submitted;
                          final color = isSuccess ? AppConstants.emerald : AppConstants.statusCritical;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
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
                                          item.eventType.name.toUpperCase(),
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
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
                                      style: const TextStyle(fontSize: 11, color: AppConstants.cream),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Recipient: ${item.recipient} • ${item.status.displayName}',
                                      style: const TextStyle(fontSize: 9.5, color: AppConstants.mutedGreenGrey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
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
