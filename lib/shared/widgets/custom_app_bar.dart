import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/ble_service.dart';
import '../../features/simulation/widgets/developer_pin_dialog.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/activity_history/screens/activity_history_screen.dart';
import 'usb_connection_dialog.dart';

class CustomAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions,
  });

  @override
  ConsumerState<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(62);
}

class _CustomAppBarState extends ConsumerState<CustomAppBar> {
  int _tapCount = 0;
  Timer? _tapResetTimer;

  void _onLogoTap() {
    _tapCount++;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(const Duration(milliseconds: 3000), () {
      _tapCount = 0;
    });

    if (_tapCount >= 5) {
      _tapCount = 0;
      _tapResetTimer?.cancel();
      showDialog(
        context: context,
        builder: (_) => const DeveloperPinDialog(),
      );
    }
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wifiService = ref.watch(wifiEsp32ServiceProvider);
    final usbService = ref.watch(usbSerialServiceProvider);
    final bleService = ref.watch(bleServiceProvider);
    final simService = ref.watch(simulationServiceProvider);

    final bool isSim = simService.isActive;
    final bool isWifi = wifiService.isConnected;
    final bool isUsb = usbService.isConnected;
    final bool isBle = bleService.state == BleConnectionState.connected;
    final bool isConnected = isWifi || isUsb || isBle;

    // In demo mode, status is seamlessly active without any visible "SIMULATION" label
    final Color pillColor = (isConnected || isSim) ? AppConstants.emerald : AppConstants.mutedGreenGrey;
    final IconData pillIcon = isWifi
        ? Icons.wifi
        : (isUsb ? Icons.usb : (isBle ? Icons.bluetooth_connected : (isSim ? Icons.sensors : Icons.sensors_off)));
    final String pillLabel = isWifi
        ? 'WIFI OK'
        : (isUsb ? 'USB OK' : (isBle ? 'BLE OK' : (isSim ? 'SENSORS OK' : 'OFFLINE')));

    return AppBar(
      backgroundColor: AppConstants.darkBg,
      foregroundColor: AppConstants.cream,
      elevation: 0,
      automaticallyImplyLeading: widget.showBack,
      titleSpacing: widget.showBack ? 0 : 16,
      title: InkWell(
        onTap: _onLogoTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/tor_logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppConstants.deepForest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.emerald),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppConstants.emerald, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.cream,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    DateFormat('EEE, d MMM • HH:mm').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppConstants.mutedGreenGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Connection status pill
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showUsbConnectionModal(context, ref);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: pillColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: pillColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pillIcon,
                  size: 13,
                  color: pillColor,
                ),
                const SizedBox(width: 4),
                Text(
                  pillLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: pillColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Activity / Alerts bell
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 22, color: AppConstants.cream),
          tooltip: 'Activity History & Alerts',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ActivityHistoryScreen()),
            );
          },
        ),

        // Settings gear
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22, color: AppConstants.cream),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        if (widget.actions != null) ...widget.actions!,
        const SizedBox(width: 4),
      ],
    );
  }
}
