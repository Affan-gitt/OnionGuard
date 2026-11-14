enum SmsAlertStatus {
  pending,
  submitted,
  delivered,
  failed,
  unknown;

  String get displayName {
    switch (this) {
      case SmsAlertStatus.pending:
        return 'Pending';
      case SmsAlertStatus.submitted:
        return 'Submitted';
      case SmsAlertStatus.delivered:
        return 'Delivered';
      case SmsAlertStatus.failed:
        return 'Failed';
      case SmsAlertStatus.unknown:
        return 'Unknown';
    }
  }
}

enum SmsAlertPriority {
  high,
  medium,
  low;

  String get displayName {
    switch (this) {
      case SmsAlertPriority.high:
        return 'HIGH';
      case SmsAlertPriority.medium:
        return 'MEDIUM';
      case SmsAlertPriority.low:
        return 'LOW';
    }
  }
}

enum SmsEventType {
  tempHigh,
  humidityHigh,
  gasSpike,
  fanActivated,
  humidifierActivated,
  sensorDisconnected,
  sensorRecovered,
  tempNormal,
  systemTest;

  String get eventKey {
    switch (this) {
      case SmsEventType.tempHigh:
        return 'TEMP_HIGH';
      case SmsEventType.humidityHigh:
        return 'HUMIDITY_HIGH';
      case SmsEventType.gasSpike:
        return 'GAS_SPIKE';
      case SmsEventType.fanActivated:
        return 'FAN_ACTIVATED';
      case SmsEventType.humidifierActivated:
        return 'HUMIDIFIER_ACTIVATED';
      case SmsEventType.sensorDisconnected:
        return 'SENSOR_DISCONNECTED';
      case SmsEventType.sensorRecovered:
        return 'SENSOR_RECOVERED';
      case SmsEventType.tempNormal:
        return 'TEMP_NORMAL';
      case SmsEventType.systemTest:
        return 'SYSTEM_TEST';
    }
  }

  String get displayName {
    switch (this) {
      case SmsEventType.tempHigh:
        return 'Temperature Limit Exceeded';
      case SmsEventType.humidityHigh:
        return 'High Humidity Warning';
      case SmsEventType.gasSpike:
        return 'Gas Spoilage Spike';
      case SmsEventType.fanActivated:
        return 'Exhaust Fan Activated';
      case SmsEventType.humidifierActivated:
        return 'Gas Response Actuator Activated';
      case SmsEventType.sensorDisconnected:
        return 'Sensor Disconnected';
      case SmsEventType.sensorRecovered:
        return 'Sensor Link Recovered';
      case SmsEventType.tempNormal:
        return 'Temperature Normalized';
      case SmsEventType.systemTest:
        return 'System Test';
    }
  }
}

class SmsAlertQueueItem {
  final String id;
  final DateTime timestamp;
  final SmsEventType eventType;
  final SmsAlertPriority priority;
  final String recipient;
  final String message;
  final SmsAlertStatus status;
  final String provider;
  final int? httpStatusCode;
  final String? providerResponse;
  final int retryCount;
  final DateTime? lastAttempt;

  SmsAlertQueueItem({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.priority,
    required this.recipient,
    required this.message,
    this.status = SmsAlertStatus.pending,
    required this.provider,
    this.httpStatusCode,
    this.providerResponse,
    this.retryCount = 0,
    this.lastAttempt,
  });

  SmsAlertQueueItem copyWith({
    String? id,
    DateTime? timestamp,
    SmsEventType? eventType,
    SmsAlertPriority? priority,
    String? recipient,
    String? message,
    SmsAlertStatus? status,
    String? provider,
    int? httpStatusCode,
    String? providerResponse,
    int? retryCount,
    DateTime? lastAttempt,
  }) {
    return SmsAlertQueueItem(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      eventType: eventType ?? this.eventType,
      priority: priority ?? this.priority,
      recipient: recipient ?? this.recipient,
      message: message ?? this.message,
      status: status ?? this.status,
      provider: provider ?? this.provider,
      httpStatusCode: httpStatusCode ?? this.httpStatusCode,
      providerResponse: providerResponse ?? this.providerResponse,
      retryCount: retryCount ?? this.retryCount,
      lastAttempt: lastAttempt ?? this.lastAttempt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'eventType': eventType.name,
    'priority': priority.name,
    'recipient': recipient,
    'message': message,
    'status': status.name,
    'provider': provider,
    'httpStatusCode': httpStatusCode,
    'providerResponse': providerResponse,
    'retryCount': retryCount,
    'lastAttempt': lastAttempt?.toIso8601String(),
  };

  factory SmsAlertQueueItem.fromJson(Map<String, dynamic> json) {
    return SmsAlertQueueItem(
      id: json['id'] as String? ?? 'SMS-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      eventType: SmsEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => SmsEventType.tempHigh,
      ),
      priority: SmsAlertPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => SmsAlertPriority.high,
      ),
      recipient: json['recipient'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: SmsAlertStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SmsAlertStatus.unknown,
      ),
      provider: json['provider'] as String? ?? 'Fast2SMS (India)',
      httpStatusCode: json['httpStatusCode'] as int?,
      providerResponse: json['providerResponse'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      lastAttempt: json['lastAttempt'] != null
          ? DateTime.tryParse(json['lastAttempt'] as String)
          : null,
    );
  }
}
