import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/onion_item.dart';

class AddOnionDialog extends ConsumerStatefulWidget {
  final String defaultRack;
  final int defaultShelf;
  final int defaultSpot;

  const AddOnionDialog({
    super.key,
    required this.defaultRack,
    required this.defaultShelf,
    required this.defaultSpot,
  });

  @override
  ConsumerState<AddOnionDialog> createState() => _AddOnionDialogState();
}

class _AddOnionDialogState extends ConsumerState<AddOnionDialog> {
  late TextEditingController _idController;
  final _weightController = TextEditingController(text: '150.0');
  final _notesController = TextEditingController();

  late String _rack;
  late int _shelf;
  late int _spot;
  String _variety = AppConstants.onionVarieties.first;
  OnionCondition _condition = OnionCondition.healthy;

  @override
  void initState() {
    super.initState();
    _rack = widget.defaultRack;
    _shelf = widget.defaultShelf;
    _spot = widget.defaultSpot;
    final rackCode = _rack.contains('A') ? 'A' : 'B';
    _idController = TextEditingController(text: 'ONG-$rackCode$_shelf-0$_spot');
  }

  @override
  void dispose() {
    _idController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryForest.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_circle, color: AppConstants.primaryForest),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add Onion to Shelf',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Onion Tag / ID'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _rack,
                      decoration: const InputDecoration(labelText: 'Rack'),
                      items: const [
                        DropdownMenuItem(value: 'Rack A', child: Text('Rack A')),
                        DropdownMenuItem(value: 'Rack B', child: Text('Rack B')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _rack = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _shelf,
                      decoration: const InputDecoration(labelText: 'Shelf'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Shelf 1')),
                        DropdownMenuItem(value: 2, child: Text('Shelf 2')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _shelf = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _spot,
                      decoration: const InputDecoration(labelText: 'Spot'),
                      items: [1, 2, 3, 4].map((s) => DropdownMenuItem(value: s, child: Text('Spot $s'))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _spot = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _variety,
                decoration: const InputDecoration(labelText: 'Onion Variety'),
                items: AppConstants.onionVarieties.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _variety = val);
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<OnionCondition>(
                value: _condition,
                decoration: const InputDecoration(labelText: 'Initial Condition'),
                items: OnionCondition.values.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: c.color, size: 12),
                        const SizedBox(width: 8),
                        Text(c.displayName, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _condition = val);
                },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight (grams)', suffixText: 'g'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Initial Notes', hintText: 'Dry scale, dormancy status...'),
              ),
              const SizedBox(height: 18),

              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Add to Inventory'),
                onPressed: () async {
                  final id = _idController.text.trim();
                  if (id.isEmpty) return;

                  final now = DateTime.now();
                  final double? weight = double.tryParse(_weightController.text.trim());
                  final note = _notesController.text.trim();

                  final newOnion = OnionItem(
                    id: id,
                    rack: _rack,
                    shelf: _shelf,
                    spot: _spot,
                    variety: _variety,
                    dateAdded: now,
                    lastInspection: now,
                    condition: _condition,
                    weightGrams: weight,
                    inspectionNotes: note,
                    isDemo: false,
                    conditionHistory: [
                      ConditionLog(timestamp: now, condition: _condition, note: note.isNotEmpty ? note : 'Added to storage inventory.'),
                    ],
                  );

                  await ref.read(onionInventoryNotifierProvider.notifier).addOnion(newOnion);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Onion $id successfully placed on $_rack • Shelf $_shelf, Spot $_spot.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
