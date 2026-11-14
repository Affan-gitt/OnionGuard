import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/models/sms_alert_queue_item.dart';
import 'storage_service.dart';

class SmsCapabilityStatus {
  final String status; // "READY", "PERMISSION_DENIED", "SMS_UNAVAILABLE", "NO_SIM"
  final bool hasPermission;
  final bool hasTelephony;
  final bool simReady;

  SmsCapabilityStatus({
    required this.status,
    required this.hasPermission,
    required this.hasTelephony,
    required this.simReady,
  });

  bool get isReady => status == 'READY';
  bool get isPermissionDenied => status == 'PERMISSION_DENIED';
  bool get isUnavailable => status == 'SMS_UNAVAILABLE' || status == 'NO_SIM';

  String get displayStatus {
    switch (status) {
      case 'READY':
        return 'Phone SIM Ready';
      case 'PERMISSION_DENIED':
        return 'SMS PERMISSION DENIED';
      case 'NO_SIM':
        return 'SMS UNAVAILABLE (No SIM)';
      default:
        return 'SMS UNAVAILABLE';
    }
  }
}

class SmsDispatchResult {
  final bool success;
  final String status;
  final String detailMessage;
  final int? httpStatusCode;
  final String? rawResponse;

  SmsDispatchResult({
    required this.success,
    required this.status,
    required this.detailMessage,
    this.httpStatusCode,
    this.rawResponse,
  });
}

class SmsService {
  final StorageService _storageService;
  
  // Independent cooldown tracking per event type to prevent starvation
  final Map<SmsEventType, DateTime> _eventCooldowns = {};
  
  static const MethodChannel _platform = MethodChannel('com.onionguard.onionguard/sms');

  SmsService(this._storageService);

  List<SmsAlertQueueItem> get alertQueue => _storageService.getSmsAlertQueue();

