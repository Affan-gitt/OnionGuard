import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/ble_service.dart';

void showBleScanModal(BuildContext context, WidgetRef ref) {
  final ble = ref.read(bleServiceProvider);
  ble.startScan();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bluetooth_searching, color: AppConstants.primaryForest, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Connect ESP32-H2 Hardware',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    ble.stopScan();
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Scanning for nearby OnionGuard ESP32-H2 DevKit units advertising BLE GATT service...',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const Divider(height: 24),
            StreamBuilder<List<DiscoveredBleDevice>>(
              stream: ble.discoveredDevicesStream,
              builder: (context, snapshot) {
                final devices = snapshot.data ?? [];
                if (devices.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppConstants.primaryForest),
                          SizedBox(height: 16),
                          Text(
                            'Listening for ESP32-H2 advertisement packets...',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Make sure your ESP32-H2 board is powered ON',
                            style: TextStyle(fontSize: 11, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final dev = devices[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryForest.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bluetooth, color: AppConstants.primaryForest),
                      ),
                      title: Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        'MAC: ${dev.id}  •  Signal: ${dev.rssi} dBm',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryForest,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await ble.connect(dev);
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Connected to ${dev.name}! Streaming live sensor feed.'),
                                backgroundColor: AppConstants.statusGreen,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Rescan'),
                onPressed: () => ble.startScan(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
