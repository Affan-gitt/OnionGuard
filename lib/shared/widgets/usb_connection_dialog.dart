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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                            Icon(Icons.usb, color: AppConstants.primaryForest, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'ESP32-H2 USB-C Connection',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Direct Android USB Host communication (CDC-ACM Serial @ 115200 Baud). Connect via USB-C to USB-C or OTG cable.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const Divider(height: 24),

                    if (isLoading) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator(color: AppConstants.primaryForest)),
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
                                  color: Colors.grey.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.usb_off, size: 40, color: Colors.grey),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No USB Device Detected',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '1. Plug a USB-C cable from phone to ESP32-H2.\n2. Ensure USB OTG is enabled in Android Settings.\n3. Verify ESP32 power LED is lit.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final dev = devices[index];
                          final isEsp = dev.isEsp32 || dev.vendorId == 12346 || dev.vendorId == 0x303A;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isEsp ? AppConstants.statusGreen.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.developer_board,
                                color: isEsp ? AppConstants.statusGreen : Colors.grey,
                              ),
                            ),
                            title: Text(
                              isEsp ? 'ESP32-H2 DevKit 4' : dev.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              'VID: 0x${dev.vendorId.toRadixString(16).toUpperCase()} • PID: 0x${dev.productId.toRadixString(16).toUpperCase()} • ${dev.deviceName}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isEsp ? AppConstants.primaryForest : Colors.grey.shade700,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final ok = await usbService.scanAndConnectEsp32();
                                if (context.mounted && ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Connected to ESP32-H2 via USB CDC Serial!'),
                                      backgroundColor: AppConstants.statusGreen,
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
                              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.statusRed),
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
