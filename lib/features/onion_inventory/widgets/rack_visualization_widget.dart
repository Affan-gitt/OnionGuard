import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/onion_item.dart';
import 'onion_spot_widget.dart';

class RackVisualizationWidget extends StatelessWidget {
  final String rackName; // "Rack A" or "Rack B"
  final List<OnionItem> onions;
  final Function(OnionItem onion) onSelectOnion;
  final Function(String rack, int shelf, int spot) onEmptySpotTap;

  const RackVisualizationWidget({
    super.key,
    required this.rackName,
    required this.onions,
    required this.onSelectOnion,
    required this.onEmptySpotTap,
  });

  OnionItem? _findOnion(int shelf, int spot) {
    try {
      return onions.firstWhere((o) => o.rack == rackName && o.shelf == shelf && o.spot == spot);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.subtleBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryForest.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.shelves, color: AppConstants.primaryForest, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rackName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.primaryForest,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppConstants.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${onions.where((o) => o.rack == rackName).length} / 8 Occupied',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Shelf 1
          _buildShelf(context, shelfNumber: 1),
          const SizedBox(height: 14),

          // Shelf 2
          _buildShelf(context, shelfNumber: 2),
        ],
      ),
    );
  }

  Widget _buildShelf(BuildContext context, {required int shelfNumber}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_rows_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Shelf $shelfNumber (Spots 1–4)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final spotNum = index + 1;
              final onion = _findOnion(shelfNumber, spotNum);
              return OnionSpotWidget(
                spotNumber: spotNum,
                onion: onion,
                onTap: () {
                  if (onion != null) {
                    onSelectOnion(onion);
                  } else {
                    onEmptySpotTap(rackName, shelfNumber, spotNum);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
