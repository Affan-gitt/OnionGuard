class HygieneEntry {
  final String id;
  final DateTime date;
  final String inspector;
  final String notes;
  final Map<String, bool> items;
  final double scorePercentage;

  static const List<String> standardCriteria = [
    'Storage room floor clean and swept',
    'Storage shelves completely dry',
    'No standing water or high condensation',
    'Adequate ventilation clearance around racks',
    'No visible mould or fungal growth observed',
    'No rotten or deteriorating onions left in storage',
    'Damaged or sprouting onions segregated',
    'Daily manual inspection completed',
    'Humidifier module sanitized and drained',
    'Sensor grilles and fan pathways free of dust',
  ];

  HygieneEntry({
    required this.id,
    required this.date,
    required this.inspector,
    this.notes = '',
    required this.items,
    required this.scorePercentage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'inspector': inspector,
    'notes': notes,
    'items': items,
    'scorePercentage': scorePercentage,
  };

  factory HygieneEntry.fromJson(Map<String, dynamic> json) => HygieneEntry(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    inspector: json['inspector'] as String,
    notes: json['notes'] as String? ?? '',
    items: (json['items'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool)),
    scorePercentage: (json['scorePercentage'] as num).toDouble(),
  );
}
