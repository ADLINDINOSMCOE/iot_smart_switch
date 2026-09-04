#pragma once
#include <Arduino.h>

// Attempt to load private credentials; fallback to defaults if not yet created
#if __has_include("../include/secrets.h")
  #include "../include/secrets.h"
#else
  #define WIFI_SSID "YOUR_WIFI_SSID"
  #define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
  #define FIREBASE_PROJECT_ID "iot-smart-switch-demo"
  #define FIREBASE_API_KEY "YOUR_API_KEY"
#endif

// ==========================================
// Device Identity (Hard Constraint)
// Must match the deviceId field in Firestore
// ==========================================
#define DEVICE_ID "esp32_001"

// ==========================================
// Hardware Pin Mapping (4-Channel Relay Array)
// ==========================================
#define RELAY_PIN_1 23          // Switch 1 (Living Room Main Light)
#define RELAY_PIN_2 22          // Switch 2 (Ceiling Fan)
#define RELAY_PIN_3 21          // Switch 3 (Kitchen Overhead Lamp)
#define RELAY_PIN_4 19          // Switch 4 (Bedroom Nightstand Lamp)
#define STATUS_LED_PIN 2        // Built-in status indicator LED (GPIO 2)
#define RELAY_ACTIVE_LEVEL HIGH // HIGH = Active-High relay, LOW = Active-Low relay

// ==========================================
// Timing & Network Parameters
// ==========================================
#define SERIAL_BAUD_RATE 115200
#define WIFI_CONNECT_TIMEOUT_MS 15000
#define FIRESTORE_POLL_INTERVAL_MS 2000 // Polling interval in ms (2 seconds)
#define HEARTBEAT_INTERVAL_MS 10000     // Heartbeat telemetry interval (10 seconds)
#define RELAY_DEBOUNCE_MS 50            // Relay state transition debounce
#define WATCHDOG_TIMEOUT_SEC 15         // Task Watchdog Timer timeout in seconds
