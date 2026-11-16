import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'OnionGuard';
  static const String appTagline = 'Smart Agricultural IoT Environmental Control';
  static const String appVersion = '2.0.0 (Pro IoT)';

  // Futuristic Agricultural IoT Palette
  static const Color darkBg = Color(0xFF06100C);           // Near-black #06100C
  static const Color deepForest = Color(0xFF071D13);       // Deep forest green #071D13
  static const Color darkCard = Color(0xFF0C251A);         // Layered dark card
  static const Color darkCardSurface = Color(0xFF113224);  // Elevated card surface
  static const Color darkCardLight = Color(0xFF163E2D);    // Highlighted card surface
  static const Color emerald = Color(0xFF00D68F);          // Luminous Emerald #00D68F
  static const Color lime = Color(0xFFB6F36B);             // Vibrant Lime #B6F36B
  static const Color warmGold = Color(0xFFD6A64B);         // Warm Gold #D6A64B
  static const Color cream = Color(0xFFF3F0DF);            // Cream #F3F0DF
  static const Color mutedGreenGrey = Color(0xFF8B9E94);   // Muted Green-Grey #8B9E94
  static const Color borderEmerald = Color(0x3300D68F);    // Glowing Emerald Border
  static const Color borderSubtle = Color(0x1F00D68F);     // Subtle Border
  static const Color glowEmerald = Color(0x4D00D68F);      // Emerald Glow
  static const Color statusCritical = Color(0xFFFF4D4D);   // Critical Red Alert

  // Legacy mappings for backward compatibility
  static const Color primaryForest = deepForest;
  static const Color primaryLight = emerald;
  static const Color accentSage = lime;
  static const Color bgIvory = darkBg;
  static const Color cardWhite = darkCard;
  static const Color lightGrey = darkCardSurface;
  static const Color subtleBorder = borderEmerald;

  // Status Colors
  static const Color statusGreen = emerald;
  static const Color statusAmber = warmGold;
  static const Color statusRed = statusCritical;
  static const Color statusGrey = mutedGreenGrey;
  static const Color statusBlue = Color(0xFF38BDF8);

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
