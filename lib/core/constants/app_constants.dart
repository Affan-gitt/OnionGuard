import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'OnionGuard';
  static const String appTagline = 'Smart Onion Storage & Environmental Management';
  static const String appVersion = '1.0.0 (Build 1)';

  // Colors based on specification
  static const Color primaryForest = Color(0xFF1B4332);
  static const Color primaryLight = Color(0xFF2D6A4F);
  static const Color accentSage = Color(0xFF52B788);
  static const Color bgIvory = Color(0xFFF8F9F5);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF1F3ED);
  static const Color subtleBorder = Color(0xFFE2E6DF);

  // Status Colors
  static const Color statusGreen = Color(0xFF2D6A4F); // Healthy / Normal
  static const Color statusAmber = Color(0xFFD97706); // Warning / Attention
  static const Color statusRed = Color(0xFFDC2626);   // Critical / Deterioration
  static const Color statusGrey = Color(0xFF94A3B8);  // Inactive / Empty
  static const Color statusBlue = Color(0xFF2563EB);  // Info / Connectivity

  // Default Environmental Thresholds
  static const double defaultTargetTemp = 20.0;
  static const double defaultTriggerTemp = 26.0;
  static const double defaultResetTemp = 24.0;
  static const double defaultTargetHumidity = 65.0;
  static const double defaultMaxHumiditySafety = 75.0;
  static const int defaultMq3Baseline = 850;
  static const double defaultMq3TriggerDeltaPercent = 25.0;

  // BLE Configuration
  static const String bleDevicePrefix = 'OnionGuard';
  static const String bleServiceUuid = '0000A001-0000-1000-8000-00805F9B34FB';
  static const String bleSensorCharUuid = '0000A002-0000-1000-8000-00805F9B34FB';
  static const String bleStatusCharUuid = '0000A003-0000-1000-8000-00805F9B34FB';
  static const String bleCommandCharUuid = '0000A004-0000-1000-8000-00805F9B34FB';
  static const String bleConfigCharUuid = '0000A005-0000-1000-8000-00805F9B34FB';
  static const String bleEventCharUuid = '0000A006-0000-1000-8000-00805F9B34FB';

  // Developer Simulation PIN
  static const String defaultDeveloperPin = '1234';

  // Seed Varieties
  static const List<String> onionVarieties = [
    'Yellow Granex',
    'Red Creole',
    'White Sweet Spanish',
    'Texas Early Grano',
    'Red Pinoy',
  ];
}
