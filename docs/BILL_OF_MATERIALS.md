# ONIONGUARD — BILL OF MATERIALS (BOM) & COMPONENT AUDIT

## 1. Confirmed Available Inventory

| Item # | Component Description | Quantity | Confirmed Role in OnionGuard System |
|---|---|---:|---|
| 1 | **ESP32-H2 DevKit 4** | 1 | Master RISC-V 32-bit controller, BLE GATT server & local control loop |
| 2 | **12V DC Exhaust Fan** | 1 | Storage rack ventilation and convective cooling actuator |
| 3 | **DHT11 Sensor Module** | 1 | Ambient air temperature and relative humidity sensing |
| 4 | **MQ-3 Gas Sensor Module** | 1 | Qualitative alcohol-vapour / volatile decay proxy sensor |
| 5 | **5V Humidifier Module** | 1 | Physical demonstration actuator for gas-response system |
| 6 | **1-Channel 5V Relay Module** | 1 | Opto-isolated power switching for the 12V exhaust fan |
| 7 | **Solderless Breadboards (830-pt)** | 2 | Power distribution rails and sensor circuit prototyping |
| 8 | **Jumper Wires (M-M, M-F, F-F)** | 80 | Signal and power interconnect cabling |

---

## 2. Additional Required Procurement List (Engineering Gap Analysis)

Before operating this prototype as a standalone hardware installation, the following missing parts must be procured:

| Item # | Component | Qty | Justification & Electrical Specification |
|---|---|---:|---|
| **REQ-1** | **I2C LCD 1602 (with PCF8574 Backpack)** | 1 | Provides local physical telemetry display (Storage Normal, High Temp, Gas Alert) when smartphone is disconnected. |
| **REQ-2** | **Secondary Relay Module or MOSFET Driver (IRFZ44N / 2N7000)** | 1 | **Critical Conflict:** The available inventory contains only a *single-channel* relay. Independent control of both the exhaust fan and humidifier module cannot be achieved with one relay. |
| **REQ-3** | **12V 2A DC External Power Supply** | 1 | Powers the 12V exhaust fan. The ESP32 3.3V/5V rails cannot deliver the 300–800mA inductive startup current required by the fan. |
| **REQ-4** | **Resistors: 10kΩ & 20kΩ (1/4W)** | 4 | 10kΩ pull-up for DHT11 data line; 10kΩ/20kΩ voltage divider to protect ESP32 ADC from MQ-3 5V analog output. |
| **REQ-5** | **1N4007 Rectifier Diode** | 2 | Flyback protection across the relay coil and exhaust fan DC motor to suppress destructive back-EMF inductive voltage spikes. |
| **REQ-6** | **Float Switch / Liquid Sensor** | 1 | Humidifier dry-run protection to prevent heater element burn-out. |

---

## 3. Cosmetic & Demonstration Component Disclosure
- **Solar Panels:** Any solar panels attached to the enclosure are purely decorative/cosmetic. They do NOT generate electrical energy or charge the battery/controller.
- **Decorative LEDs:** Cosmetic enclosure lighting is wired for visual demonstration purposes and must not be confused with functional status indicators.
