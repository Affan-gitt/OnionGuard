/**
 * OnionGuard ESP32-H2 DevKit 4 Pin Definitions
 * SoC: ESP32-H2 (32-bit RISC-V @ 96 MHz)
 * Note: ESP32-H2 has 19 programmable GPIOs (GPIO 0-5, 8-14, 25-27)
 */

#ifndef PIN_DEFINITIONS_H
#define PIN_DEFINITIONS_H

// Sensor Inputs
#define PIN_MQ3_ANALOG      1   // ADC1_CH1 (0 - 3.3V after resistive divider)
#define PIN_DHT11_DATA      2   // Digital 1-Wire Data bus with 10k pull-up
#define PIN_WATER_LEVEL     12  // Optional capacitive/resistive water sensor

// I2C Bus for LCD Display
#define PIN_I2C_SDA         4   // I2C SDA
#define PIN_I2C_SCL         5   // I2C SCL

// Actuator & Relay Outputs
#define PIN_RELAY_FAN       8   // Relay control for 12V exhaust fan (Active LOW)
#define PIN_ACTUATOR_HUM    9   // Demonstration actuator driver (Humidifier proxy)
#define PIN_STATUS_LED      10  // Onboard system heartbeat LED

// Actuator Active Logic Levels
#define RELAY_ACTIVE_LEVEL   LOW   // Standard opto-isolated relay modules are active LOW
#define RELAY_INACTIVE_LEVEL HIGH
#define HUM_ACTIVE_LEVEL     HIGH
#define HUM_INACTIVE_LEVEL   LOW

#endif // PIN_DEFINITIONS_H
