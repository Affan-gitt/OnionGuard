import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class GasResponseCard extends StatelessWidget {
  final int rawAdc;
  final int baselineAdc;
  final double deltaPercent;
  final double triggerDeltaThreshold;
  final bool isTriggered;

  const GasResponseCard({
    super.key,
    required this.rawAdc,
    required this.baselineAdc,
    required this.deltaPercent,
    required this.triggerDeltaThreshold,
    required this.isTriggered,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isTriggered ? AppConstants.warmGold : AppConstants.emerald;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTriggered ? AppConstants.warmGold.withValues(alpha: 0.6) : AppConstants.borderEmerald,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isTriggered ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.science_outlined, size: 16, color: statusColor),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VOLATILE GAS SENSOR (MQ-3)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppConstants.cream,
                        ),
                      ),
                      Text(
                        'Alcohol / Spoilage Vapour Proxy',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: AppConstants.mutedGreenGrey.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Text(
                  isTriggered ? 'GAS ELEVATED' : 'BASELINE NORMAL',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Readings
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RESPONSE DELTA',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppConstants.mutedGreenGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${deltaPercent >= 0 ? "+" : ""}${deltaPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 38, color: AppConstants.borderEmerald),
              const SizedBox(width: 14),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Raw ADC:', style: TextStyle(fontSize: 10, color: AppConstants.mutedGreenGrey)),
                        Text('$rawAdc', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.cream)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Clean Baseline:', style: TextStyle(fontSize: 10, color: AppConstants.mutedGreenGrey)),
                        Text('$baselineAdc', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.cream)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Trigger Limit:', style: TextStyle(fontSize: 10, color: AppConstants.mutedGreenGrey)),
                        Text('+${triggerDeltaThreshold.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.warmGold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