  /// Checks if a specific alert event is eligible to dispatch under cooldown
  bool canDispatchEvent(SmsEventType eventType, int cooldownMinutes) {
    final lastTime = _eventCooldowns[eventType];
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime).inMinutes >= cooldownMinutes;
  }

  /// Checks real device telephony and SIM capability
  Future<SmsCapabilityStatus> checkCapability() async {
    try {
      final res = await _platform.invokeMethod<Map<dynamic, dynamic>>('checkSmsCapability');
      if (res != null) {
        return SmsCapabilityStatus(
          status: res['status'] as String? ?? 'SMS_UNAVAILABLE',
          hasPermission: res['hasPermission'] as bool? ?? false,
          hasTelephony: res['hasTelephony'] as bool? ?? false,
          simReady: res['simReady'] as bool? ?? false,
        );
      }
    } catch (e) {
      debugPrint('[SMS] checkSmsCapability error: $e');
    }
    return SmsCapabilityStatus(
      status: 'SMS_UNAVAILABLE',
      hasPermission: false,
      hasTelephony: false,
      simReady: false,
    );
  }

  /// Requests Android runtime SEND_SMS permission
  Future<bool> requestPermission() async {
    try {
      final granted = await _platform.invokeMethod<bool>('requestSmsPermission');
      return granted == true;
    } catch (e) {
      debugPrint('[SMS] requestSmsPermission error: $e');
      return false;
    }
  }

  /// Fallback: opens Android's native SMS messaging app with pre-filled content
  Future<bool> openNativeComposer({
    required String message,
  }) async {
    final settings = _storageService.getSettings();
    final phone = settings.alertPhoneNumber.trim();
    try {
      final ok = await _platform.invokeMethod<bool>('openNativeSmsComposer', {
        'phone': phone,
        'message': message,
      });

      await _storageService.addSmsAlertQueueItem(
        SmsAlertQueueItem(
          id: 'SMS-COMPOSER-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          eventType: SmsEventType.systemTest,
          priority: SmsAlertPriority.low,
          recipient: phone,
          message: message,
          status: SmsAlertStatus.submitted,
          provider: 'Native Android Messaging App',
          providerResponse: 'Composer intent launched',
        ),
      );

      return ok == true;
    } catch (e) {
      debugPrint('[SMS] openNativeSmsComposer error: $e');
      return false;
    }
  }

  /// Enqueues and dispatches an alert according to configured provider and cooldown rules
  Future<SmsDispatchResult> enqueueAlertEvent({
    required SmsEventType eventType,
    required String message,
    SmsAlertPriority priority = SmsAlertPriority.high,
    bool isTest = false,
  }) async {
    final settings = _storageService.getSettings();
    final phone = settings.alertPhoneNumber.trim();
    final provider = settings.smsProvider;

    final queueId = 'SMS-${DateTime.now().millisecondsSinceEpoch}';
    final initialItem = SmsAlertQueueItem(
      id: queueId,
      timestamp: DateTime.now(),
      eventType: eventType,
      priority: priority,
      recipient: phone,
      message: message,
      status: SmsAlertStatus.pending,
      provider: provider,
      lastAttempt: DateTime.now(),
    );

    await _storageService.addSmsAlertQueueItem(initialItem);

    if (!settings.smsEnabled && !isTest) {
      final updated = initialItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'SMS alerts currently disabled in Settings.',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: false,
        status: 'DISABLED',
        detailMessage: 'SMS alerts are disabled in Settings.',
      );
    }

    if (phone.isEmpty) {
      final updated = initialItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'No recipient phone number configured in Settings.',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: false,
        status: 'NO_PHONE',
        detailMessage: 'No recipient phone number configured.',
      );
    }

    // Cooldown verification (independent per event type)
    if (!isTest && !canDispatchEvent(eventType, settings.alertCooldownMinutes)) {
      final updated = initialItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'Suppressed by active cooldown (${settings.alertCooldownMinutes}m).',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: false,
        status: 'COOLDOWN',
        detailMessage: 'Alert suppressed by active cooldown window (${settings.alertCooldownMinutes} min).',
      );
    }

    _eventCooldowns[eventType] = DateTime.now();

    // Provider Dispatch
    if (provider.contains('Circuit') || provider.contains('Circuit Digest')) {
      return await _dispatchCircuitDigestWhatsApp(initialItem, settings.whatsappApiKey, phone, message, eventType);
    } else if (provider.contains('ntfy') || provider.contains('Push')) {
      return await _dispatchNtfy(initialItem, settings.ntfyTopic, message, priority);
    } else if (provider.contains('CallMeBot') || provider.contains('WhatsApp') || provider.contains('Fast2SMS')) {
      return await _dispatchCallMeBot(initialItem, settings.whatsappApiKey, phone, message);
    } else if (provider.contains('Webhook')) {
      return await _dispatchCustomWebhook(initialItem, settings.whatsappCustomWebhookUrl, phone, message);
    } else if (provider.contains('Direct')) {
      final opened = await openWhatsAppDirect(phone: phone, message: message);
      final updated = initialItem.copyWith(
        status: opened ? SmsAlertStatus.submitted : SmsAlertStatus.failed,
        providerResponse: opened ? 'Direct WhatsApp App launched' : 'Could not launch WhatsApp',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: opened,
        status: opened ? 'OPENED' : 'FAILED',
        detailMessage: opened ? 'WhatsApp app opened with alert text' : 'WhatsApp app launch failed',
      );
    } else if (provider.contains('SIM')) {
      return await _dispatchPhoneSim(initialItem, phone, message);
    } else {
      // Simulation Test Mode
      final updated = initialItem.copyWith(
        status: SmsAlertStatus.delivered,
        providerResponse: 'Simulated In-App Dispatch Successful',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: true,
        status: 'SIMULATED',
        detailMessage: 'Test notification simulated successfully and logged in alert queue.',
      );
    }
  }

  /// Sends alert via free instant ntfy.sh push notification receiver (No credentials required)
  Future<SmsDispatchResult> _dispatchNtfy(
    SmsAlertQueueItem queueItem,
    String rawTopic,
    String message,
    SmsAlertPriority priority,
  ) async {
    final cleanTopic = rawTopic.trim().replaceAll(' ', '_');
    if (cleanTopic.isEmpty) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'ntfy Topic cannot be empty in Settings.',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: false,
        status: 'CONFIG_MISSING',
        detailMessage: 'ntfy Topic cannot be empty in Settings.',
      );
    }

    // Always show device local heads-up notification so the user definitely receives it
    await showDeviceNotification(
      title: '🧅 OnionGuard Storage Alert',
      message: message,
    );

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final url = Uri.parse('https://ntfy.sh/$cleanTopic');
      final req = await client.postUrl(url);
      req.headers.set('Title', 'OnionGuard Storage Alert');
      req.headers.set('Priority', priority == SmsAlertPriority.high ? 'urgent' : 'high');
      req.headers.set('Tags', 'warning,onion');
      req.write(message);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();

      final isSuccess = resp.statusCode >= 200 && resp.statusCode < 300;
      final updated = queueItem.copyWith(
        status: isSuccess ? SmsAlertStatus.delivered : SmsAlertStatus.failed,
        httpStatusCode: resp.statusCode,
        providerResponse: 'ntfy.sh HTTP ${resp.statusCode}: ${body.trim()}',
        lastAttempt: DateTime.now(),
      );
      await _storageService.updateSmsAlertQueueItem(updated);

      return SmsDispatchResult(
        success: isSuccess,
        status: isSuccess ? 'DELIVERED' : 'FAILED',
        detailMessage: isSuccess
            ? 'Push alert delivered to ntfy topic "$cleanTopic"!'
            : 'ntfy HTTP error ${resp.statusCode}: $body',
        httpStatusCode: resp.statusCode,
        rawResponse: body,
      );
    } catch (e) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'Network exception: $e',
        lastAttempt: DateTime.now(),
      );
      await _storageService.updateSmsAlertQueueItem(updated);

      return SmsDispatchResult(
        success: false,
        status: 'NETWORK_ERROR',
        detailMessage: 'Push delivery network error: $e (device notification shown).',
      );
    }
  }

  /// Triggers a real Android system heads-up notification on the device
  Future<bool> showDeviceNotification({
    required String title,
    required String message,
  }) async {
    try {
      final ok = await _platform.invokeMethod<bool>('showSystemNotification', {
        'title': title,
        'message': message,
      });
      return ok == true;
    } catch (e) {
      debugPrint('[Notification] showDeviceNotification error: $e');
      return false;
    }
  }

  /// Opens the ntfy web viewer or app to subscribe
  Future<bool> openNtfyFeed(String topic) async {
    final cleanTopic = topic.trim().replaceAll(' ', '_');
    final url = 'https://ntfy.sh/$cleanTopic';
    try {
      final ok = await _platform.invokeMethod<bool>('openBrowserUrl', {
        'url': url,
      });
      return ok == true;
    } catch (e) {
      debugPrint('[Notification] openNtfyFeed error: $e');
      return false;
    }
  }

  /// Sends WhatsApp alert via Circuit Digest Cloud WhatsApp API (Real WhatsApp message)
  Future<SmsDispatchResult> _dispatchCircuitDigestWhatsApp(
    SmsAlertQueueItem queueItem,
    String rawApiKey,
    String rawPhone,
    String message,
    SmsEventType eventType,
  ) async {
    final apiKey = rawApiKey.trim();
    if (apiKey.isEmpty) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'Circuit Digest Cloud WhatsApp API key missing in Settings.',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: false,
        status: 'AUTH_MISSING',
        detailMessage: 'Circuit Digest Cloud WhatsApp API key missing in Settings.',
      );
    }

    var cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    if (cleanPhone.length < 10) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'Invalid recipient phone number in Settings.',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: false,
        status: 'INVALID_PHONE',
        detailMessage: 'Invalid recipient phone number. Please enter a valid number in Settings.',
      );
    }

    // Also trigger local device notification
    await showDeviceNotification(
      title: '🧅 OnionGuard WhatsApp Alert',
      message: message,
    );

    // Prepare template & variables
    final Map<String, dynamic> payload;
    final nowStr = DateTime.now().toLocal().toString().split('.').first;

    if (eventType == SmsEventType.tempHigh) {
      String measured = 'Over Limit';
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*°?C').firstMatch(message);
      if (match != null) {
        measured = '${match.group(1)} C';
      }
      payload = {
        'phone_number': cleanPhone,
        'template_id': 'threshold_violation_alert',
        'variables': {
          'device_name': 'OnionGuard Storage',
          'parameter': 'Temperature',
          'measured_value': measured,
          'limit': '30.0 C',
          'location': 'Storage Rack 1',
        },
      };
    } else if (eventType == SmsEventType.humidityHigh) {
      String measured = 'High Humidity';
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(message);
      if (match != null) {
        measured = '${match.group(1)}%';
      }
      payload = {
        'phone_number': cleanPhone,
        'template_id': 'threshold_violation_alert',
        'variables': {
          'device_name': 'OnionGuard Storage',
          'parameter': 'Humidity',
          'measured_value': measured,
          'limit': '70.0%',
          'location': 'Storage Rack 1',
        },
      };
    } else if (eventType == SmsEventType.gasSpike) {
      payload = {
        'phone_number': cleanPhone,
        'template_id': 'threshold_violation_alert',
        'variables': {
          'device_name': 'OnionGuard Storage',
          'parameter': 'Gas Spoilage (MQ-3)',
          'measured_value': 'Spike Detected',
          'limit': 'Normal Baseline',
          'location': 'Storage Rack 1',
        },
      };
    } else {
      // critical_event_alert for all other events (system test, fan activated, sensor disconnected, recovery, etc.)
      final cleanStatus = message
          .replaceAll('*', '')
          .replaceAll('🧅', '')
          .trim();
      final statusText = cleanStatus.length > 50 ? cleanStatus.substring(0, 50) : cleanStatus;

      payload = {
        'phone_number': cleanPhone,
        'template_id': 'critical_event_alert',
        'variables': {
          'device_name': 'OnionGuard Storage',
          'event_type': eventType == SmsEventType.systemTest ? 'System Verification' : eventType.displayName,
          'status': statusText.isEmpty ? 'Active' : statusText,
          'timestamp': nowStr,
        },
      };
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 12);
      final url = Uri.parse('https://www.circuitdigest.cloud/api/v1/whatsapp/send');
      final request = await client.postUrl(url);
      request.headers.set('Authorization', apiKey);
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode(payload));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      int statusCode = response.statusCode;
      bool isSuccess = false;
      String messageId = '';
      String responseDetail = responseBody.trim();

      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map) {
          if (decoded['success'] == true) {
            isSuccess = true;
            messageId = decoded['message_id']?.toString() ?? '';
            responseDetail = decoded['message']?.toString() ?? 'WhatsApp message sent';
          } else if (decoded.containsKey('detail')) {
            responseDetail = decoded['detail']?.toString() ?? responseBody;
          }
        }
      } catch (_) {}

      if (isSuccess) {
        final updated = queueItem.copyWith(
          status: SmsAlertStatus.delivered,
          httpStatusCode: statusCode,
          providerResponse: 'Circuit Digest Cloud: $responseDetail (ID: $messageId)',
          lastAttempt: DateTime.now(),
        );
        await _storageService.updateSmsAlertQueueItem(updated);

        return SmsDispatchResult(
          success: true,
          status: 'DELIVERED',
          detailMessage: 'WhatsApp Alert Delivered via Circuit Digest Cloud! (Msg ID: $messageId)',
          httpStatusCode: statusCode,
          rawResponse: responseBody,
        );
      } else {
        final updated = queueItem.copyWith(
          status: SmsAlertStatus.failed,
          httpStatusCode: statusCode,
          providerResponse: 'Circuit Digest Error ($statusCode): $responseDetail',
          lastAttempt: DateTime.now(),
        );
        await _storageService.updateSmsAlertQueueItem(updated);

        return SmsDispatchResult(
          success: false,
          status: 'FAILED',
          detailMessage: 'Circuit Digest WhatsApp Error: $responseDetail',
          httpStatusCode: statusCode,
          rawResponse: responseBody,
        );
      }
    } catch (e) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'Circuit Digest Network Error: $e',
        lastAttempt: DateTime.now(),
      );
      await _storageService.updateSmsAlertQueueItem(updated);

      return SmsDispatchResult(
        success: false,
        status: 'NETWORK_ERROR',
        detailMessage: 'Circuit Digest Network Error: $e',
      );
    }
  }

  /// Sends alert via free CallMeBot WhatsApp API (Instant, No delays, No SMS costs)
  Future<SmsDispatchResult> _dispatchCallMeBot(
    SmsAlertQueueItem queueItem,
    String rawApiKey,
    String rawPhone,
    String message,
  ) async {
    final apiKey = rawApiKey.trim();
    if (apiKey.isEmpty) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'CallMeBot Free WhatsApp API Key missing in Settings.',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: false,
        status: 'AUTH_MISSING',
        detailMessage: 'Missing CallMeBot WhatsApp API Key. Please get free key and configure in Settings.',
      );
    }

    // Clean phone number: international format without + or spaces
    var cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }
    // Default 10-digit Indian numbers to country code 91
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 12);

      final encodedText = Uri.encodeComponent(message);
      final url = Uri.parse(
        'https://api.callmebot.com/whatsapp.php?phone=$cleanPhone&text=$encodedText&apikey=$apiKey',
      );

      final request = await client.getUrl(url);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      int statusCode = response.statusCode;
      final lowerBody = responseBody.toLowerCase();
      bool isApiSuccess = statusCode == 200 &&
          !lowerBody.contains('invalid apikey') &&
          !lowerBody.contains('error');

      if (isApiSuccess) {
        final updated = queueItem.copyWith(
          status: SmsAlertStatus.submitted,
          httpStatusCode: statusCode,
          providerResponse: 'CallMeBot WhatsApp 200 OK: ${responseBody.trim()}',
          lastAttempt: DateTime.now(),
        );
        await _storageService.updateSmsAlertQueueItem(updated);

        return SmsDispatchResult(
          success: true,
          status: 'DELIVERED',
          detailMessage: 'WhatsApp Alert Dispatched Instantly!',
          httpStatusCode: statusCode,
          rawResponse: responseBody,
        );
      } else {
        final updated = queueItem.copyWith(
          status: SmsAlertStatus.failed,
          httpStatusCode: statusCode,
          providerResponse: 'CallMeBot Error ($statusCode): ${responseBody.trim()}',
          lastAttempt: DateTime.now(),
        );
        await _storageService.updateSmsAlertQueueItem(updated);

        return SmsDispatchResult(
          success: false,
          status: 'FAILED',
          detailMessage: 'CallMeBot Error: ${responseBody.trim()}',
          httpStatusCode: statusCode,
          rawResponse: responseBody,
        );
      }
    } catch (e) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'Network exception: $e',
        lastAttempt: DateTime.now(),
      );
      await _storageService.updateSmsAlertQueueItem(updated);

      return SmsDispatchResult(
        success: false,
        status: 'NETWORK_ERROR',
        detailMessage: 'WhatsApp Network Connection Error: $e',
      );
    }
  }

  /// Sends alert via custom or self-hosted WhatsApp Webhook URL
  Future<SmsDispatchResult> _dispatchCustomWebhook(
    SmsAlertQueueItem queueItem,
    String rawWebhookUrl,
    String rawPhone,
    String message,
  ) async {
    final webhookUrl = rawWebhookUrl.trim();
    if (webhookUrl.isEmpty) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'Custom WhatsApp Webhook URL missing in Settings.',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: false,
        status: 'CONFIG_MISSING',
        detailMessage: 'Missing Custom WhatsApp Webhook URL in Settings.',
      );
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 12);
      final request = await client.postUrl(Uri.parse(webhookUrl));
      request.headers.set('Content-Type', 'application/json');

      final payload = jsonEncode({
        'phone': rawPhone.replaceAll(RegExp(r'[^\d+]'), ''),
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'OnionGuard Environmental Monitor',
      });

      request.write(payload);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      final updated = queueItem.copyWith(
        status: isSuccess ? SmsAlertStatus.submitted : SmsAlertStatus.failed,
        httpStatusCode: response.statusCode,
        providerResponse: 'Custom Webhook HTTP ${response.statusCode}: ${responseBody.trim()}',
        lastAttempt: DateTime.now(),
      );
      await _storageService.updateSmsAlertQueueItem(updated);

      return SmsDispatchResult(
        success: isSuccess,
        status: isSuccess ? 'SUBMITTED' : 'FAILED',
        detailMessage: 'Custom Webhook HTTP ${response.statusCode}',
        httpStatusCode: response.statusCode,
        rawResponse: responseBody,
      );
    } catch (e) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'Custom Webhook error: $e',
        lastAttempt: DateTime.now(),
      );
      await _storageService.updateSmsAlertQueueItem(updated);

      return SmsDispatchResult(
        success: false,
        status: 'NETWORK_ERROR',
        detailMessage: 'Custom Webhook Error: $e',
      );
    }
  }

  /// Opens the native WhatsApp app on device with pre-filled message
  Future<bool> openWhatsAppDirect({required String phone, required String message}) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      final ok = await _platform.invokeMethod<bool>('openWhatsApp', {
        'phone': cleanPhone,
        'message': message,
      });
      return ok == true;
    } catch (e) {
      debugPrint('[WhatsApp] openWhatsAppDirect error: $e');
      return false;
    }
  }

  /// One-click helper to activate free CallMeBot WhatsApp API key
  Future<bool> openCallMeBotActivation() async {
    return await openWhatsAppDirect(
      phone: '34644442083',
      message: 'I allow callmebot to send me messages',
    );
  }

  /// Sends alert via Android Phone SIM (SmsManager)
  Future<SmsDispatchResult> _dispatchPhoneSim(
    SmsAlertQueueItem queueItem,
    String phone,
    String message,
  ) async {
    final cap = await checkCapability();
    if (cap.isUnavailable) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'SMS UNAVAILABLE: No active mobile SIM card detected.',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: false,
        status: 'SMS UNAVAILABLE',
        detailMessage: 'SMS UNAVAILABLE: No active mobile SIM card detected.',
      );
    }

    if (cap.isPermissionDenied) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'SMS PERMISSION DENIED: SEND_SMS runtime permission not granted.',
      );
      await _storageService.updateSmsAlertQueueItem(updated);
      return SmsDispatchResult(
        success: false,
        status: 'SMS PERMISSION DENIED',
        detailMessage: 'SMS PERMISSION DENIED: Grant runtime SMS permission in Settings.',
      );
    }

    try {
      final res = await _platform.invokeMethod<Map<dynamic, dynamic>>('sendDirectSms', {
        'phone': phone,
        'message': message,
      });

      final success = res?['success'] as bool? ?? false;
      final status = res?['status'] as String? ?? 'FAILED';
      final detailMessage = res?['detailMessage'] as String? ?? (success ? 'SMS DELIVERED' : 'SMS FAILED');

      final updated = queueItem.copyWith(
        status: success ? SmsAlertStatus.delivered : SmsAlertStatus.failed,
        providerResponse: 'SIM SmsManager: $detailMessage',
        lastAttempt: DateTime.now(),
      );
      await _storageService.updateSmsAlertQueueItem(updated);

      return SmsDispatchResult(
        success: success,
        status: status,
        detailMessage: detailMessage,
      );
    } catch (e) {
      final updated = queueItem.copyWith(
        status: SmsAlertStatus.failed,
        providerResponse: 'SmsManager Exception: $e',
        lastAttempt: DateTime.now(),
      );
      await _storageService.updateSmsAlertQueueItem(updated);

      return SmsDispatchResult(
        success: false,
        status: 'FAILED',
        detailMessage: 'SMS Dispatch Exception: $e',
      );
    }
  }

  /// Compatibility wrapper for existing alert calls
  Future<SmsDispatchResult> sendAlertSms({
    required String message,
    String alertKey = 'GENERAL_ALERT',
    SmsEventType eventType = SmsEventType.systemTest,
    SmsAlertPriority priority = SmsAlertPriority.medium,
    bool isTest = false,
  }) async {
    return await enqueueAlertEvent(
      eventType: eventType,
      message: message,
      priority: priority,
      isTest: isTest,
    );
  }
}
