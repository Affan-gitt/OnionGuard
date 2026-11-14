# OnionGuard — Smart Onion Storage, Monitoring & Environmental Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.4-0175C2?logo=dart)](https://dart.dev)
[![ESP32-H2](https://img.shields.io/badge/Hardware-ESP32--H2%20DevKit%204-E7352C?logo=espressif)](https://www.espressif.com)
[![Platform](https://img.shields.io/badge/Platform-Android%2014%2B%20(API%2023--36)-3DDC84?logo=android)](https://www.android.com)
[![License](https://img.shields.io/badge/Build-v1.0.0--release-1B4332)](https://github.com)

**OnionGuard** is an end-to-end IoT and mobile engineering solution designed to mitigate post-harvest onion spoilage in storage rooms. Combining an **ESP32-H2 DevKit 4** microcontroller over Bluetooth Low Energy (BLE) and an **Android application (Flutter/Dart)**, OnionGuard monitors critical microclimate conditions, controls automated ventilation, demonstrates volatile gas response triggers, tracks physical shelf inventory, and computes empirical spoilage risk indices.

---

## 📱 Deliverable: Android Release APK

The pre-compiled, debug-signed release APK is ready for direct installation on physical Android devices:

- **File Path:** [`OnionGuard-v1.0.0-release.apk`](file:///C:/Users/Lenovo/Downloads/Onion%20Guard/OnionGuard-v1.0.0-release.apk)
- **Size:** 51.8 MB (54,305,652 bytes)
- **Minimum SDK:** Android 6.0 (API 23)
- **Target SDK:** Android 14+ (API 34/35/36)
- **Install command:**
  ```powershell
  adb install -r "OnionGuard-v1.0.0-release.apk"
  ```

---

## 🏛️ Application Architecture & Design Language

OnionGuard faithfully implements the visual identity and module structure of the reference specifications:
- **Primary Color:** Deep Forest Green (`#1B4332` / `#2D6A4F`)
- **Backgrounds:** Warm Ivory / Off-White (`#F8F9F5`) and Light Surface (`#F0F2EB`)
- **Cards & Badges:** Clean White cards (`#FFFFFF`) with subtle borders (`#E5E7EB`) and restrained elevation.
- **State Management:** Riverpod 3 with compile-safe `Notifier<T>` and `NotifierProvider`.

### 6 Primary Modules (Home Hub)
1. **Live Room Sensors:** Multi-range charts (5m, 30m, 1h, 24h, 7d), Min/Avg/Max statistics, DHT11 temperature & humidity, MQ-3 raw ADC & baseline. When disconnected in Live Mode, an honest unavailable/offline state is shown.
2. **Fan, Cooling & Gas Response:** Automatic and manual exhaust fan control with configurable temperature hysteresis (trigger vs. reset thresholds). Demonstration humidifier actuator control with an **automatic humidity safety interlock** (strictly locks OFF when RH $\ge 75\%$).
3. **Gas Sensor Test:** A guided 9-step laboratory test procedure with live curve plotting, real-time peak measurement, duration tracking, baseline delta calculation, and CSV test session export.
4. **Onion Storage Shelves:** Visual 2-rack storage matrix (Rack A & Rack B, 16 physical positions). Displays onion varieties, weights, condition badges, quarantine statuses, inspection logs, and CSV inventory export.
5. **Activity History:** Categorized system audit log (Environmental, Actuator, Gas Test, Inventory, Security) with severity badges (`INFO`, `WARNING`, `CRITICAL`), text filtering, and CSV export.
6. **Help & Setup Guide:** Complete on-device wiring schematics, ESP32-H2 pinout table, Bill of Materials (BOM), safe testing protocol, and firmware flashing instructions.

### Supplementary Features
- **Storage Hygiene Checklist:** 10-point daily sanitation audit with compliance scoring and audit history.
- **Mathematical Spoilage Modelling:** Transparent composite risk estimation ($W_t, W_h, W_g, W_v$) with real-time risk index ($0.0 - 1.0$), component deviation meters, and empirical spoilage progression simulation.
- **SMS Alerting Gateway:** Configurable notification service with Fast2SMS/local gateway integration and automatic alert deduplication.

---

## 🧪 Demonstration & Simulation Mode (Developer PIN)

To allow demonstration of all hardware features, alerts, actuators, and graphs without requiring live physical hardware:

1. On the **Home Dashboard**, tap the **OnionGuard shield logo 5 times within 3 seconds**.
2. When prompted, enter Developer PIN: `1234`.
3. Choose from **7 realistic pre-configured scenarios**:
   - `Normal Baseline` (21.5°C, 65.0% RH, MQ-3 ADC 320)
   - `High Temperature Spike` (31.2°C → triggers exhaust fan)
   - `High Humidity Risk` (81.0% RH → triggers safety interlock)
   - `Alcohol / Spoilage Vapour Detection` (MQ-3 ADC 820 → triggers gas actuator)
   - `Combined Critical Failure` (32.5°C, 82% RH, ADC 890)
   - `Dynamic Fluctuation Cycle` (Sine-wave oscillation across thresholds)
   - `Sensor Disconnect Fault` (Demonstrates honest offline error state)
4. Use the manual interactive sliders for real-time sensor injection or adjust the simulation clock from **1x up to 10x speed**.
5. All 12 pre-seeded demonstration onions are clearly marked `[DEMO DATA]`.

---

## ⚡ ESP32-H2 DevKit 4 Hardware & Firmware

The complete C++ Arduino firmware is located in [`firmware/onionguard_esp32h2/`](file:///C:/Users/Lenovo/Downloads/Onion%20Guard/firmware/onionguard_esp32h2/):

| File | Purpose |
|---|---|
| [`onionguard_esp32h2.ino`](file:///C:/Users/Lenovo/Downloads/Onion%20Guard/firmware/onionguard_esp32h2/onionguard_esp32h2.ino) | Main event loop, DHT11 sampling, MQ-3 EMA filter, hysteresis logic, interlocks |
| [`PinDefinitions.h`](file:///C:/Users/Lenovo/Downloads/Onion%20Guard/firmware/onionguard_esp32h2/PinDefinitions.h) | Exact GPIO assignments for ESP32-H2 DevKit 4 |
| [`Config.h`](file:///C:/Users/Lenovo/Downloads/Onion%20Guard/firmware/onionguard_esp32h2/Config.h) | BLE GATT UUIDs, default thresholds, timings |
| [`LcdDisplay.h`](file:///C:/Users/Lenovo/Downloads/Onion%20Guard/firmware/onionguard_esp32h2/LcdDisplay.h) | 16x2 I2C LCD screen rotation with graceful non-blocking fallback |
| [`BleServerManager.h`](file:///C:/Users/Lenovo/Downloads/Onion%20Guard/firmware/onionguard_esp32h2/BleServerManager.h) | BLE GATT Server, telemetry notifications, command receiver |

### Pin Assignments
- **GPIO 1 (ADC1_CH1):** MQ-3 Alcohol Sensor Analog Output (via $10\text{ k}\Omega/20\text{ k}\Omega$ voltage divider)
- **GPIO 2:** DHT11 Temperature & Humidity Sensor (with $10\text{ k}\Omega$ pull-up resistor to 3.3V)
- **GPIO 4 (SDA):** I2C LCD Display (SDA)
- **GPIO 5 (SCL):** I2C LCD Display (SCL)
- **GPIO 8:** Relay IN (Exhaust Fan control)
- **GPIO 9:** MOSFET Gate / Relay 2 (Demonstration Humidifier actuator)
- **GPIO 10:** System Status LED

---

## 🔬 Scientific & Engineering Disclaimers

1. **MQ-3 Gas Sensor vs. Ethylene ($C_2H_4$):**
   - The MQ-3 sensor has a tin dioxide ($SnO_2$) sensing layer calibrated primarily for **alcohol vapours ($C_2H_5OH$)**.
   - In OnionGuard, the MQ-3 serves as a **qualitative proxy** for volatile fermentation and anaerobic soft-rot breakdown products.
   - It is **not** an ethylene sensor. For commercial storage facilities, an electrochemical or NDIR ethylene gas sensor (e.g., $0-10\text{ ppm}$) is specified for future hardware upgrades.
2. **Humidifier vs. Ethylene Filtration:**
   - The ultrasonic humidifier module is strictly a **benchtop proof-of-concept actuator** to demonstrate automated gas-triggered responses.
   - A humidifier **does not remove ethylene**. The production design specifies an activated alumina bed impregnated with potassium permanganate ($KMnO_4$).
3. **Humidity Safety Interlock:**
   - Excessive humidity ($>75\%$) accelerates neck rot (*Botrytis allii*) and premature rooting.
   - The firmware and application enforce a hard safety interlock: if relative humidity reaches or exceeds $75\%$, the humidifier actuator is **forced OFF and locked**, overriding any manual or gas-trigger commands.
4. **Safe Testing Instructions:**
   - **Never** expose the MQ-3 sensor to open flames, butane lighters, or uncontrolled alcohol pours.
   - Perform testing using a sterile cotton swab lightly dampened with isopropyl alcohol ($70\%$) held $5-10\text{ cm}$ away from the sensor mesh.

---

## 📁 Repository Directory Structure

```
Onion Guard/
├── OnionGuard-v1.0.0-release.apk     # Pre-built release APK (Deliverable)
├── android/                          # Android native project files & Gradle configuration
├── firmware/
│   └── onionguard_esp32h2/           # ESP32-H2 C++ Arduino source files
│       ├── onionguard_esp32h2.ino
│       ├── PinDefinitions.h
│       ├── Config.h
│       ├── LcdDisplay.h
│       └── BleServerManager.h
├── docs/                             # Engineering documentation
│   ├── WIRING_AND_PINOUT.md          # Schematics, pinout, level shifting, power isolation
│   ├── BILL_OF_MATERIALS.md         # Component inventory, procurement, and costs
│   ├── BLE_GATT_SPECIFICATION.md     # UUIDs, telemetry packets, control opcodes
│   ├── MATHEMATICAL_MODELLING.md     # Spoilage risk index & progression formulas
│   ├── SIMULATION_AND_TESTING_GUIDE.md# 7 demonstration scenarios & lab procedures
│   └── SMS_AND_NOTIFICATIONS_GUIDE.md# Fast2SMS gateway setup & notification triggers
├── lib/
│   ├── main.dart                     # App entry point
│   ├── app/                          # App root, Theme, Riverpod providers
│   ├── core/                         # Constants, Services (BLE, Storage, Simulation, SMS)
│   ├── data/                         # Models (OnionItem, SensorReading, Actuator, Event)
│   ├── features/                     # Feature screens (Dashboard, Sensors, Fan, Gas, Shelves, etc.)
│   └── shared/                       # Reusable UI widgets (MetricCard, StatusBadge, etc.)
├── test/
│   └── widget_test.dart              # Automated widget & logic unit tests
├── pubspec.yaml                      # Flutter dependencies
└── README.md                         # This specification & operational guide
```

---

## 🛠️ Build & Development Commands

### Run Unit and Widget Tests
```powershell
& "D:\flutter\bin\flutter.bat" test
```

### Run Static Analysis
```powershell
& "D:\flutter\bin\flutter.bat" analyze
```

### Build Android APK
```powershell
& "D:\flutter\bin\flutter.bat" build apk --release
```
