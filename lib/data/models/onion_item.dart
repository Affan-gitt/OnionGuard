import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

enum OnionCondition {
  healthy,
  softening,
  suspectedDeterioration,
  visibleRot,
  mouldObserved,
  damaged,
  notInspected,
}

extension OnionConditionExtension on OnionCondition {
  String get displayName {
    switch (this) {
      case OnionCondition.healthy:
        return 'Healthy / Fresh';
      case OnionCondition.softening:
        return 'Soft / Check Soon';
      case OnionCondition.suspectedDeterioration:
        return 'Suspected Deterioration';
      case OnionCondition.visibleRot:
        return 'Visible Rot';
      case OnionCondition.mouldObserved:
        return 'Mould Observed';
      case OnionCondition.damaged:
        return 'Mechanical Damage';
      case OnionCondition.notInspected:
        return 'Not Inspected';
    }
  }

  Color get color {
    switch (this) {
      case OnionCondition.healthy:
        return AppConstants.statusGreen;
      case OnionCondition.softening:
      case OnionCondition.suspectedDeterioration:
        return AppConstants.statusAmber;
      case OnionCondition.visibleRot:
      case OnionCondition.mouldObserved:
      case OnionCondition.damaged:
        return AppConstants.statusRed;
      case OnionCondition.notInspected:
        return AppConstants.statusGrey;
    }
  }

  String get shortCode {
    switch (this) {
      case OnionCondition.healthy:
        return 'FRSH';
      case OnionCondition.softening:
        return 'SOFT';
      case OnionCondition.suspectedDeterioration:
        return 'DTRT';
      case OnionCondition.visibleRot:
        return 'ROT';
      case OnionCondition.mouldObserved:
        return 'MLD';
      case OnionCondition.damaged:
        return 'DMG';
      case OnionCondition.notInspected:
        return 'UNIN';
    }
  }
}

class ConditionLog {
  final DateTime timestamp;
  final OnionCondition condition;
  final String note;

  ConditionLog({
    required this.timestamp,
    required this.condition,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'condition': condition.name,
    'note': note,
  };

  factory ConditionLog.fromJson(Map<String, dynamic> json) => ConditionLog(
    timestamp: DateTime.parse(json['timestamp'] as String),
    condition: OnionCondition.values.firstWhere(
      (e) => e.name == json['condition'],
      orElse: () => OnionCondition.healthy,
    ),
    note: json['note'] as String? ?? '',
  );
}

class OnionItem {
  final String id;
  final String rack; // "Rack A" or "Rack B"
  final int shelf;   // 1 or 2
  final int spot;    // 1 to 4
  final String variety;
  final DateTime dateAdded;
  final DateTime lastInspection;
  final OnionCondition condition;
  final double? weightGrams;
  final String inspectionNotes;
  final List<ConditionLog> conditionHistory;
  final bool isDemo;
  final bool isRemoved;

  OnionItem({
    required this.id,
    required this.rack,
    required this.shelf,
    required this.spot,
    required this.variety,
    required this.dateAdded,
    required this.lastInspection,
    required this.condition,
    this.weightGrams,
    this.inspectionNotes = '',
    List<ConditionLog>? conditionHistory,
    this.isDemo = false,
    this.isRemoved = false,
  }) : conditionHistory = conditionHistory ?? [];

  String get locationString => '$rack • Shelf $shelf, Spot $spot';

  OnionItem copyWith({
    String? id,
    String? rack,
    int? shelf,
    int? spot,
    String? variety,
    DateTime? dateAdded,
    DateTime? lastInspection,
    OnionCondition? condition,
    double? weightGrams,
    String? inspectionNotes,
    List<ConditionLog>? conditionHistory,
    bool? isDemo,
    bool? isRemoved,
  }) {
    return OnionItem(
      id: id ?? this.id,
      rack: rack ?? this.rack,
      shelf: shelf ?? this.shelf,
      spot: spot ?? this.spot,
      variety: variety ?? this.variety,
      dateAdded: dateAdded ?? this.dateAdded,
      lastInspection: lastInspection ?? this.lastInspection,
      condition: condition ?? this.condition,
      weightGrams: weightGrams ?? this.weightGrams,
      inspectionNotes: inspectionNotes ?? this.inspectionNotes,
      conditionHistory: conditionHistory ?? this.conditionHistory,
      isDemo: isDemo ?? this.isDemo,
      isRemoved: isRemoved ?? this.isRemoved,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'rack': rack,
    'shelf': shelf,
    'spot': spot,
    'variety': variety,
    'dateAdded': dateAdded.toIso8601String(),
    'lastInspection': lastInspection.toIso8601String(),
    'condition': condition.name,
    'weightGrams': weightGrams,
    'inspectionNotes': inspectionNotes,
    'conditionHistory': conditionHistory.map((c) => c.toJson()).toList(),
    'isDemo': isDemo,
    'isRemoved': isRemoved,
  };

  factory OnionItem.fromJson(Map<String, dynamic> json) => OnionItem(
    id: json['id'] as String,
    rack: json['rack'] as String,
    shelf: json['shelf'] as int,
    spot: json['spot'] as int,
    variety: json['variety'] as String,
    dateAdded: DateTime.parse(json['dateAdded'] as String),
    lastInspection: DateTime.parse(json['lastInspection'] as String),
    condition: OnionCondition.values.firstWhere(
      (e) => e.name == json['condition'],
      orElse: () => OnionCondition.healthy,
    ),
    weightGrams: (json['weightGrams'] as num?)?.toDouble(),
    inspectionNotes: json['inspectionNotes'] as String? ?? '',
    conditionHistory: (json['conditionHistory'] as List<dynamic>?)
            ?.map((e) => ConditionLog.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    isDemo: json['isDemo'] as bool? ?? false,
    isRemoved: json['isRemoved'] as bool? ?? false,
  );
}
