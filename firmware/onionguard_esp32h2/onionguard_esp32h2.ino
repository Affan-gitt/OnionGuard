/**
 * ============================================================================
 * ONIONGUARD - ESP32-H2 DevKit 4 FIRMWARE (HARDWARE-FIRST USB CDC + BLE)
 * Smart Onion Storage, Monitoring and Environmental Management System
 * ============================================================================
 * Microcontroller: ESP32-H2-WROOM-1 (32-bit RISC-V @ 96MHz)
 * Primary Interface: USB-C CDC-ACM Serial (115200 Baud, Newline-Delimited JSON)
 * Secondary Interface: Bluetooth Low Energy 5.0 (BLE) GATT Architecture
 * Sensors: DHT11 (Temp/Humidity), MQ-3 (Alcohol Vapour Decomposition Proxy)
 * Actuators: 12V Exhaust Fan (Relay 1), Demonstration Actuator (GPIO 9)
 * Display: I2C LCD 1602 (PCF8574 Backpack @ 0x27)
 * ============================================================================
 */

#include <Arduino.h>
#include <DHT.h>
#include <ArduinoJson.h>

#include "PinDefinitions.h"
#include "Config.h"
#include "LcdDisplay.h"
#include "BleServerManager.h"

#define FIRMWARE_VERSION "1.2.0"
#define DEVICE_ID        "ONIONGUARD_ESP32H2"

// Hardware instances
DHT dht(PIN_DHT11_DATA, DHT11);
LcdDisplay lcd;

// System Telemetry Variables
float currentTemperature = 0.0f;
float currentHumidity = 0.0f;
int mq3RawAdc = 0;
float mq3SmoothedAdc = 0.0f;
int mq3BaselineAdc = DEFAULT_MQ3_BASELINE;
float mq3DeltaPercent = 0.0f;

// Operational Modes & Actuators
bool fanState = false;
String fanMode = "AUTO"; // "AUTO" or "MANUAL"
unsigned long fanLastToggledTime = 0;

bool humidifierState = false;
String humidifierMode = "AUTO"; // "AUTO" or "MANUAL"
bool safetyInterlockActive = false;

// Configurable Thresholds
float triggerTemp = DEFAULT_TRIGGER_TEMP;
float resetTemp = DEFAULT_RESET_TEMP;
float maxHumiditySafety = DEFAULT_MAX_HUMIDITY_SAFETY;
float mq3TriggerDelta = DEFAULT_MQ3_TRIGGER_DELTA;

// Telemetry Timers & Error Tracking
unsigned long lastSensorReadTime = 0;
unsigned long lastHeartbeatTime = 0;
unsigned long lastUsbRxTime = 0;
unsigned long packetSequence = 0;
int consecutiveErrorCount = 0;
bool sensorFault = false;
bool hasValidReading = false;

// Forward declaration of command handler
void processIncomingJsonCommand(const String& jsonStr, const char* sourceInterface);

class SystemCommandHandler : public CommandHandler {
public:
  void onCommandReceived(const String& cmd) override {
    processIncomingJsonCommand(cmd, "BLE");
  }
};

SystemCommandHandler cmdHandler;
BleServerManager bleManager(&cmdHandler);

void setup() {
  // Initialize USB CDC-ACM Serial (ESP32-H2 native USB)
  Serial.begin(115200);
  delay(1200);

  // Initialize GPIO Pins
  pinMode(PIN_RELAY_FAN, OUTPUT);
  digitalWrite(PIN_RELAY_FAN, RELAY_INACTIVE_LEVEL);

  pinMode(PIN_ACTUATOR_HUM, OUTPUT);
  digitalWrite(PIN_ACTUATOR_HUM, HUM_INACTIVE_LEVEL);

  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);

  // Configure ADC for MQ-3 (12-bit, 0 - 3.3V attenuation)
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  // Initialize DHT11
  dht.begin();

  // Initialize LCD Display
  lcd.begin();

  // Initialize BLE GATT Server
  bleManager.begin();

  // Initial Sensor Warm-up baseline read
  calibrateMq3Baseline();

  // Announce system ready over USB serial
  #if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument bootDoc;
  #else
  StaticJsonDocument<256> bootDoc;
  #endif
  bootDoc["type"] = "boot";
  bootDoc["device_id"] = DEVICE_ID;
  bootDoc["fw"] = FIRMWARE_VERSION;
  bootDoc["status"] = "READY";
  bootDoc["protocol"] = "NDJSON";
  bootDoc["baud"] = 115200;

  String bootMsg;
  serializeJson(bootDoc, bootMsg);
  Serial.println(bootMsg);
}

