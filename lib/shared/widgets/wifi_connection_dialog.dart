import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/constants/app_constants.dart';

void showWifiConnectionModal(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const WifiConnectionSheet(),
  );
}

class WifiConnectionSheet extends ConsumerStatefulWidget {
  const WifiConnectionSheet({super.key});

  @override
  ConsumerState<WifiConnectionSheet> createState() => _WifiConnectionSheetState();
}

class _WifiConnectionSheetState extends ConsumerState<WifiConnectionSheet> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  bool _isConnecting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final wifi = ref.read(wifiEsp32ServiceProvider);
    _ipController = TextEditingController(text: wifi.espIp);
    _portController = TextEditingController(text: wifi.port.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = null;
    });

    final wifi = ref.read(wifiEsp32ServiceProvider);
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 80;

    final success = await wifi.connect(ip: ip, port: port);

    if (mounted) {
      setState(() {
        _isConnecting = false;
        _statusMessage = success
            ? 'Connected successfully to ESP32 at $ip!'
            : 'Could not connect to $ip:$port. Check Wi-Fi connection.';
      });

      if (success) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  void _handleDisconnect() {
    ref.read(wifiEsp32ServiceProvider).disconnect();
    setState(() {
      _statusMessage = 'Disconnected from ESP32.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final wifi = ref.watch(wifiEsp32ServiceProvider);
    final isConnected = wifi.isConnected;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.wifi, color: AppConstants.primaryForest, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'ESP32 Wi-Fi Setup',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isConnected ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.wifi_off,
                  color: isConnected ? AppConstants.statusGreen : AppConstants.statusRed,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? 'ESP32 ONLINE • WI-FI' : 'NOT CONNECTED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                        ),
                      ),
                      Text(
                        isConnected ? 'Receiving real-time sensor stream from ${wifi.espIp}' : 'Enter ESP32 IP or connect to OnionGuard hotspot',
                        style: TextStyle(
                          fontSize: 11,
                          color: isConnected ? const Color(0xFF166534) : const Color(0xFF7F1D1D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // IP and Port inputs
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'ESP32 IP Address or Hostname',
                    hintText: '192.168.4.1 or onionguard.local',
                    prefixIcon: Icon(Icons.dns_outlined, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '80',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Connect / Disconnect Buttons
          if (isConnected) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Disconnect Wi-Fi Link'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.statusRed,
                side: const BorderSide(color: AppConstants.statusRed),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _handleDisconnect,
            ),
          ] else ...[
            ElevatedButton.icon(
              icon: _isConnecting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.wifi, size: 18),
              label: Text(_isConnecting ? 'Connecting...' : 'Connect to ESP32 Wi-Fi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryForest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isConnecting ? null : _handleConnect,
            ),
          ],

          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isConnected ? AppConstants.statusGreen : AppConstants.statusRed,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Connection Quick Guide Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.subtleBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to connect your phone/laptop to ESP32:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
                SizedBox(height: 6),
                Text('• Option A (Direct Hotspot - No Router Needed):\n'
                    '   Connect your phone Wi-Fi to "OnionGuard-WiFi" (Password: onionguard123). Keep IP as 192.168.4.1.\n\n'
                    '• Option B (Home / Storage Wi-Fi):\n'
                    '   If ESP32 is joined to your router, type its assigned local IP (e.g. 192.168.1.50 or onionguard.local).',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
