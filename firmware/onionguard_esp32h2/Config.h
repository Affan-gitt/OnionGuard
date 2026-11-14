/**
 * OnionGuard ESP32-H2 Configuration & Thresholds
 */

#ifndef CONFIG_H
#define CONFIG_H

// BLE GATT Service & Characteristic UUIDs
#define BLE_DEVICE_NAME             "OnionGuard-ESP32H2"
#define SERVICE_UUID                "0000A001-0000-1000-8000-00805F9B34FB"
#define CHAR_SENSOR_DATA_UUID       "0000A002-0000-1000-8000-00805F9B34FB"
#define CHAR_DEVICE_STATUS_UUID     "0000A003-0000-1000-8000-00805F9B34FB"
#define CHAR_ACTUATOR_COMMAND_UUID  "0000A004-0000-1000-8000-00805F9B34FB"
#define CHAR_CONFIG_UUID            "0000A005-0000-1000-8000-00805F9B34FB"
#define CHAR_EVENT_NOTIFY_UUID      "0000A006-0000-1000-8000-00805F9B34FB"

// Environmental Default Thresholds
#define DEFAULT_TRIGGER_TEMP        26.0f // Fan turns ON at or above 26.0°C
#define DEFAULT_RESET_TEMP          24.0f // Fan turns OFF at or below 24.0°C (Hysteresis = 2.0°C)
#define DEFAULT_MAX_HUMIDITY_SAFETY 75.0f // Humidifier safety interlock limit
#define DEFAULT_MQ3_BASELINE        850   // Ambient raw ADC baseline
#define DEFAULT_MQ3_TRIGGER_DELTA   25.0f // +25% above baseline triggers demonstration actuator

// Timing & Intervals (milliseconds)
#define SENSOR_READ_INTERVAL_MS     2000  // Acquire DHT11 & MQ-3 every 2 seconds
#define LCD_CYCLE_INTERVAL_MS       4000  // Rotate LCD screens every 4 seconds
#define BLE_NOTIFY_INTERVAL_MS      2000  // Stream BLE payload every 2 seconds
#define MIN_FAN_CYCLE_TIME_MS       15000 // Anti-chattering: minimum 15s before toggling relay again
#define MAX_CONSECUTIVE_ERRORS      3     // Enter failsafe mode after 3 consecutive sensor read failures

// I2C LCD Configuration
#define LCD_I2C_ADDRESS             0x27  // Change to 0x3F if your PCF8574 backpack is addressed 0x3F
#define LCD_COLUMNS                 16
#define LCD_ROWS                    2

#endif // CONFIG_H
