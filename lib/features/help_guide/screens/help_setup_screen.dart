import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/custom_app_bar.dart';

class HelpSetupScreen extends StatefulWidget {
  const HelpSetupScreen({super.key});

  @override
  State<HelpSetupScreen> createState() => _HelpSetupScreenState();
}

class _HelpSetupScreenState extends State<HelpSetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Help & Setup Guide',
        showBack: true,
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppConstants.primaryForest,
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: AppConstants.primaryForest,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Wiring Diagram'),
                  Tab(text: 'Hardware Pinout'),
                  Tab(text: 'Inventory & BOM'),
                  Tab(text: 'Firmware & Safety'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWiringTab(),
                  _buildPinoutTab(),
                  _buildBomTab(),
                  _buildFirmwareSafetyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWiringTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'System Architecture & Circuit Schematic',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
          ),
          const SizedBox(height: 6),
          const Text(
            'Complete hardware schematic interconnecting ESP32-H2 DevKit 4 with sensors and actuators.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Interactive ASCII & Flow Diagram Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                '                  +---------------------------+\n'
                '                  |     ESP32-H2 DevKit 4     |\n'
                '                  |    (RISC-V 96MHz / BLE)   |\n'
                '                  +---------------------------+\n'
                '                   |     |      |       |    |\n'
                '      GPIO 4 (SDA) |     |      |       |    | GPIO 5 (SCL)\n'
                '      +------------+     |      |       |    +-------------+\n'
                '      |                  |      |       |                  |\n'
                '      |   GPIO 2         |      |       | GPIO 1           |\n'
                '      |   (DHT11 Data)   |      |       | (MQ-3 Analog)    |\n'
                '      |   +--------------+      |       +-------------+    |\n'
                '      |   |                     |                     |    |\n'
                '      |   |        GPIO 8       |        GPIO 9       |    |\n'
                '      |   |      (Relay In)     |      (Humidifier)   |    |\n'
                '      |   |      +--------------+      +--------------+    |\n'
                '      |   |      |                                         |\n'
                '      v   v      v                                         v\n'
                '   +-------+   +-------+   +-------------------+       +-------+\n'
                '   | DHT11 |   | RELAY |-->| 12V EXHAUST FAN   |       | I2C   |\n'
                '   | Temp/ |   | 1-CH  |   | (External 12V PSU)|       | LCD   |\n'
                '   | Humid |   +-------+   +-------------------+       | 1602  |\n'
                '   +-------+                                           +-------+\n'
                '       ^               +-------------------+\n'
                '       |               | MQ-3 Gas Sensor   | (5V Powered,\n'
                '       +---------------+ (Voltage Divider  |  3.3V ADC Safe)\n'
                '                       |  to ESP32 ADC)    |\n'
                '                       +-------------------+',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF38BDF8)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildCircuitCard(
            title: '1. DHT11 Sensor Connection',
            color: Colors.blue,
            details: '• VCC -> ESP32 3.3V (or 5V)\n'
                     '• DATA -> GPIO 2 (with 10kΩ pull-up resistor to 3.3V)\n'
                     '• GND -> Common GND',
          ),
          const SizedBox(height: 10),

          _buildCircuitCard(
            title: '2. MQ-3 Alcohol Sensor Connection',
            color: Colors.purple,
            details: '• VCC -> External 5V (heater needs 5V)\n'
                     '• GND -> Common GND\n'
                     '• AOUT -> Voltage Divider (10kΩ / 20kΩ) -> GPIO 1 (ADC1_CH1)\n'
                     '  * CRITICAL: ESP32-H2 ADC input range is 0 to 3.3V. Do not connect 5V directly to ADC pin!',
          ),
          const SizedBox(height: 10),

          _buildCircuitCard(
            title: '3. Exhaust Fan Relay Circuit',
            color: AppConstants.statusGreen,
            details: '• Relay VCC -> 5V\n'
                     '• Relay GND -> Common GND\n'
                     '• Relay IN -> GPIO 8 (Active LOW opto-isolated)\n'
                     '• COM -> 12V External Power Supply (+)\n'
                     '• NO (Normally Open) -> Exhaust Fan (+)\n'
                     '• Exhaust Fan (-) -> 12V PSU (-)',
          ),
          const SizedBox(height: 10),

          _buildCircuitCard(
            title: '4. I2C LCD Display (1602/2004)',
            color: Colors.orange,
            details: '• VCC -> 5V\n'
                     '• GND -> Common GND\n'
                     '• SDA -> GPIO 4\n'
                     '• SCL -> GPIO 5\n'
                     '• Default I2C address: 0x27 or 0x3F',
          ),
        ],
      ),
    );
  }

  Widget _buildCircuitCard({required String title, required Color color, required String details}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(details, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildPinoutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ESP32-H2 DevKit 4 GPIO Pinout Table',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
          ),
          const SizedBox(height: 6),
          const Text(
            'ESP32-H2 is a 96MHz 32-bit RISC-V SoC with native Bluetooth 5 (LE) and IEEE 802.15.4 (Zigbee/Thread).',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          Table(
            border: TableBorder.all(color: AppConstants.subtleBorder, borderRadius: BorderRadius.circular(8)),
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.8),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(2.5),
            },
            children: [
              _buildTableHeader(['GPIO', 'Assigned Function', 'Signal Type', 'Notes']),
              _buildTableRow(['GPIO 1', 'MQ-3 Analog Out', 'ADC1_CH1', 'Protected with divider']),
              _buildTableRow(['GPIO 2', 'DHT11 Data Bus', 'Digital I/O', '10kΩ pull-up to 3.3V']),
              _buildTableRow(['GPIO 4', 'I2C SDA', 'Digital I2C', 'LCD 1602 Display']),
              _buildTableRow(['GPIO 5', 'I2C SCL', 'Digital I2C', 'LCD 1602 Display']),
              _buildTableRow(['GPIO 8', 'Exhaust Fan Relay', 'Digital Out', 'Active LOW driver']),
              _buildTableRow(['GPIO 9', 'Humidifier Driver', 'Digital Out / PWM', 'MOSFET / Relay 2']),
              _buildTableRow(['GPIO 10', 'Status LED', 'Digital Out', 'On-board heartbeat']),
              _buildTableRow(['GPIO 12', 'Water Level Sensor', 'Digital In / ADC', 'Optional safety']),
              _buildTableRow(['3V3', 'Sensors VCC', 'Power (3.3V)', 'ESP32 on-board LDO']),
              _buildTableRow(['5V / VIN', 'Heater / Relay', 'Power (5.0V)', 'From USB or ext 5V']),
              _buildTableRow(['GND', 'Common Ground', 'Ground', 'Common to all modules']),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader(List<String> cells) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
      children: cells.map((c) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B))),
      )).toList(),
    );
  }

  TableRow _buildTableRow(List<String> cells) {
    return TableRow(
      children: cells.map((c) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(c, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
      )).toList(),
    );
  }

  Widget _buildBomTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bill of Materials & Procurement Inventory',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
          ),
          const SizedBox(height: 12),

          // Available components
          const Text('A. Confirmed Available Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.statusGreen)),
          const SizedBox(height: 8),
          _buildInventoryItem('ESP32-H2 DevKit 4', '1', 'Main RISC-V Controller with Bluetooth LE 5.0'),
          _buildInventoryItem('Exhaust Fan (12V DC)', '1', 'Storage ventilation actuator'),
          _buildInventoryItem('DHT11 Sensor', '1', 'Temperature & Relative Humidity monitoring'),
          _buildInventoryItem('MQ-3 Alcohol Sensor', '1', 'Volatile organic / alcohol-vapour proxy'),
          _buildInventoryItem('Humidifier Module (5V)', '1', 'Demonstration gas-response actuator'),
          _buildInventoryItem('Single-Channel Relay Module', '1', 'Exhaust fan switching'),
          _buildInventoryItem('Solderless Breadboards', '2', 'Prototyping & bus distribution'),
          _buildInventoryItem('Jumper Wires (M-M, M-F, F-F)', '80', 'Interconnection cables'),
          const SizedBox(height: 18),

          // Missing / Additional Procurement
          const Text('B. Additional Required Procurement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.statusRed)),
          const SizedBox(height: 8),
          _buildProcurementItem('I2C LCD 1602 or 2004 Module', '1', 'Local physical display dashboard for temperature, humidity, and gas status.'),
          _buildProcurementItem('Second Relay / MOSFET Driver Module', '1', 'Required because available 1-channel relay cannot independently switch both the fan and humidifier.'),
          _buildProcurementItem('12V 2A DC Power Supply', '1', 'Dedicated power for the 12V exhaust fan (cannot be powered from ESP32 pins).'),
          _buildProcurementItem('Resistors (10kΩ & 20kΩ)', '4', 'Pull-up resistor for DHT11 and voltage divider for MQ-3 ADC protection.'),
          _buildProcurementItem('Flyback Diodes (1N4007)', '2', 'Back-EMF inductive spike suppression across fan motor and relay coil.'),
        ],
      ),
    );
  }

  Widget _buildInventoryItem(String name, String qty, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.subtleBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppConstants.statusGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Qty: $qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppConstants.statusGreen)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcurementItem(String name, String qty, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.statusRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppConstants.statusRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Qty: $qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppConstants.statusRed)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF991B1B))),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirmwareSafetyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Firmware Flashing & Safety Protocol',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryForest),
          ),
          const SizedBox(height: 12),

          _buildStepCard(
            step: '1',
            title: 'Arduino IDE / ESP-IDF Setup',
            body: '1. In Arduino IDE Preferences, add ESP32 board URL:\n'
                  '   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json\n'
                  '2. In Boards Manager, install "esp32 by Espressif Systems" (v3.0.0+ for ESP32-H2 support).\n'
                  '3. Select Board: "ESP32H2 Dev Module".',
          ),
          const SizedBox(height: 10),

          _buildStepCard(
            step: '2',
            title: 'Install Required Libraries',
            body: '• DHT sensor library by Adafruit\n'
                  '• Adafruit Unified Sensor\n'
                  '• LiquidCrystal_I2C by Frank de Brabander\n'
                  '• ArduinoJson by Benoît Blanchon',
          ),
          const SizedBox(height: 10),

          _buildStepCard(
            step: '3',
            title: 'Flashing via USB-C',
            body: '1. Connect ESP32-H2 DevKit to PC using USB-C cable.\n'
                  '2. Select the recognized COM Port.\n'
                  '3. Set Flash Frequency to 64MHz, Upload Speed to 921600.\n'
                  '4. Click Upload. The firmware source is in `firmware/onionguard_esp32h2/`.',
          ),
          const SizedBox(height: 10),

          _buildStepCard(
            step: '4',
            title: 'Electrical Safety Precautions',
            body: '• Ground isolation: Keep 12V fan power ground tied to ESP32 ground for common reference.\n'
                  '• Do NOT power the exhaust fan from the ESP32 board 3.3V or 5V rail; it will damage the regulator.\n'
                  '• MQ-3 requires a 24-48 hour pre-heat burn-in cycle upon initial unpacking to stabilize baseline.',
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({required String step, required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppConstants.primaryForest,
                child: Text(step, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.4)),
        ],
      ),
    );
  }
}
