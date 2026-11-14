import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/onion_item.dart';

class OnionSpotWidget extends StatelessWidget {
  final int spotNumber;
  final OnionItem? onion;
  final VoidCallback onTap;

  const OnionSpotWidget({
    super.key,
    required this.spotNumber,
    this.onion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = onion == null;
    final Color statusColor = isEmpty ? AppConstants.statusGrey : onion!.condition.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isEmpty ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEmpty ? AppConstants.subtleBorder : statusColor.withOpacity(0.5),
            width: isEmpty ? 1 : 1.5,
          ),
          boxShadow: isEmpty
              ? null
              : [
                  BoxShadow(
                    color: statusColor.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'P$spotNumber',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                if (!isEmpty && onion!.isDemo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'DEMO',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Icon(
              isEmpty ? Icons.add_circle_outline : Icons.circle,
              color: statusColor,
              size: isEmpty ? 24 : 22,
            ),
            const SizedBox(height: 6),
            Text(
              isEmpty ? 'Empty Spot' : onion!.id,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isEmpty) ...[
              const SizedBox(height: 2),
              Text(
                onion!.variety,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  onion!.condition.shortCode,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