void loop() {
  unsigned long now = millis();

  // 1. Process incoming USB CDC serial commands (Newline-Delimited JSON)
  while (Serial.available() > 0) {
    String inputLine = Serial.readStringUntil('\n');
    inputLine.trim();
    if (inputLine.length() > 0) {
      lastUsbRxTime = now;
      processIncomingJsonCommand(inputLine, "USB");
    }
  }

  // 2. Periodic Sensor Telemetry Acquisition (every 2s)
  if (now - lastSensorReadTime >= SENSOR_READ_INTERVAL_MS) {
    lastSensorReadTime = now;
    readPhysicalSensors();
    evaluateActuationLogic();
    updateLcdDisplay();
    broadcastTelemetry();
    toggleHeartbeatLed();
  }

  // 3. Periodic Heartbeat (every 5s)
  if (now - lastHeartbeatTime >= 5000) {
    lastHeartbeatTime = now;
    sendHeartbeat();
  }
}

/**
 * Reads real physical sensors: DHT11 and MQ-3 Analog ADC
 */
void readPhysicalSensors() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();

  if (isnan(h) || isnan(t) || h <= 0.0f || t <= 0.0f) {
    consecutiveErrorCount++;
    if (consecutiveErrorCount >= MAX_CONSECUTIVE_ERRORS) {
      sensorFault = true;
      hasValidReading = false;
      executeFailsafeShutdown();
    }
    return;
  }

  // Valid reading received from physical sensor
  consecutiveErrorCount = 0;
  sensorFault = false;
  hasValidReading = true;
  currentTemperature = t;
  currentHumidity = h;

  // Read MQ-3 Analog ADC (12-bit: 0 - 4095)
  long adcSum = 0;
  for (int i = 0; i < 5; i++) {
    adcSum += analogRead(PIN_MQ3_ANALOG);
    delay(2);
  }
  mq3RawAdc = adcSum / 5;

  // Exponential Moving Average (EMA) filter: alpha = 0.2
  mq3SmoothedAdc = (0.2f * (float)mq3RawAdc) + (0.8f * mq3SmoothedAdc);

  if (mq3BaselineAdc > 0) {
    mq3DeltaPercent = (((float)mq3RawAdc - (float)mq3BaselineAdc) / (float)mq3BaselineAdc) * 100.0f;
  } else {
    mq3DeltaPercent = 0.0f;
  }
}

/**
 * Automated Control Logic with Hysteresis & Safety Interlocks
 */
void evaluateActuationLogic() {
  if (sensorFault || !hasValidReading) return;

  unsigned long now = millis();

  // 1. Exhaust Fan Temperature Automation with 2°C Hysteresis
  if (fanMode == "AUTO") {
    if (now - fanLastToggledTime >= MIN_FAN_CYCLE_TIME_MS) {
      if (!fanState && currentTemperature >= triggerTemp) {
        setFanPhysicalState(true, "AUTO_TEMP_TRIGGER");
      } else if (fanState && currentTemperature <= resetTemp) {
        setFanPhysicalState(false, "AUTO_TEMP_RESET");
      }
    }
  }

  // 2. Humidifier Demonstration Actuator & Safety Interlock
  // Safety Interlock: If humidity exceeds max limit (75%), force OFF immediately!
  if (currentHumidity >= maxHumiditySafety) {
    if (humidifierState) {
      setHumidifierPhysicalState(false, "SAFETY_INTERLOCK_EXCEEDED");
    }
    safetyInterlockActive = true;
  } else {
    safetyInterlockActive = false;

    // Automatic Gas Response
    if (humidifierMode == "AUTO") {
      if (mq3DeltaPercent >= mq3TriggerDelta) {
        if (!humidifierState) {
          setHumidifierPhysicalState(true, "AUTO_GAS_TRIGGER");
        }
      } else {
        if (humidifierState) {
          setHumidifierPhysicalState(false, "AUTO_GAS_RESET");
        }
      }
    }
  }
}

