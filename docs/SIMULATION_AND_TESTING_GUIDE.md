# ONIONGUARD — SIMULATION & DEMONSTRATION TESTING GUIDE

## 1. Accessing Hidden Developer Simulation Mode

To demonstrate the full functionality of the OnionGuard Android application without physical hardware:

1. Launch the **OnionGuard** application.
2. Locate the **OnionGuard logo** (the green leaf/onion emblem) in the top-left corner of the app bar.
3. **Tap the logo 5 times within 3 seconds.**
4. A secure PIN prompt will appear.
5. Enter the default Developer PIN: **`1234`**
6. Toggle the **"SIMULATION MODE ACTIVE"** switch.
7. An amber **`SIMULATION`** badge will immediately appear in the app bar.

---

## 2. The 7 Demonstration Scenarios

| Scenario | Objective | Simulated Behavior |
|---|---|---|
| **A. Normal Storage** | Demonstrates stable preservation | Temp: 21.4°C, Humidity: 63.5%, MQ-3: 850 ADC. Exhaust fan remains idle. |
| **B. Temperature Spike** | Demonstrates automated exhaust fan | Temp steadily climbs past 26.0°C. When crossing threshold, simulated exhaust fan switches ON, status changes to RUNNING, and an alert is logged. |
| **C. Gas Response** | Demonstrates gas detection trigger | MQ-3 proxy reading spikes +45% above baseline. Triggers demonstration actuator with a live response curve. |
| **D. High Humidity** | Demonstrates safety interlock | Relative humidity climbs past 75.0%. The safety interlock forces the humidifier OFF to prevent rot and mould. |
| **E. Extended Storage** | Demonstrates mathematical risk model | Simulates multi-day environmental stress accumulation, updating the composite risk score and spoilage progression model. |
| **F. Sensor Failure** | Demonstrates failsafe shutdown | Simulates disconnected sensor hardware. System displays "DISCONNECTED", shuts off actuators, and logs a critical hardware alert. |
| **G. Recovery** | Demonstrates hysteresis reset | Exhaust fan actively cools the room below 24.0°C. Actuators safely return to standby without chattering. |

---

## 3. Manual Environmental Sliders

When Simulation Mode is unlocked, you can also use three real-time sliders:
- **Temperature Slider (14.0°C – 36.0°C):** Drag above 26.0°C to watch the fan turn on; drag below 24.0°C to watch it shut off.
- **Humidity Slider (35.0% – 90.0%):** Drag above 75.0% to test the safety interlock.
- **Gas ADC Slider (500 – 2500 ADC):** Drag above 1100 to trigger the demonstration gas response actuator.
- **Simulation Speed (1x – 10x):** Speed up scenario execution for rapid presentation demonstrations.

---

## 4. Separation of Simulated and Live Data
- All simulated telemetry points are tagged with `isSimulated: true`.
- Simulation Mode **never** transmits physical actuator actuation commands over BLE.
- In Live Mode (when Simulation is OFF), the application will **never** synthesize fake sensor readings; it will display an offline state if the ESP32-H2 is not connected.
