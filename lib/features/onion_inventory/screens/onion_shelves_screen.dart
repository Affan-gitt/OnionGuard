import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/onion_item.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../widgets/rack_visualization_widget.dart';
import 'onion_detail_screen.dart';
import 'add_onion_dialog.dart';

class OnionShelvesScreen extends ConsumerStatefulWidget {
  const OnionShelvesScreen({super.key});

  @override
  ConsumerState<OnionShelvesScreen> createState() => _OnionShelvesScreenState();
}

class _OnionShelvesScreenState extends ConsumerState<OnionShelvesScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, HEALTHY, SOFT, DETERIORATING, ROT_MOULD

  @override
  Widget build(BuildContext context) {
    final allOnions = ref.watch(onionInventoryNotifierProvider);

    // Filter calculations
    final int totalTracked = allOnions.length;
    final int freshCount = allOnions.where((o) => o.condition == OnionCondition.healthy).length;
    final int softCount = allOnions.where((o) => o.condition == OnionCondition.softening).length;
    final int suspectedCount = allOnions.where((o) => o.condition == OnionCondition.suspectedDeterioration).length;
    final int rotMouldCount = allOnions.where((o) =>
      o.condition == OnionCondition.visibleRot ||
      o.condition == OnionCondition.mouldObserved ||
      o.condition == OnionCondition.damaged
    ).length;

    // Apply filters and search
    final filteredOnions = allOnions.where((o) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!o.id.toLowerCase().contains(q) && !o.variety.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_selectedFilter == 'HEALTHY') {
        return o.condition == OnionCondition.healthy;
      } else if (_selectedFilter == 'SOFT') {
        return o.condition == OnionCondition.softening;
      } else if (_selectedFilter == 'DETERIORATING') {
        return o.condition == OnionCondition.suspectedDeterioration;
      } else if (_selectedFilter == 'ROT_MOULD') {
        return o.condition == OnionCondition.visibleRot ||
               o.condition == OnionCondition.mouldObserved ||
               o.condition == OnionCondition.damaged;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Onion Storage Shelves',
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () {
              final csv = ref.read(onionRepositoryProvider).exportToCsv();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Inventory CSV Export'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        csv,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Onion',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const AddOnionDialog(
                  defaultRack: 'Rack B',
                  defaultShelf: 2,
                  defaultSpot: 1,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Top Summary Row
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Storage Rack Inventory Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryForest,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSummaryPill('Total', totalTracked.toString(), AppConstants.primaryForest),
                        const SizedBox(width: 6),
                        _buildSummaryPill('Fresh', freshCount.toString(), AppConstants.statusGreen),
                        const SizedBox(width: 6),
                        _buildSummaryPill('Soft', softCount.toString(), AppConstants.statusAmber),
                        const SizedBox(width: 6),
                        _buildSummaryPill('Suspected', suspectedCount.toString(), Colors.deepOrange),
                        const SizedBox(width: 6),
                        _buildSummaryPill('Rot/Mould', rotMouldCount.toString(), AppConstants.statusRed),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search and Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search onion ID, variety...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('ALL', 'All Onions ($totalTracked)'),
                        const SizedBox(width: 6),
                        _buildFilterChip('HEALTHY', 'Fresh ($freshCount)'),
                        const SizedBox(width: 6),
                        _buildFilterChip('SOFT', 'Softening ($softCount)'),
                        const SizedBox(width: 6),
                        _buildFilterChip('DETERIORATING', 'Suspected ($suspectedCount)'),
                        const SizedBox(width: 6),
                        _buildFilterChip('ROT_MOULD', 'Rot/Mould ($rotMouldCount)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Rack A Visualization
            RackVisualizationWidget(
              rackName: 'Rack A',
              onions: filteredOnions,
              onSelectOnion: (onion) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OnionDetailScreen(onionId: onion.id)),
                );
              },
              onEmptySpotTap: (rack, shelf, spot) {
                showDialog(
                  context: context,
                  builder: (_) => AddOnionDialog(
                    defaultRack: rack,
                    defaultShelf: shelf,
                    defaultSpot: spot,
                  ),
                );
              },
            ),

            // Rack B Visualization
            RackVisualizationWidget(
              rackName: 'Rack B',
              onions: filteredOnions,
              onSelectOnion: (onion) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OnionDetailScreen(onionId: onion.id)),
                );
              },
              onEmptySpotTap: (rack, shelf, spot) {
                showDialog(
                  context: context,
                  builder: (_) => AddOnionDialog(
                    defaultRack: rack,
                    defaultShelf: shelf,
                    defaultSpot: spot,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSummaryPill(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final bool isSelected = _selectedFilter == filterKey;
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
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppConstants.primaryForest : AppConstants.subtleBorder,
      ),
      onSelected: (_) {
        setState(() => _selectedFilter = filterKey);
      },
    );
  }
}
