import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/activity_event.dart';
import 'storage_service.dart';

class NotificationAlert {
  final String id;
  final String title;
  final String message;
  final EventSeverity severity;
  final DateTime timestamp;

  NotificationAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
  });
}

class NotificationService {
  final StorageService _storageService;
  final _alertController = StreamController<NotificationAlert>.broadcast();

  // Cooldown tracker: map of alert key -> last sent timestamp
  final Map<String, DateTime> _lastAlertSentTimes = {};

  NotificationService(this._storageService);

  Stream<NotificationAlert> get alertStream => _alertController.stream;

  /// Checks if an alert of this type can be sent based on cooldown
  bool canSendAlert(String alertKey, int cooldownMinutes) {
    final lastTime = _lastAlertSentTimes[alertKey];
    if (lastTime == null) return true;
    final diff = DateTime.now().difference(lastTime).inMinutes;
    return diff >= cooldownMinutes;
  }

  /// Dispatches an alert if cooldown permits, logs it to Activity History, and broadcasts
  Future<bool> triggerAlert({
    required String alertKey,
    required String title,
    required String message,
    required EventSeverity severity,
    required EventCategory category,
    String triggerSource = 'Automatic Alert System',
    String operatingMode = 'LIVE',
    double? temperature,
    double? humidity,
    int? gasAdc,
    bool forceBypassCooldown = false,
  }) async {
    final settings = _storageService.getSettings();
    if (!settings.notificationsEnabled) return false;

    if (!forceBypassCooldown && !canSendAlert(alertKey, settings.alertCooldownMinutes)) {
      debugPrint('Alert "$alertKey" suppressed due to active cooldown.');
      return false;
    }

    _lastAlertSentTimes[alertKey] = DateTime.now();

    final alert = NotificationAlert(
      id: 'ALT-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      severity: severity,
      timestamp: DateTime.now(),
    );

    // Broadcast for UI listeners
    _alertController.add(alert);

    // Save as activity event in persistent log
    final event = ActivityEvent(
      id: 'EVT-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      category: category,
      severity: severity,
      title: title,
      description: message,
      triggerSource: triggerSource,
      operatingMode: operatingMode,
      temperature: temperature,
      humidity: humidity,
      gasAdc: gasAdc,
    );
    await _storageService.addEvent(event);

    return true;
  }

  void dispose() {
    _alertController.close();
  }
}
