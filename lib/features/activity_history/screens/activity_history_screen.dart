import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utilities/csv_exporter.dart';
import '../../../data/models/activity_event.dart';
import '../../../data/models/sms_alert_queue_item.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';

class ActivityHistoryScreen extends ConsumerStatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  ConsumerState<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends ConsumerState<ActivityHistoryScreen> {
  String _selectedSeverity = 'ALL'; // ALL, INFO, WARNING, CRITICAL
  final String _selectedCategory = 'ALL';

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(eventsNotifierProvider);
    final smsService = ref.watch(smsServiceProvider);
    final smsQueue = smsService.alertQueue;

    final filteredEvents = allEvents.where((e) {
      if (_selectedSeverity != 'ALL' && e.severity.name.toUpperCase() != _selectedSeverity) {
        return false;
      }
      if (_selectedCategory != 'ALL' && e.category.name != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Activity & Alert Log',
          showBack: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export CSV',
              onPressed: () {
                final csv = CsvExporter.exportEventsToCsv(allEvents);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Event History CSV Export'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: SingleChildScrollView(
                        child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                      ),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            children: [
              // Segmented TabBar
              Container(
                color: Colors.white,
                child: const TabBar(
                  labelColor: AppConstants.primaryForest,
                  unselectedLabelColor: Color(0xFF64748B),
                  indicatorColor: Color(0xFF25D366),
                  indicatorWeight: 3,
                  tabs: [
                    Tab(icon: Icon(Icons.list_alt, size: 18), text: 'System Events Log'),
                    Tab(icon: Icon(Icons.chat_outlined, size: 18), text: 'WhatsApp Alert Queue'),
                  ],
                ),
              ),

              // TabBarViews
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: System Events Log
                    _buildEventsTab(filteredEvents),

                    // Tab 2: Persistent WhatsApp Alert Queue
                    _buildSmsQueueTab(smsQueue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsTab(List<ActivityEvent> filteredEvents) {
    return Column(
      children: [
        // Filter Chips Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSeverityChip('ALL', 'All Events'),
                const SizedBox(width: 8),
                _buildSeverityChip('INFO', 'Info'),
                const SizedBox(width: 8),
                _buildSeverityChip('WARNING', 'Warnings'),
                const SizedBox(width: 8),
                _buildSeverityChip('CRITICAL', 'Critical'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Events List
        Expanded(
          child: filteredEvents.isEmpty
              ? const Center(
                  child: Text('No events found matching filter.', style: TextStyle(color: Colors.grey)),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, MediaQuery.of(context).viewPadding.bottom + 20),
                  itemCount: filteredEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    return _buildEventTile(context, event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSmsQueueTab(List<SmsAlertQueueItem> smsQueue) {
    if (smsQueue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline, size: 40, color: Color(0xFF16A34A)),
              ),
              const SizedBox(height: 14),
              const Text(
                'WhatsApp Alert Queue Empty',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Instant alerts for high temperature, gas spikes, humidity safety cutoffs, or test notifications will appear here with live WhatsApp delivery status.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(14, 14, 14, MediaQuery.of(context).viewPadding.bottom + 20),
      itemCount: smsQueue.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = smsQueue[index];
        return _buildSmsQueueTile(context, item);
      },
    );
  }

  Widget _buildSmsQueueTile(BuildContext context, SmsAlertQueueItem item) {
    Color statusColor;
    IconData statusIcon;

    switch (item.status) {
      case SmsAlertStatus.delivered:
        statusColor = AppConstants.statusGreen;
        statusIcon = Icons.check_circle_outline;
        break;
      case SmsAlertStatus.submitted:
        statusColor = const Color(0xFF0284C7);
        statusIcon = Icons.outbox_outlined;
        break;
      case SmsAlertStatus.pending:
        statusColor = AppConstants.statusAmber;
        statusIcon = Icons.schedule;
        break;
      case SmsAlertStatus.failed:
        statusColor = AppConstants.statusRed;
        statusIcon = Icons.error_outline;
        break;
      case SmsAlertStatus.unknown:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.priority == SmsAlertPriority.high
                            ? AppConstants.statusRed.withOpacity(0.12)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.priority.displayName,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: item.priority == SmsAlertPriority.high ? AppConstants.statusRed : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        item.eventType.displayName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              StatusBadge(
                label: item.status.displayName.toUpperCase(),
                color: statusColor,
                icon: statusIcon,
                isSmall: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.message,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.3),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'To: ${item.recipient.isNotEmpty ? item.recipient : "None"} • ${item.provider}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd MMM HH:mm:ss').format(item.timestamp),
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          if (item.providerResponse != null && item.providerResponse!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Log: ${item.providerResponse}',
                style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Color(0xFF475569)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeverityChip(String code, String label) {
    final bool isSelected = _selectedSeverity == code;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
      ),
      selected: isSelected,
      selectedColor: AppConstants.primaryForest,
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide(color: isSelected ? AppConstants.primaryForest : AppConstants.subtleBorder),
      onSelected: (_) => setState(() => _selectedSeverity = code),
    );
  }

  Widget _buildEventTile(BuildContext context, ActivityEvent event) {
    return InkWell(
      onTap: () => _showEventDetails(context, event),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppConstants.subtleBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getSeverityColor(event.severity).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getCategoryIcon(event.category), size: 16, color: _getSeverityColor(event.severity)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusBadge(label: event.severity.displayName, color: _getSeverityColor(event.severity), isSmall: true),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    event.description,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${event.triggerSource} • ${event.operatingMode}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM HH:mm:ss').format(event.timestamp),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetails(BuildContext context, ActivityEvent event) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewPadding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                StatusBadge(label: event.severity.displayName, color: _getSeverityColor(event.severity)),
              ],
            ),
            const Divider(height: 20),
            Text(event.description, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            _buildDetailRow('Timestamp', DateFormat('yyyy-MM-dd HH:mm:ss').format(event.timestamp)),
            _buildDetailRow('Category', event.category.displayName),
            _buildDetailRow('Trigger Source', event.triggerSource),
            _buildDetailRow('Operating Mode', event.operatingMode),
            if (event.temperature != null) _buildDetailRow('Temperature', '${event.temperature}°C'),
            if (event.humidity != null) _buildDetailRow('Humidity', '${event.humidity}%'),
            if (event.gasAdc != null) _buildDetailRow('Gas Sensor', '${event.gasAdc} ADC'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Color _getSeverityColor(EventSeverity severity) {
    switch (severity) {
      case EventSeverity.info:
        return AppConstants.statusGreen;
      case EventSeverity.warning:
        return AppConstants.statusAmber;
      case EventSeverity.critical:
        return AppConstants.statusRed;
    }
  }

  IconData _getCategoryIcon(EventCategory category) {
    switch (category) {
      case EventCategory.environmental:
        return Icons.thermostat;
      case EventCategory.actuation:
        return Icons.mode_fan_off;
      case EventCategory.gasTest:
        return Icons.science;
      case EventCategory.inventory:
        return Icons.inventory_2;
      case EventCategory.system:
        return Icons.settings;
      case EventCategory.hygiene:
        return Icons.checklist_rtl;
      case EventCategory.alert:
        return Icons.notification_important;
      case EventCategory.simulation:
        return Icons.smart_toy;
    }
  }
}