void setFanPhysicalState(bool state, const char* reason) {
  fanState = state;
  fanLastToggledTime = millis();
  digitalWrite(PIN_RELAY_FAN, fanState ? RELAY_ACTIVE_LEVEL : RELAY_INACTIVE_LEVEL);
}

void setHumidifierPhysicalState(bool state, const char* reason) {
  humidifierState = state;
  digitalWrite(PIN_ACTUATOR_HUM, humidifierState ? HUM_ACTIVE_LEVEL : HUM_INACTIVE_LEVEL);
}

void executeFailsafeShutdown() {
  setFanPhysicalState(false, "FAILSAFE_SHUTDOWN");
  setHumidifierPhysicalState(false, "FAILSAFE_SHUTDOWN");
  lcd.displayError("HARDWARE FAULT", "Actuators OFF");
}

void calibrateMq3Baseline() {
  long sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(PIN_MQ3_ANALOG);
    delay(50);
  }
  mq3BaselineAdc = sum / 10;
  mq3SmoothedAdc = (float)mq3BaselineAdc;
}

void updateLcdDisplay() {
  bool usbActive = (millis() - lastUsbRxTime < 10000) && (lastUsbRxTime > 0);
  lcd.update(
    currentTemperature,
    currentHumidity,
    mq3RawAdc,
    fanState,
    humidifierState,
    bleManager.isConnected(),
    sensorFault,
    usbActive
  );
}

/**
 * Constructs structured newline-delimited JSON packet and broadcasts to USB and BLE
 */
void broadcastTelemetry() {
  packetSequence++;

  #if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument doc;
  #else
  StaticJsonDocument<384> doc;
  #endif

  doc["type"] = "sensor";
  doc["dev"] = DEVICE_ID;
  doc["fw"] = FIRMWARE_VERSION;
  doc["seq"] = packetSequence;
  doc["uptime"] = millis() / 1000;

  if (hasValidReading && !sensorFault) {
    doc["temperature"] = serialized(String(currentTemperature, 1));
    doc["humidity"] = serialized(String(currentHumidity, 1));
    doc["mq3_raw"] = mq3RawAdc;
    doc["mq3_delta"] = serialized(String(mq3DeltaPercent, 1));
    doc["sensor_status"] = safetyInterlockActive ? "INTERLOCK" : "OK";
  } else {
    doc["temperature"] = nullptr;
    doc["humidity"] = nullptr;
    doc["mq3_raw"] = nullptr;
    doc["mq3_delta"] = nullptr;
    doc["sensor_status"] = "WAITING FOR SENSOR DATA";
  }

  doc["fan"] = fanState;
  doc["humidifier"] = humidifierState;
  doc["fan_mode"] = fanMode;
  doc["humidifier_mode"] = humidifierMode;
  doc["safety_lock"] = safetyInterlockActive;

  String payload;
  serializeJson(doc, payload);

  // 1. Send via USB CDC-ACM Serial (Newline delimited)
  Serial.println(payload);

  // 2. Notify BLE Central
  bleManager.notifySensorData(payload);
}

void sendHeartbeat() {
  packetSequence++;

  #if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument doc;
  #else
  StaticJsonDocument<256> doc;
  #endif

  doc["type"] = "heartbeat";
  doc["dev"] = DEVICE_ID;
  doc["fw"] = FIRMWARE_VERSION;
  doc["seq"] = packetSequence;
  doc["uptime"] = millis() / 1000;
  doc["status"] = sensorFault ? "SENSOR_FAULT" : "OK";
  doc["fan"] = fanState;
  doc["humidifier"] = humidifierState;

  String payload;
  serializeJson(doc, payload);
  Serial.println(payload);
}

