import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/hygiene_entry.dart';
import '../../../data/models/activity_event.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';

class HygieneChecklistScreen extends ConsumerStatefulWidget {
  const HygieneChecklistScreen({super.key});

  @override
  ConsumerState<HygieneChecklistScreen> createState() => _HygieneChecklistScreenState();
}

class _HygieneChecklistScreenState extends ConsumerState<HygieneChecklistScreen> {
  final _inspectorController = TextEditingController(text: 'Operator 1');
  final _notesController = TextEditingController();
  final Map<String, bool> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    for (final criterion in HygieneEntry.standardCriteria) {
      _checkedItems[criterion] = false;
    }
  }

  @override
  void dispose() {
    _inspectorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _currentScore {
    int passed = _checkedItems.values.where((v) => v).length;
    return (passed / HygieneEntry.standardCriteria.length) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(hygieneNotifierProvider);
    final score = _currentScore;

    Color scoreColor = AppConstants.statusGreen;
    if (score < 60) {
      scoreColor = AppConstants.statusRed;
    } else if (score < 80) {
      scoreColor = AppConstants.statusAmber;
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Storage Hygiene Checklist', showBack: true),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            14,
            14,
            14,
            MediaQuery.of(context).viewPadding.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hygiene compliance score is an operational protocol checklist and does not constitute laboratory-certified biological pathogen clearance.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Score Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.subtleBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scoreColor.withOpacity(0.12),
                      border: Border.all(color: scoreColor, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        '${score.round()}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Compliance Rating',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_checkedItems.values.where((v) => v).length} of ${HygieneEntry.standardCriteria.length} inspection criteria passed',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        StatusBadge(
                          label: score >= 80 ? 'SATISFACTORY' : (score >= 60 ? 'NEEDS ATTENTION' : 'CRITICAL DEFICIT'),
                          color: scoreColor,
                          isSmall: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Checklist Form
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Sanitation Checklist',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inspectorController,
                          decoration: const InputDecoration(labelText: 'Responsible Inspector', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: HygieneEntry.standardCriteria.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (context, index) {
                      final criterion = HygieneEntry.standardCriteria[index];
                      final isChecked = _checkedItems[criterion] ?? false;
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(criterion, style: const TextStyle(fontSize: 12.5)),
                        value: isChecked,
                        activeColor: AppConstants.primaryForest,
                        onChanged: (val) {
                          setState(() {
                            _checkedItems[criterion] = val ?? false;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Sanitation / Inspection Notes',
                      hintText: 'e.g. Cleared sweepings, wiped condensation trays...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Submit Daily Hygiene Report'),
                      onPressed: () async {
                        final entry = HygieneEntry(
                          id: 'HYG-${DateTime.now().millisecondsSinceEpoch}',
                          date: DateTime.now(),
                          inspector: _inspectorController.text.trim(),
                          notes: _notesController.text.trim(),
                          items: Map.from(_checkedItems),
                          scorePercentage: score,
                        );
                        await ref.read(hygieneNotifierProvider.notifier).addEntry(entry);

                        // Record in Activity History
                        ref.read(eventsNotifierProvider.notifier).addEvent(
                          ActivityEvent(
                            id: 'EVT-${DateTime.now().millisecondsSinceEpoch}',
                            timestamp: DateTime.now(),
                            category: EventCategory.hygiene,
                            severity: score >= 80 ? EventSeverity.info : EventSeverity.warning,
                            title: 'Hygiene Inspection Logged (${score.round()}%)',
                            description: 'Inspector: ${entry.inspector} • Score: ${score.round()}% • Criteria: ${entry.items.values.where((v) => v).length}/10',
                            triggerSource: 'Manual Inspection',
                          ),
                        );

                        _notesController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Daily hygiene checklist recorded successfully!')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Historical Compliance Logs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historical Compliance Audits',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                  ),
                  const Divider(height: 20),
                  if (history.isEmpty)
                    const Text('No prior checklist records.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const Divider(height: 14),
                      itemBuilder: (context, index) {
                        final item = history[index];
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (item.scorePercentage >= 80 ? AppConstants.statusGreen : AppConstants.statusAmber).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.scorePercentage.round()}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: item.scorePercentage >= 80 ? AppConstants.statusGreen : AppConstants.statusAmber,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Inspector: ${item.inspector}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  if (item.notes.isNotEmpty)
                                    Text(
                                      item.notes,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('MMM d, HH:mm').format(item.date),
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
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
