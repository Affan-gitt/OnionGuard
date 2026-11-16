import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/usb_serial_service.dart';

void showUsbConnectionModal(BuildContext context, WidgetRef ref) async {
  final usbService = ref.read(usbSerialServiceProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppConstants.darkBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: AppConstants.borderEmerald, width: 1),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return FutureBuilder<List<DiscoveredUsbDevice>>(
            future: usbService.getConnectedUsbDevices(),
            builder: (context, snapshot) {
              final devices = snapshot.data ?? [];
              final isLoading = snapshot.connectionState == ConnectionState.waiting;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.7,
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
                            Icon(Icons.usb, color: AppConstants.emerald, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'ESP32-H2 USB-C Connection',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.cream),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppConstants.mutedGreenGrey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Direct Android USB Host communication (CDC-ACM Serial @ 115200 Baud). Connect via USB-C to USB-C or OTG cable.',
                      style: TextStyle(fontSize: 12, color: AppConstants.mutedGreenGrey),
                    ),
                    const Divider(height: 24, color: AppConstants.borderEmerald),

                    if (isLoading) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator(color: AppConstants.emerald)),
                      ),
                    ] else if (devices.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppConstants.darkCardSurface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppConstants.borderEmerald),
                                ),
                                child: const Icon(Icons.usb_off, size: 40, color: AppConstants.mutedGreenGrey),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No USB Device Detected',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppConstants.cream),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '1. Plug a USB-C cable from phone to ESP32-H2.\n2. Ensure USB OTG is enabled in Android Settings.\n3. Verify ESP32 power LED is lit.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppConstants.borderEmerald),
                        itemBuilder: (context, index) {
                          final dev = devices[index];
                          final isEsp = dev.isEsp32 || dev.vendorId == 12346 || dev.vendorId == 0x303A;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isEsp ? AppConstants.emerald.withValues(alpha: 0.15) : AppConstants.darkCardSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isEsp ? AppConstants.emerald : AppConstants.borderEmerald,
                                ),
                              ),
                              child: Icon(
                                Icons.developer_board,
                                color: isEsp ? AppConstants.emerald : AppConstants.mutedGreenGrey,
                              ),
                            ),
                            title: Text(
                              isEsp ? 'ESP32-H2 DevKit 4' : dev.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppConstants.cream),
                            ),
                            subtitle: Text(
                              'VID: 0x${dev.vendorId.toRadixString(16).toUpperCase()} • PID: 0x${dev.productId.toRadixString(16).toUpperCase()} • ${dev.deviceName}',
                              style: const TextStyle(fontSize: 11, color: AppConstants.mutedGreenGrey),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isEsp ? AppConstants.emerald : AppConstants.darkCardSurface,
                                foregroundColor: isEsp ? AppConstants.darkBg : AppConstants.cream,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final ok = await usbService.scanAndConnectEsp32();
                                if (context.mounted && ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Connected to ESP32-H2 via USB CDC Serial!'),
                                      backgroundColor: AppConstants.emerald,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Connect USB'),
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Rescan USB'),
                            onPressed: () => setState(() {}),
                          ),
                        ),
                        if (usbService.isConnected) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.statusCritical,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Disconnect'),
                              onPressed: () {
                                usbService.disconnect();
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}
