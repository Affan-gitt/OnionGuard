# ONIONGUARD — HARDWARE WIRING DIAGRAM & PINOUT SPECIFICATION

## 1. Controller Identity: ESP32-H2 DevKit 4
- **Processor:** 32-bit RISC-V Single-Core CPU @ 96 MHz (Espressif ESP32-H2-WROOM-1 module)
- **Radios:** Bluetooth Low Energy (BLE 5.0) and IEEE 802.15.4 (Thread/Zigbee).
- **Wi-Fi:** *None* (ESP32-H2 does NOT support native Wi-Fi). Android smartphone acts as the internet and cloud gateway.
- **Operating Voltage:** 3.3V logic (ADC range: 0.0V to 3.3V).

---

## 2. GPIO Pinout Table

| ESP32-H2 Pin | Signal / Device | Voltage | Signal Type | Electrical Requirement / Protection |
|---|---|---|---|---|
| **GPIO 1** | MQ-3 Gas Sensor (Analog Out) | 0–3.3V | ADC1_CH1 | Must use 10kΩ/20kΩ voltage divider from MQ-3 5V analog pin |
| **GPIO 2** | DHT11 Data Line | 3.3V | Digital 1-Wire | 10kΩ pull-up resistor to 3.3V rail |
| **GPIO 4** | I2C LCD SDA | 3.3V/5V | I2C Bus | Connected to PCF8574 backpack SDA |
| **GPIO 5** | I2C LCD SCL | 3.3V/5V | I2C Bus | Connected to PCF8574 backpack SCL |
| **GPIO 8** | 1-Channel Relay (Exhaust Fan) | 3.3V | Digital Output | Active LOW opto-isolated trigger |
| **GPIO 9** | Demonstration Actuator | 3.3V | Digital Output | Drives MOSFET gate / Relay 2 for humidifier |
| **GPIO 10** | System Status Heartbeat | 3.3V | Digital Output | Onboard diagnostic LED |
| **GPIO 12** | Water Level Float Sensor | 3.3V | Digital Input | Optional safety switch with internal pull-up |
| **3V3** | Sensors Power Rail | 3.3V DC | Power Out | ESP32 internal LDO (max 500mA) |
| **5V / VIN** | MQ-3 Heater & Relay Coil | 5.0V DC | Power In/Out | Sourced from external 5V 2A USB / PSU |
| **GND** | Common System Ground | 0V | Ground | Must tie all grounds (12V PSU, 5V PSU, ESP32) together |

---

## 3. Circuit Schematic Diagram (ASCII Architecture)

```
                 +-----------------------------------+
                 |         ESP32-H2 DevKit 4         |
                 |       32-bit RISC-V 96 MHz        |
                 +-----------------------------------+
                   |       |       |       |       |
     GPIO 4 (SDA)  |       |       |       |       | GPIO 5 (SCL)
     +-------------+       |       |       |       +-------------+
     |                     |       |       |                     |
     |      GPIO 2         |       |       | GPIO 1              |
     |   (DHT11 Data)      |       |       | (MQ-3 ADC)          |
     |   +-----------------+       |       +---------------+     |
     |   |                         |                       |     |
     |   |             GPIO 8      |        GPIO 9         |     |
     |   |           (Relay IN)    |      (Humidifier)     |     |
     |   |           +-------------+      +-----------+    |     |
     |   |           |                                |    |     |
     v   v           v                                v    v     v
  +-------+      +-------+                        +---------------+  +-------+
  | DHT11 |      | RELAY |                        | 5V HUMIDIFIER |  | I2C   |
  | Temp/ |      | 1-CH  |                        | DEMONSTRATION |  | LCD   |
  | Humid |      +-------+                        | ACTUATOR      |  | 1602  |
  +-------+          |                            +---------------+  +-------+
                     v
             +-------------------------+
             | 12V DC EXHAUST FAN      |
             | (Powered by 12V 2A PSU) |
             +-------------------------+
```

---

## 4. Critical Electrical Safety & Sensor Interfacing Guidelines

### A. MQ-3 Gas Sensor (5V to 3.3V ADC Protection)
- The MQ-3 internal tin dioxide ($SnO_2$) heating coil requires a strict **5.0V DC supply** consuming approximately 150mA.
- The analog output pin ($A_{OUT}$) can swing up to 5.0V under high vapour concentration.
- **DANGER:** Direct connection of 5V to ESP32-H2 GPIO 1 will destroy the internal ADC silicon!
- **Protection Circuit:** Implement a 2:1 resistive divider:
  $$V_{ADC} = V_{MQ3} \times \frac{R_2}{R_1 + R_2} = 5.0V \times \frac{20k\Omega}{10k\Omega + 20k\Omega} = 3.33V$$
  Place a 10kΩ resistor in series between MQ-3 $A_{OUT}$ and GPIO 1, and a 20kΩ resistor from GPIO 1 to GND.

### B. Inductive Load Suppression (Exhaust Fan)
- When the 12V exhaust fan motor switches off, the collapsing magnetic field creates a reverse voltage spike (back-EMF) exceeding 60V.
- Connect a **1N4007 flyback diode** across the fan terminals in reverse-bias (Cathode to +12V, Anode to GND) to clamp the inductive kick and protect the relay contacts from pitting.

### C. Common Grounding
- The 12V power supply ground, 5V regulator ground, and ESP32 DevKit ground MUST be connected together on the breadboard ground bus.
- Never connect the 12V positive rail to any pin on the ESP32!
