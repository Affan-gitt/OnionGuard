import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/ble_service.dart';
import '../../../data/models/sms_alert_queue_item.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/wifi_connection_dialog.dart';
import '../../../shared/widgets/usb_connection_dialog.dart';
import '../../../shared/widgets/ble_scan_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _phoneController;
  late TextEditingController _targetTempController;
  late TextEditingController _triggerTempController;
  late TextEditingController _resetTempController;
  late TextEditingController _targetHumController;
  late TextEditingController _safetyHumController;
  late TextEditingController _mq3BaselineController;
  late TextEditingController _mq3DeltaController;
  late TextEditingController _pinController;
  late TextEditingController _whatsappApiKeyController;
  late TextEditingController _customWebhookController;
  late TextEditingController _ntfyTopicController;
  late TextEditingController _cooldownController;
  late String _whatsappProvider;
  bool _obscureApiKey = true;
  String _smsCapabilityStatusText = 'Checking SIM...';
  bool _isCheckingSms = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsNotifierProvider);
    _phoneController = TextEditingController(
      text: s.whatsappPhoneNumber.isNotEmpty ? s.whatsappPhoneNumber : s.alertPhoneNumber,
    );
    _targetTempController = TextEditingController(text: s.targetTemp.toString());
    _triggerTempController = TextEditingController(text: s.triggerTemp.toString());
    _resetTempController = TextEditingController(text: s.resetTemp.toString());
    _targetHumController = TextEditingController(text: s.targetHumidity.toString());
    _safetyHumController = TextEditingController(text: s.maxHumiditySafety.toString());
    _mq3BaselineController = TextEditingController(text: s.mq3Baseline.toString());
    _mq3DeltaController = TextEditingController(text: s.mq3TriggerDeltaPercent.toString());
    _pinController = TextEditingController(text: s.developerPin);
    _whatsappApiKeyController = TextEditingController(
      text: s.whatsappApiKey.isNotEmpty ? s.whatsappApiKey : s.fast2SmsApiKey,
    );
    _customWebhookController = TextEditingController(text: s.whatsappCustomWebhookUrl);
    _ntfyTopicController = TextEditingController(text: s.ntfyTopic);
    _cooldownController = TextEditingController(text: s.alertCooldownMinutes.toString());
    _whatsappProvider = s.whatsappProvider;

    _refreshSmsCapability();
  }

  Future<void> _refreshSmsCapability() async {
    setState(() => _isCheckingSms = true);
    try {
      final cap = await ref.read(smsServiceProvider).checkCapability();
      if (mounted) {
        setState(() {
          _smsCapabilityStatusText = cap.displayStatus;
          _isCheckingSms = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _smsCapabilityStatusText = 'SMS UNAVAILABLE';
          _isCheckingSms = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _targetTempController.dispose();
    _triggerTempController.dispose();
    _resetTempController.dispose();
    _targetHumController.dispose();
    _safetyHumController.dispose();
    _mq3BaselineController.dispose();
    _mq3DeltaController.dispose();
    _pinController.dispose();
    _whatsappApiKeyController.dispose();
    _customWebhookController.dispose();
    _ntfyTopicController.dispose();
    _cooldownController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final current = ref.read(settingsNotifierProvider);
    final updated = current.copyWith(
      whatsappPhoneNumber: _phoneController.text.trim(),
      whatsappApiKey: _whatsappApiKeyController.text.trim(),
      whatsappCustomWebhookUrl: _customWebhookController.text.trim(),
      ntfyTopic: _ntfyTopicController.text.trim(),
      whatsappProvider: _whatsappProvider,
      alertPhoneNumber: _phoneController.text.trim(),
      fast2SmsApiKey: _whatsappApiKeyController.text.trim(),
      smsProvider: _whatsappProvider,
      alertCooldownMinutes: int.tryParse(_cooldownController.text) ?? current.alertCooldownMinutes,
      targetTemp: double.tryParse(_targetTempController.text) ?? current.targetTemp,
      triggerTemp: double.tryParse(_triggerTempController.text) ?? current.triggerTemp,
      resetTemp: double.tryParse(_resetTempController.text) ?? current.resetTemp,
      targetHumidity: double.tryParse(_targetHumController.text) ?? current.targetHumidity,
      maxHumiditySafety: double.tryParse(_safetyHumController.text) ?? current.maxHumiditySafety,
      mq3Baseline: int.tryParse(_mq3BaselineController.text) ?? current.mq3Baseline,
      mq3TriggerDeltaPercent: double.tryParse(_mq3DeltaController.text) ?? current.mq3TriggerDeltaPercent,
      developerPin: _pinController.text.trim().isNotEmpty ? _pinController.text.trim() : current.developerPin,
    );

    ref.read(settingsNotifierProvider.notifier).updateSettings(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuration saved successfully!'),
        backgroundColor: AppConstants.emerald,
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderEmerald, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoBox({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.darkCardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor ?? AppConstants.borderEmerald, width: 1),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wifi = ref.watch(wifiEsp32ServiceProvider);
    final usb = ref.watch(usbSerialServiceProvider);
    final ble = ref.watch(bleServiceProvider);
    final isWifiConnected = wifi.isConnected;
    final isUsbConnected = usb.isConnected;
    final isBleConnected = ble.state == BleConnectionState.connected;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        title: const Text('Settings & Configuration'),
        backgroundColor: AppConstants.darkBg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppConstants.emerald),
            tooltip: 'Save All',
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            14,
            10,
            14,
            MediaQuery.of(context).viewPadding.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. ESP32 Wi-Fi Connection Card (Primary)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isWifiConnected ? Icons.wifi : Icons.wifi_off,
                              color: isWifiConnected ? AppConstants.emerald : AppConstants.statusAmber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ESP32 Wi-Fi (Primary)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.cream,
                              ),
                            ),
                          ],
                        ),
                        StatusBadge(
                          label: isWifiConnected ? 'CONNECTED' : 'DISCONNECTED',
                          color: isWifiConnected ? AppConstants.emerald : AppConstants.statusGrey,
                          isSmall: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isWifiConnected
                          ? 'Connected to ESP32 SoC at http://${wifi.espIp}:${wifi.port}\nReal-time HTTP polling & REST command stream active.'
                          : 'Connect via Wi-Fi to the ESP32 SoftAP hotspot (SSID: OnionGuard-WiFi) or farm WLAN.',
                      style: const TextStyle(fontSize: 12, color: AppConstants.mutedGreenGrey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.wifi, size: 16),
                          label: const Text('Configure & Connect Wi-Fi'),
                          onPressed: () => showWifiConnectionModal(context, ref),
                        ),
                        if (isWifiConnected)
                          OutlinedButton(
                            onPressed: () {
                              wifi.disconnect();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ESP32 Wi-Fi disconnected.')),
                                );
                              }
                            },
                            child: const Text('Disconnect'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 1. ESP32 USB-C Connection Card (Secondary)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isUsbConnected ? Icons.usb : Icons.usb_off,
                              color: isUsbConnected ? AppConstants.emerald : AppConstants.statusAmber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ESP32-H2 USB-C (Hardware)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.cream,
                              ),
                            ),
                          ],
                        ),
                        StatusBadge(
                          label: isUsbConnected ? 'CONNECTED' : 'DISCONNECTED',
                          color: isUsbConnected ? AppConstants.emerald : AppConstants.statusGrey,
                          isSmall: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUsbConnected
                          ? 'Connected via USB CDC-ACM Serial @ 115200 Baud\nDevice: ${usb.connectedDeviceName ?? "ESP32-H2 USB JTAG/Serial"}'
                          : 'Direct Android USB Host connection (115200 8N1). Connect phone to ESP32-H2 using a USB-C OTG cable.',
                      style: const TextStyle(fontSize: 12, color: AppConstants.mutedGreenGrey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.usb, size: 16),
                          label: const Text('Connect USB-C'),
                          onPressed: () => showUsbConnectionModal(context, ref),
                        ),
                        if (isUsbConnected)
                          OutlinedButton(
                            onPressed: () async {
                              await usb.disconnect();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('USB CDC disconnected.')),
                                );
                              }
                            },
                            child: const Text('Disconnect'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. BLE Connection Card (Secondary)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isBleConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                              color: isBleConnected ? AppConstants.emerald : AppConstants.statusAmber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ESP32-H2 BLE (Wireless)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.cream,
                              ),
                            ),
                          ],
                        ),
                        StatusBadge(
                          label: isBleConnected ? 'CONNECTED' : 'DISCONNECTED',
                          color: isBleConnected ? AppConstants.emerald : AppConstants.statusGrey,
                          isSmall: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isBleConnected
                          ? 'Connected to ${ble.connectedDevice?.name} (${ble.connectedDevice?.id})'
                          : 'Secondary wireless peripheral connection for monitoring.',
                      style: const TextStyle(fontSize: 12, color: AppConstants.mutedGreenGrey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text('Scan BLE'),
                          onPressed: () => showBleScanModal(context, ref),
                        ),
                        if (isBleConnected)
                          OutlinedButton(
                            onPressed: () => ble.disconnect(),
                            child: const Text('Disconnect'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Environmental Thresholds Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.thermostat_outlined, color: AppConstants.emerald, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Environmental Thresholds',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.cream,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _targetTempController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Target Temp (°C)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _triggerTempController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Fan Trigger (°C)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _resetTempController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Fan Reset (°C)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _targetHumController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Target Humidity (%)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _safetyHumController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Humidifier Max Safety Limit (%)',
                        helperText: 'Safety interlock forces actuator OFF when exceeded',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. MQ-3 Sensor Baseline & Triggers
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.grain_rounded, color: AppConstants.warmGold, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'MQ-3 Sensor Baseline & Triggers',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.cream,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Alcohol/fermentation vapour proxy for storage spoilage detection.',
                      style: TextStyle(fontSize: 11.5, color: AppConstants.mutedGreenGrey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _mq3BaselineController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Baseline Raw ADC'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _mq3DeltaController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Trigger Δ (%)'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 5. Alert Notification Gateway (WhatsApp / Push / SMS)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notifications_active_rounded, color: AppConstants.emerald, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Alert Gateway Config',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.cream,
                              ),
                            ),
                          ],
                        ),
                        StatusBadge(
                          label: _whatsappProvider.contains('Circuit')
                              ? 'CIRCUIT DIGEST'
                              : (_whatsappProvider.contains('ntfy')
                                  ? 'NTFY PUSH'
                                  : (_whatsappProvider.contains('CallMeBot')
                                      ? 'CALLMEBOT'
                                      : (_whatsappProvider.contains('Direct')
                                          ? 'DIRECT WA'
                                          : (_whatsappProvider.contains('Webhook')
                                              ? 'WEBHOOK'
                                              : (_whatsappProvider.contains('SIM')
                                                  ? (_isCheckingSms ? 'CHECKING...' : _smsCapabilityStatusText)
                                                  : 'SIMULATION'))))),
                          color: AppConstants.emerald,
                          isSmall: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Automated multi-channel emergency notification dispatch.',
                      style: TextStyle(fontSize: 11.5, color: AppConstants.mutedGreenGrey),
                    ),
                    const SizedBox(height: 14),

                    // Provider Dropdown
                    DropdownButtonFormField<String>(
                      value: _whatsappProvider,
                      isExpanded: true,
                      dropdownColor: AppConstants.darkCard,
                      iconEnabledColor: AppConstants.emerald,
                      style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Notification Gateway Provider',
                        prefixIcon: Icon(Icons.cell_tower, size: 20, color: AppConstants.emerald),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Circuit Digest Cloud WhatsApp API',
                          child: Text('Circuit Digest Cloud WhatsApp (Official API, Instant)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'ntfy.sh (Free Push Receiver - No Auth Required)',
                          child: Text('ntfy.sh (Free Push Receiver - Zero Auth, Instant)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'CallMeBot (Free WhatsApp)',
                          child: Text('CallMeBot Free WhatsApp API', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'Direct WhatsApp App',
                          child: Text('Direct WhatsApp App (Native 1-Tap)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'Custom WhatsApp Webhook',
                          child: Text('Custom Webhook (Self-Hosted/Cloud)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'Android Phone Native SMS (SIM)',
                          child: Text('Android Phone Native SMS (SIM Fallback)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'Simulation Test Only',
                          child: Text('Simulation Test Only (In-App Log Only)', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _whatsappProvider = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Cooldown in Minutes
                    TextField(
                      controller: _cooldownController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Alert Cooldown (Minutes)',
                        prefixIcon: Icon(Icons.timer_outlined, size: 20, color: AppConstants.emerald),
                        helperText: 'Minimum wait time per alert event type to suppress duplicate spam',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Circuit Digest Cloud WhatsApp API Controls
                    if (_whatsappProvider.contains('Circuit')) ...[
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Emergency WhatsApp Recipient Phone Number',
                          hintText: '919876543210 (10 digits or with country code)',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20, color: AppConstants.emerald),
                          helperText: 'Enter phone number to receive WhatsApp alerts (e.g. 919876543210)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified, color: AppConstants.emerald, size: 18),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Circuit Digest Cloud WhatsApp Gateway',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.emerald),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Official WhatsApp Notification API via Circuit Digest Cloud. '
                              'Delivers instant temperature, humidity, gas spike, and system alerts directly with zero carrier delay.',
                              style: TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _whatsappApiKeyController,
                              obscureText: _obscureApiKey,
                              style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Circuit Digest API Key',
                                prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20, color: AppConstants.emerald),
                                helperText: 'Pre-configured API key: cd_muh_131126_sIj6nj',
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off, size: 18, color: AppConstants.emerald),
                                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('Send Test WhatsApp Alert'),
                                  onPressed: () async {
                                    final current = ref.read(settingsNotifierProvider);
                                    ref.read(settingsNotifierProvider.notifier).updateSettings(
                                      current.copyWith(
                                        whatsappPhoneNumber: _phoneController.text.trim(),
                                        whatsappApiKey: _whatsappApiKeyController.text.trim(),
                                        whatsappProvider: _whatsappProvider,
                                        alertPhoneNumber: _phoneController.text.trim(),
                                        fast2SmsApiKey: _whatsappApiKeyController.text.trim(),
                                        smsProvider: _whatsappProvider,
                                        alertCooldownMinutes: int.tryParse(_cooldownController.text) ?? current.alertCooldownMinutes,
                                      ),
                                    );

                                    final item = await ref.read(smsServiceProvider).enqueueAlertEvent(
                                      eventType: SmsEventType.systemTest,
                                      message: '🧅 OnionGuard Storage Alert: Circuit Digest WhatsApp notification verified!',
                                      isTest: true,
                                      priority: SmsAlertPriority.high,
                                    );

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('WhatsApp Test Dispatched! Status: ${item.status.toUpperCase()}'),
                                          backgroundColor: item.success ? AppConstants.statusGreen : AppConstants.statusAmber,
                                        ),
                                      );
                                    }
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.warning_amber_rounded, size: 16, color: AppConstants.warmGold),
                                  label: const Text('Test Threshold Alert'),
                                  onPressed: () async {
                                    final current = ref.read(settingsNotifierProvider);
                                    ref.read(settingsNotifierProvider.notifier).updateSettings(
                                      current.copyWith(
                                        whatsappPhoneNumber: _phoneController.text.trim(),
                                        whatsappApiKey: _whatsappApiKeyController.text.trim(),
                                        whatsappProvider: _whatsappProvider,
                                        alertPhoneNumber: _phoneController.text.trim(),
                                        fast2SmsApiKey: _whatsappApiKeyController.text.trim(),
                                        smsProvider: _whatsappProvider,
                                        alertCooldownMinutes: int.tryParse(_cooldownController.text) ?? current.alertCooldownMinutes,
                                      ),
                                    );

                                    final item = await ref.read(smsServiceProvider).enqueueAlertEvent(
                                      eventType: SmsEventType.tempHigh,
                                      message: '🧅 OnionGuard Warning: Storage temp 32.5 C exceeds 30.0 C limit! Exhaust fan activated.',
                                      isTest: true,
                                      priority: SmsAlertPriority.high,
                                    );

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Threshold Alert Dispatched! Status: ${item.status.toUpperCase()}'),
                                          backgroundColor: item.success ? AppConstants.statusGreen : AppConstants.statusAmber,
                                        ),
                                      );
                                    }
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.chat, size: 16, color: AppConstants.emerald),
                                  label: const Text('Open WhatsApp Direct'),
                                  onPressed: () {
                                    ref.read(smsServiceProvider).openWhatsAppDirect(
                                      phone: _phoneController.text.trim(),
                                      message: '🧅 OnionGuard Storage Alert: Circuit Digest WhatsApp channel active.',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else if (_whatsappProvider.contains('ntfy')) ...[
                      _buildInfoBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_outlined, color: AppConstants.emerald, size: 18),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Instant Push Notification Receiver',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.emerald),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '100% Free & Zero-Delay. No phone number, no API keys, and no sign-up needed! '
                              'Tap "Open / Subscribe" to receive high-priority alerts with sound directly on your phone.',
                              style: TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _ntfyTopicController,
                              style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'ntfy Alert Topic Name',
                                prefixIcon: Icon(Icons.tag, size: 20, color: AppConstants.emerald),
                                hintText: 'onionguard_storage_alerts',
                                helperText: 'Topic name to receive alerts on your device or browser',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('Send Test Alert to Phone'),
                                  onPressed: () async {
                                    final current = ref.read(settingsNotifierProvider);
                                    ref.read(settingsNotifierProvider.notifier).updateSettings(
                                      current.copyWith(
                                        ntfyTopic: _ntfyTopicController.text.trim(),
                                        whatsappProvider: _whatsappProvider,
                                        alertCooldownMinutes: int.tryParse(_cooldownController.text) ?? current.alertCooldownMinutes,
                                      ),
                                    );

                                    final item = await ref.read(smsServiceProvider).enqueueAlertEvent(
                                      eventType: SmsEventType.systemTest,
                                      message: '🧅 OnionGuard Test Alert: Push notification channel verified on your device!',
                                      isTest: true,
                                      priority: SmsAlertPriority.high,
                                    );

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Alert Dispatched! Status: ${item.status.toUpperCase()}'),
                                          backgroundColor: item.success ? AppConstants.statusGreen : AppConstants.statusAmber,
                                          action: SnackBarAction(
                                            label: 'View Feed',
                                            textColor: Colors.white,
                                            onPressed: () => ref.read(smsServiceProvider).openNtfyFeed(_ntfyTopicController.text.trim()),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const Text('Open / Subscribe (ntfy)'),
                                  onPressed: () {
                                    ref.read(smsServiceProvider).openNtfyFeed(_ntfyTopicController.text.trim());
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else if (_whatsappProvider.contains('CallMeBot')) ...[
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Emergency WhatsApp Recipient Phone',
                          hintText: '919876543210 (Country code + phone without spaces)',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20, color: AppConstants.emerald),
                          helperText: 'Enter international format: e.g. 919876543210 (India), 12025550123 (US)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_outlined, color: AppConstants.emerald, size: 18),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text('CallMeBot Free WhatsApp API',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.emerald)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Delivers alerts directly into your WhatsApp inbox. Requires 1-time activation message to CallMeBot.',
                              style: TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _whatsappApiKeyController,
                              obscureText: _obscureApiKey,
                              style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'CallMeBot WhatsApp API Key',
                                prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20, color: AppConstants.emerald),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off, size: 18, color: AppConstants.emerald),
                                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('Send Test WhatsApp Alert'),
                                  onPressed: () async {
                                    final current = ref.read(settingsNotifierProvider);
                                    ref.read(settingsNotifierProvider.notifier).updateSettings(
                                      current.copyWith(
                                        whatsappPhoneNumber: _phoneController.text.trim(),
                                        whatsappApiKey: _whatsappApiKeyController.text.trim(),
                                        whatsappProvider: _whatsappProvider,
                                        alertPhoneNumber: _phoneController.text.trim(),
                                        fast2SmsApiKey: _whatsappApiKeyController.text.trim(),
                                        smsProvider: _whatsappProvider,
                                        alertCooldownMinutes: int.tryParse(_cooldownController.text) ?? current.alertCooldownMinutes,
                                      ),
                                    );

                                    final item = await ref.read(smsServiceProvider).enqueueAlertEvent(
                                      eventType: SmsEventType.systemTest,
                                      message: '🧅 OnionGuard System Test: WhatsApp notification verified!',
                                      isTest: true,
                                      priority: SmsAlertPriority.high,
                                    );

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('WhatsApp Test Dispatched! Status: ${item.status.toUpperCase()}'),
                                          backgroundColor: item.success ? AppConstants.statusGreen : AppConstants.statusAmber,
                                        ),
                                      );
                                    }
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.chat, size: 16, color: AppConstants.emerald),
                                  label: const Text('Open WhatsApp Direct'),
                                  onPressed: () {
                                    ref.read(smsServiceProvider).openWhatsAppDirect(
                                      phone: _phoneController.text.trim(),
                                      message: '🧅 OnionGuard Storage Alert: Test message verified.',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else if (_whatsappProvider.contains('Direct')) ...[
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Emergency WhatsApp Recipient Phone',
                          hintText: '919876543210 (Country code + phone without spaces)',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20, color: AppConstants.emerald),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Direct WhatsApp App Mode',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.emerald),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Alerts launch the official WhatsApp application with the alert message pre-filled ready for 1-tap dispatch.',
                              style: TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.chat, size: 16),
                              label: const Text('Open Pre-filled WhatsApp Test Message'),
                              onPressed: () {
                                ref.read(smsServiceProvider).openWhatsAppDirect(
                                  phone: _phoneController.text.trim(),
                                  message: '🧅 OnionGuard Storage Alert: Environmental notification check.',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else if (_whatsappProvider.contains('Webhook')) ...[
                      _buildInfoBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Custom WhatsApp Webhook Gateway',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.emerald),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'HTTP POST with {"phone": "...", "message": "...", "timestamp": "..."}',
                              style: TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _customWebhookController,
                              style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Custom Webhook URL',
                                prefixIcon: Icon(Icons.link, size: 20, color: AppConstants.emerald),
                                hintText: 'https://my-whatsapp-gateway.com/api/send',
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('Dispatch Test Webhook Alert'),
                              onPressed: () async {
                                final current = ref.read(settingsNotifierProvider);
                                ref.read(settingsNotifierProvider.notifier).updateSettings(
                                  current.copyWith(
                                    whatsappPhoneNumber: _phoneController.text.trim(),
                                    whatsappCustomWebhookUrl: _customWebhookController.text.trim(),
                                    whatsappProvider: _whatsappProvider,
                                  ),
                                );

                                final item = await ref.read(smsServiceProvider).enqueueAlertEvent(
                                  eventType: SmsEventType.systemTest,
                                  message: '🧅 OnionGuard System Test: Webhook notification verified.',
                                  isTest: true,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Webhook Test Status: ${item.status}'),
                                      backgroundColor: item.success ? AppConstants.statusGreen : AppConstants.statusAmber,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else if (_whatsappProvider.contains('SIM')) ...[
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Emergency SMS Recipient Phone',
                          hintText: '919876543210 (Country code + phone without spaces)',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20, color: AppConstants.emerald),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_smsCapabilityStatusText.contains('DENIED')) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppConstants.statusAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppConstants.statusAmber.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: AppConstants.statusAmber, size: 20),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'SMS PERMISSION DENIED: Grant runtime SMS permission for direct phone dispatch.',
                                        style: TextStyle(fontSize: 11, color: AppConstants.warmGold, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final granted = await ref.read(smsServiceProvider).requestPermission();
                                        await _refreshSmsCapability();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(granted ? 'SMS Permission Granted!' : 'Permission denied.')),
                                          );
                                        }
                                      },
                                      child: const Text('Grant', style: TextStyle(color: AppConstants.emerald)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            OutlinedButton.icon(
                              icon: const Icon(Icons.send, size: 15),
                              label: const Text('Send SIM Test SMS', style: TextStyle(fontSize: 11.5)),
                              onPressed: () async {
                                final smsService = ref.read(smsServiceProvider);
                                final result = await smsService.sendAlertSms(
                                  message: 'OnionGuard SIM Test verified.',
                                  isTest: true,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result.detailMessage),
                                      backgroundColor: result.success ? AppConstants.statusGreen : AppConstants.statusAmber,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      _buildInfoBox(
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppConstants.mutedGreenGrey, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Simulation mode: Alerts will be logged to the Alert Queue as local simulation records without sending external messages.',
                                style: TextStyle(fontSize: 11.5, color: AppConstants.mutedGreenGrey),
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

              // 6. Inbound Sensor API Receiver Card (Receive Telemetry via HTTP)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.wifi_tethering, color: AppConstants.emerald, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Inbound Sensor API Receiver',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.cream,
                              ),
                            ),
                          ],
                        ),
                        StatusBadge(
                          label: 'LISTENING :8088',
                          color: AppConstants.emerald,
                          isSmall: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Built-in HTTP API receiver. External devices, Wi-Fi ESP32 boards, or cURL scripts can POST sensor readings directly into OnionGuard.',
                      style: TextStyle(fontSize: 11.5, color: AppConstants.mutedGreenGrey),
                    ),
                    const SizedBox(height: 10),
                    _buildInfoBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Endpoint: POST http://<phone-ip>:8088/api/sensor',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.cream),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Payload: {"temperature": 28.5, "humidity": 62.0, "mq3_raw": 420}',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: AppConstants.mutedGreenGrey),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Packets received: ${ref.watch(inboundApiReceiverServiceProvider).totalPacketsReceived} • Last: ${ref.watch(inboundApiReceiverServiceProvider).lastReceivedInfo}',
                            style: const TextStyle(fontSize: 10.5, color: AppConstants.emerald, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Test Inbound Reading (POST)'),
                          onPressed: () async {
                            final ok = await ref.read(inboundApiReceiverServiceProvider).sendSampleInboundReading();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'Inbound telemetry received & parsed successfully! Dashboard updated.'
                                      : 'Inbound test request failed.'),
                                  backgroundColor: ok ? AppConstants.statusGreen : AppConstants.statusAmber,
                                ),
                              );
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Restart Server'),
                          onPressed: () async {
                            final s = ref.read(inboundApiReceiverServiceProvider);
                            await s.stopServer();
                            await s.startServer(port: 8088);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Inbound API Receiver restarted on port 8088.')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 7. Developer Security PIN
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_outline, color: AppConstants.emerald, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Developer Security PIN',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.cream,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      style: const TextStyle(color: AppConstants.cream, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: '4-Digit Simulation PIN',
                        helperText: 'Required when tapping OnionGuard logo 5 times',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Save Button
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save All Configuration Changes'),
                onPressed: _saveSettings,
              ),
              const SizedBox(height: 20),

              // Architecture Footer
              const Center(
                child: Column(
                  children: [
                    Text(
                      'OnionGuard • Version 2.0 (Agricultural IoT Control Centre)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppConstants.mutedGreenGrey),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'ESP32 Multi-Link Architecture: Wi-Fi REST • USB CDC Serial • BLE GATT',
                      style: TextStyle(fontSize: 11, color: Color(0xFF5A7266)),
                    ),
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
}
