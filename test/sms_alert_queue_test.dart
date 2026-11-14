import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onionguard/data/models/sms_alert_queue_item.dart';
import 'package:onionguard/core/services/storage_service.dart';
import 'package:onionguard/core/services/sms_service.dart';

void main() {
  group('SMS Alert Queue & Cooldown Tests', () {
    late StorageService storageService;
    late SmsService smsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = await StorageService.init();
      smsService = SmsService(storageService);
    });

    test('SmsAlertQueueItem JSON round-trip serialization', () {
      final now = DateTime.now();
      final item = SmsAlertQueueItem(
        id: 'test-item-1',
        timestamp: now,
        eventType: SmsEventType.tempHigh,
        priority: SmsAlertPriority.high,
        status: SmsAlertStatus.pending,
        recipient: '9876543210',
        message: 'High Temp Alert test',
        provider: 'Fast2SMS (India)',
      );

      final json = item.toJson();
      final restored = SmsAlertQueueItem.fromJson(json);

      expect(restored.id, 'test-item-1');
      expect(restored.eventType, SmsEventType.tempHigh);
      expect(restored.priority, SmsAlertPriority.high);
      expect(restored.status, SmsAlertStatus.pending);
      expect(restored.recipient, '9876543210');
      expect(restored.message, 'High Temp Alert test');
      expect(restored.provider, 'Fast2SMS (India)');
    });

    test('StorageService persists and updates queue items', () async {
      final item1 = SmsAlertQueueItem(
        id: 'queue-1',
        timestamp: DateTime.now(),
        eventType: SmsEventType.humidityHigh,
        priority: SmsAlertPriority.medium,
        status: SmsAlertStatus.pending,
        recipient: '9876543210',
        message: 'High Humidity Alert',
        provider: 'Fast2SMS (India)',
      );

      await storageService.addSmsAlertQueueItem(item1);
      var queue = storageService.getSmsAlertQueue();
      expect(queue.length, 1);
      expect(queue.first.status, SmsAlertStatus.pending);

      // Update status to submitted
      final updated = item1.copyWith(
        status: SmsAlertStatus.submitted,
        providerResponse: '{"return":true,"request_id":"test-123"}',
        httpStatusCode: 200,
      );
      await storageService.updateSmsAlertQueueItem(updated);

      queue = storageService.getSmsAlertQueue();
      expect(queue.length, 1);
      expect(queue.first.status, SmsAlertStatus.submitted);
      expect(queue.first.httpStatusCode, 200);
    });

    test('Independent per-event cooldowns allow different event types without cross-starvation', () async {
      // Configure phone number
      final settings = storageService.getSettings().copyWith(
        alertPhoneNumber: '9876543210',
        smsEnabled: true,
        smsProvider: 'Simulation Test Only',
      );
      await storageService.saveSettings(settings);

      // 1. Enqueue Temp High
      final tempResult = await smsService.enqueueAlertEvent(
        eventType: SmsEventType.tempHigh,
        message: 'Temp exceeded',
        priority: SmsAlertPriority.high,
      );
      expect(tempResult.success, true);
      expect(tempResult.status, 'SIMULATED');

      // 2. Immediate duplicate Temp High should be suppressed by cooldown
      final duplicateTempResult = await smsService.enqueueAlertEvent(
        eventType: SmsEventType.tempHigh,
        message: 'Temp exceeded again',
        priority: SmsAlertPriority.high,
      );
      expect(duplicateTempResult.success, false);
      expect(duplicateTempResult.status, 'COOLDOWN');

      // 3. Different event type (Gas Spike) should NOT be blocked by Temp High cooldown
      final gasResult = await smsService.enqueueAlertEvent(
        eventType: SmsEventType.gasSpike,
        message: 'Gas spike detected',
        priority: SmsAlertPriority.high,
      );
      expect(gasResult.success, true);
      expect(gasResult.status, 'SIMULATED');

      // 4. Recovery event should also NOT be blocked
      final recoveryResult = await smsService.enqueueAlertEvent(
        eventType: SmsEventType.tempNormal,
        message: 'Temp normalized',
        priority: SmsAlertPriority.low,
      );
      expect(recoveryResult.success, true);
      expect(recoveryResult.status, 'SIMULATED');

      // Check that all 4 events exist in persistent queue with proper statuses
      final queue = storageService.getSmsAlertQueue();
      expect(queue.length, 4);
    });
  });
}
