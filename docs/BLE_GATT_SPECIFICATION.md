# ONIONGUARD — BLE GATT SERVICE & COMMUNICATION SPECIFICATION

## 1. Network Topology & Gateway Architecture

Because the **ESP32-H2** SoC features native Bluetooth 5.0 (LE) and IEEE 802.15.4 but lacks Wi-Fi, the system uses a gateway architecture:

```
+-------------------+             +-----------------------+             +----------------------+
| ESP32-H2 DevKit 4 |  Bluetooth  | Android Smartphone    |  4G / Wi-Fi | Cloud Backend        |
| (GATT Server)     | ----------> | OnionGuard Gateway    | ----------> | (Supabase / Webhook) |
| Hardware Sensors  |    (BLE)    | Local Storage & UI    |  Internet   | Remote Analytics/SMS |
+-------------------+             +-----------------------+             +----------------------+
```

---

## 2. Custom GATT Service Architecture

- **Primary Service UUID:** `0000A001-0000-1000-8000-00805F9B34FB`
- **Device Advertised Name:** `OnionGuard-ESP32H2`

### Characteristic Definitions

| Characteristic Name | UUID | Permissions | Description & Properties |
|---|---|---|---|
| **Sensor Data** | `0000A002-0000-1000-8000-00805F9B34FB` | Read, Notify | Transmits live sensor telemetry stream every 2000ms. |
| **Device Status** | `0000A003-0000-1000-8000-00805F9B34FB` | Read, Notify | Device operational mode, firmware version, and uptime. |
| **Actuator Command** | `0000A004-0000-1000-8000-00805F9B34FB` | Write | Receives control commands from the Android app. |
| **System Config** | `0000A005-0000-1000-8000-00805F9B34FB` | Read, Write | Set/read operating thresholds (temp, humidity, baseline). |
| **Event Alert** | `0000A006-0000-1000-8000-00805F9B34FB` | Notify | Instant asynchronous notification when threshold crossed. |

---

## 3. Data Payloads

### A. Sensor Data Stream (JSON Format)
Notified every 2000 milliseconds to the Android application:

```json
{
  "device_id": "ONIONGUARD_001",
  "temperature": 23.4,
  "humidity": 64.2,
  "mq3_adc": 862,
  "mq3_delta": 1.4,
  "fan_state": false,
  "humidifier_state": false,
  "fan_mode": "AUTO",
  "sensor_status": "OK",
  "timestamp": 142850
}
```

### B. Command Protocol Reference (Characteristic `0000A004`)

| ASCII Command String | Parameters | Microcontroller Action |
|---|---|---|
| `FAN_ON` | None | Manually forces exhaust fan relay ON. Switches mode to MANUAL. |
| `FAN_OFF` | None | Manually forces exhaust fan relay OFF. Switches mode to MANUAL. |
| `AUTO_MODE` | None | Returns fan and humidifier to automated hysteresis control. |
| `HUMIDIFIER_ON` | None | Manually turns demonstration actuator ON (subject to humidity interlock). |
| `HUMIDIFIER_OFF` | None | Forces demonstration actuator OFF. |
| `CALIBRATE_BASELINE` | None | Samples 10 ambient air readings to reset MQ-3 baseline. |
| `SET_TEMP_THRESHOLD:26.5` | Float (°C) | Sets exhaust fan trigger temperature. Auto-calculates reset (Trigger - 2.0°C). |
| `SET_HUMIDITY_LIMIT:75.0` | Float (%) | Updates safety shutdown interlock limit. |

---

## 4. Android Bluetooth Permissions (API 31+ Compatible)

The application manifest incorporates Android 12+ (API 31+) and backward-compatible permissions:

- `android.permission.BLUETOOTH_SCAN` (`usesPermissionFlags="neverForLocation"`)
- `android.permission.BLUETOOTH_CONNECT`
- `android.permission.ACCESS_FINE_LOCATION` (Required on Android 6–11 for BLE scanning)
