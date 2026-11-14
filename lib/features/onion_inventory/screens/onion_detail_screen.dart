import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/onion_item.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';

class OnionDetailScreen extends ConsumerStatefulWidget {
  final String onionId;

  const OnionDetailScreen({super.key, required this.onionId});

  @override
  ConsumerState<OnionDetailScreen> createState() => _OnionDetailScreenState();
}

class _OnionDetailScreenState extends ConsumerState<OnionDetailScreen> {
  final _notesController = TextEditingController();
  final _weightController = TextEditingController();
  OnionCondition? _selectedCondition;

  @override
  void dispose() {
    _notesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _showMoveDialog(BuildContext context, OnionItem onion) {
    String targetRack = onion.rack;
    int targetShelf = onion.shelf;
    int targetSpot = onion.spot;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Move Onion Position', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: targetRack,
                  decoration: const InputDecoration(labelText: 'Target Rack'),
                  items: const [
                    DropdownMenuItem(value: 'Rack A', child: Text('Rack A')),
                    DropdownMenuItem(value: 'Rack B', child: Text('Rack B')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => targetRack = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: targetShelf,
                  decoration: const InputDecoration(labelText: 'Target Shelf'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Shelf 1')),
                    DropdownMenuItem(value: 2, child: Text('Shelf 2')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => targetShelf = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: targetSpot,
                  decoration: const InputDecoration(labelText: 'Target Spot'),
                  items: [1, 2, 3, 4].map((s) => DropdownMenuItem(value: s, child: Text('Spot $s'))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => targetSpot = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(onionInventoryNotifierProvider.notifier).moveOnion(
                    id: onion.id,
                    newRack: targetRack,
                    newShelf: targetShelf,
                    newSpot: targetSpot,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Onion ${onion.id} moved to $targetRack • Shelf $targetShelf, Spot $targetSpot')),
                  );
                },
                child: const Text('Move'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, OnionItem onion) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove / Quarantine Onion?'),
        content: Text('Are you sure you want to remove ${onion.id} (${onion.variety}) from storage inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.statusRed),
            onPressed: () async {
              await ref.read(onionInventoryNotifierProvider.notifier).deleteOnion(onion.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Onion ${onion.id} quarantined/removed.')),
              );
            },
            child: const Text('Confirm Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onions = ref.watch(onionInventoryNotifierProvider);
    final onion = onions.firstWhere(
      (o) => o.id == widget.onionId,
      orElse: () => OnionItem(
        id: 'NOT_FOUND',
        rack: 'Rack A',
        shelf: 1,
        spot: 1,
        variety: 'Unknown',
        dateAdded: DateTime.now(),
        lastInspection: DateTime.now(),
        condition: OnionCondition.notInspected,
      ),
    );

    if (onion.id == 'NOT_FOUND') {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Onion Inspection', showBack: true),
        body: const Center(child: Text('Onion record not found.')),
      );
    }

    _selectedCondition ??= onion.condition;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Inspection: ${onion.id}',
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_move_outlined),
            tooltip: 'Move Position',
            onPressed: () => _showMoveDialog(context, onion),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove Onion',
            onPressed: () => _showDeleteDialog(context, onion),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewPadding.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.subtleBorder),
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
                            Flexible(
                              child: Text(
                                onion.id,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (onion.isDemo) ...[
                              const SizedBox(width: 8),
                              const StatusBadge(label: 'DEMO DATA', color: Colors.orange, isSmall: true),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: onion.condition.displayName,
                        color: onion.condition.color,
                        icon: Icons.circle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Variety: ${onion.variety}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Storage Location: ${onion.locationString}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Stored: ${DateFormat('yyyy-MM-dd').format(onion.dateAdded)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        'Last Checked: ${DateFormat('MMM d, HH:mm').format(onion.lastInspection)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Condition Update Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Record New Inspection',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Observed Condition:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<OnionCondition>(
                    value: _selectedCondition,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
                      if (val != null) setState(() => _selectedCondition = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Current Bulb Weight (grams)',
                      hintText: onion.weightGrams != null ? '${onion.weightGrams}g' : 'e.g. 145.5',
                      suffixText: 'g',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Inspection Notes / Physical Assessment',
                      hintText: 'e.g. Neck firmness, skin dry scale, aroma...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Inspection Record'),
                      onPressed: () async {
                        final double? weight = double.tryParse(_weightController.text.trim()) ?? onion.weightGrams;
                        final note = _notesController.text.trim();
                        await ref.read(onionInventoryNotifierProvider.notifier).updateCondition(
                          id: onion.id,
                          newCondition: _selectedCondition ?? onion.condition,
                          note: note,
                          newWeight: weight,
                        );
                        _notesController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Inspection saved for ${onion.id}')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Condition History Timeline
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history, size: 18, color: AppConstants.primaryForest),
                      SizedBox(width: 8),
                      Text(
                        'Condition & Inspection History',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (onion.conditionHistory.isEmpty)
                    const Text('No prior condition changes logged.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: onion.conditionHistory.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final log = onion.conditionHistory[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: log.condition.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        log.condition.displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: log.condition.color,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp),
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                  if (log.note.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      log.note,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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