void toggleHeartbeatLed() {
  static bool ledState = false;
  ledState = !ledState;
  digitalWrite(PIN_STATUS_LED, ledState ? HIGH : LOW);
}

/**
 * Parses and executes structured JSON commands from Android USB or BLE
 * Protocol:
 * {"type":"command","device":"fan","state":true,"seq":42}
 * {"type":"command","device":"humidifier","state":false,"seq":43}
 * {"type":"command","action":"calibrate_baseline","seq":44}
 * {"type":"command","action":"set_thresholds","trigger_temp":26.0,"reset_temp":24.0,"max_humidity":75.0}
 */
void processIncomingJsonCommand(const String& jsonStr, const char* sourceInterface) {
  #if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument cmdDoc;
  #else
  StaticJsonDocument<384> cmdDoc;
  #endif

  DeserializationError err = deserializeJson(cmdDoc, jsonStr);
  if (err) {
    // Send NACK response
    Serial.println("{\"type\":\"error\",\"message\":\"INVALID_JSON\"}");
    return;
  }

  long cmdSeq = cmdDoc["seq"] | 0;
  const char* type = cmdDoc["type"] | "";

  #if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument ackDoc;
  #else
  StaticJsonDocument<256> ackDoc;
  #endif
  ackDoc["type"] = "ack";
  ackDoc["seq"] = cmdSeq;
  ackDoc["source"] = sourceInterface;

  if (strcmp(type, "command") == 0) {
    if (cmdDoc.containsKey("device")) {
      const char* device = cmdDoc["device"] | "";
      bool reqState = cmdDoc["state"] | false;

      if (strcmp(device, "fan") == 0) {
        fanMode = "MANUAL";
        setFanPhysicalState(reqState, "MANUAL_COMMAND");
        
        ackDoc["device"] = "fan";
        ackDoc["state"] = reqState;
        ackDoc["actual_state"] = fanState;
        ackDoc["success"] = (fanState == reqState);
      } else if (strcmp(device, "humidifier") == 0) {
        if (reqState && (currentHumidity >= maxHumiditySafety || safetyInterlockActive)) {
          // Safety interlock rejection
          ackDoc["device"] = "humidifier";
          ackDoc["state"] = false;
          ackDoc["actual_state"] = false;
          ackDoc["success"] = false;
          ackDoc["error"] = "HUMIDITY_SAFETY_LIMIT_EXCEEDED";
        } else {
          humidifierMode = "MANUAL";
          setHumidifierPhysicalState(reqState, "MANUAL_COMMAND");

          ackDoc["device"] = "humidifier";
          ackDoc["state"] = reqState;
          ackDoc["actual_state"] = humidifierState;
          ackDoc["success"] = (humidifierState == reqState);
        }
      } else {
        ackDoc["success"] = false;
        ackDoc["error"] = "UNKNOWN_DEVICE";
      }
    } else if (cmdDoc.containsKey("action")) {
      const char* action = cmdDoc["action"] | "";
      if (strcmp(action, "calibrate_baseline") == 0) {
        calibrateMq3Baseline();
        ackDoc["action"] = "calibrate_baseline";
        ackDoc["success"] = true;
        ackDoc["baseline"] = mq3BaselineAdc;
      } else if (strcmp(action, "auto_mode") == 0) {
        fanMode = "AUTO";
        humidifierMode = "AUTO";
        ackDoc["action"] = "auto_mode";
        ackDoc["success"] = true;
      } else if (strcmp(action, "ping") == 0) {
        ackDoc["action"] = "ping";
        ackDoc["success"] = true;
        ackDoc["uptime"] = millis() / 1000;
      } else {
        ackDoc["success"] = false;
        ackDoc["error"] = "UNKNOWN_ACTION";
      }
    }
  } else {
    ackDoc["success"] = false;
    ackDoc["error"] = "UNRECOGNIZED_PACKET_TYPE";
  }

  String ackResponse;
  serializeJson(ackDoc, ackResponse);
  Serial.println(ackResponse);

  if (bleManager.isConnected()) {
    bleManager.notifyEvent(ackResponse);
  }
}
