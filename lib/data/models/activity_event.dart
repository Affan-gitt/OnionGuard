import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

enum EventCategory {
  environmental,
  actuation,
  gasTest,
  inventory,
  hygiene,
  alert,
  system,
  simulation,
}

extension EventCategoryExtension on EventCategory {
  String get displayName {
    switch (this) {
      case EventCategory.environmental:
        return 'Environmental';
      case EventCategory.actuation:
        return 'Actuation';
      case EventCategory.gasTest:
        return 'Gas Sensor Test';
      case EventCategory.inventory:
        return 'Onion Inventory';
      case EventCategory.hygiene:
        return 'Hygiene Checklist';
      case EventCategory.alert:
        return 'Notification / Alert';
      case EventCategory.system:
        return 'Hardware / System';
      case EventCategory.simulation:
        return 'Simulation Engine';
    }
  }

  IconData get icon {
    switch (this) {
      case EventCategory.environmental:
        return Icons.thermostat;
      case EventCategory.actuation:
        return Icons.mode_fan_off;
      case EventCategory.gasTest:
        return Icons.science;
      case EventCategory.inventory:
        return Icons.grid_view;
      case EventCategory.hygiene:
        return Icons.checklist_rtl;
      case EventCategory.alert:
        return Icons.notifications_active;
      case EventCategory.system:
        return Icons.settings_input_component;
      case EventCategory.simulation:
        return Icons.smart_toy;
    }
  }
}

enum EventSeverity {
  info,
  warning,
  critical,
}

extension EventSeverityExtension on EventSeverity {
  String get displayName {
    switch (this) {
      case EventSeverity.info:
        return 'INFO';
      case EventSeverity.warning:
        return 'WARNING';
      case EventSeverity.critical:
        return 'CRITICAL';
    }
  }

  Color get color {
    switch (this) {
      case EventSeverity.info:
        return AppConstants.statusBlue;
      case EventSeverity.warning:
        return AppConstants.statusAmber;
      case EventSeverity.critical:
        return AppConstants.statusRed;
    }
  }
}

class ActivityEvent {
  final String id;
  final DateTime timestamp;
  final EventCategory category;
  final EventSeverity severity;
  final String title;
  final String description;
  final String triggerSource;
  final String operatingMode; // "LIVE" or "SIMULATION"
  final double? temperature;
  final double? humidity;
  final int? gasAdc;

  ActivityEvent({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    this.triggerSource = 'Automatic Control',
    this.operatingMode = 'LIVE',
    this.temperature,
    this.humidity,
    this.gasAdc,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'category': category.name,
    'severity': severity.name,
    'title': title,
    'description': description,
    'triggerSource': triggerSource,
    'operatingMode': operatingMode,
    'temperature': temperature,
    'humidity': humidity,
    'gasAdc': gasAdc,
  };

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    category: EventCategory.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => EventCategory.system,
    ),
    severity: EventSeverity.values.firstWhere(
      (e) => e.name == json['severity'],
      orElse: () => EventSeverity.info,
    ),
    title: json['title'] as String,
    description: json['description'] as String,
    triggerSource: json['triggerSource'] as String? ?? 'Automatic Control',
    operatingMode: json['operatingMode'] as String? ?? 'LIVE',
    temperature: (json['temperature'] as num?)?.toDouble(),
    humidity: (json['humidity'] as num?)?.toDouble(),
    gasAdc: json['gasAdc'] as int?,
  );
}
