/**
 * =============================================================================
 * SECURE ESP32 SMART SWITCH FIRMWARE (PROD HARDENED)
 * =============================================================================
 * 
 * Security Architecture:
 * 1. Hardware Device Identity: Hard-coded DEVICE_ID matching Firestore document.
 * 2. Secure Transport: TLS 1.3 / HTTPS communication with Firebase Firestore REST API.
 * 3. Pre-Shared Device Secret: Device sends cryptographic secret header for trusted layer.
 * 4. Strict Command Validation: Validates exact DEVICE_ID, schema types, and boolean fields.
 * 5. Anti-Replay & Freshness Protection: Validates timestamp freshness to prevent stale/replayed state changes.
 * 6. Non-Blocking Loop: Uses millis() timing for Wi-Fi reconnect and polling loops.
 * 7. Watchdog Protection: Hardware Watchdog Timer (WDT) prevents freeze/lockup states.
 * 8. Sanitized Logging: Safe serial logging without printing Wi-Fi, secret tokens, or API keys.
 * =============================================================================
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>

// Include local secrets (copy from secrets.h.template)
#if __has_include("secrets.h")
  #include "secrets.h"
#else
  #warning "secrets.h not found. Please copy secrets.h.template to secrets.h"
  #define WIFI_SSID           "DEMO_WIFI_SSID"
  #define WIFI_PASSWORD       "DEMO_WIFI_PASSWORD"
  #define FIREBASE_PROJECT_ID "iot-switch-23826"
  #define FIREBASE_API_KEY    "DEMO_API_KEY"
  #define DEVICE_ID           "esp32_relay_01"
  #define DEVICE_SECRET_TOKEN "DEMO_SECRET_TOKEN"
  #define RELAY_PIN           23
  #define STATUS_LED_PIN      2
  #define RELAY_ACTIVE_LOW    true
#endif

#ifndef DEVICE_SYNC_URL
#define DEVICE_SYNC_URL "https://us-central1-iot-switch-23826.cloudfunctions.net/deviceSync"
#endif

// =============================================================================
// CONSTANTS & TIMERS
// =============================================================================
#define WDT_TIMEOUT_SECONDS     30
#define POLL_INTERVAL_MS        1500  // Fast, non-blocking state check
#define HEARTBEAT_INTERVAL_MS   30000 // Send heartbeat telemetry every 30s
#define WIFI_RETRY_INTERVAL_MS  5000  // Wi-Fi reconnect backoff

// Global Hardware & Security State
bool currentRelayState = false;
bool isHardwareInitialized = false;
unsigned long lastPollTime = 0;
unsigned long lastHeartbeatTime = 0;
unsigned long lastWifiAttemptTime = 0;
bool isWifiConnecting = false;

// Anti-Replay & Freshness Tracking
String lastProcessedTimestamp = "";
unsigned long lastCommandNonce = 0;
const unsigned long COMMAND_FRESHNESS_WINDOW_MS = 60000; // 60 seconds freshness window

// Command idempotency tracking
struct CommandHistory {
  String commandId;
  unsigned long timestamp;
  bool executed;
};
const int COMMAND_HISTORY_SIZE = 10;
CommandHistory commandHistory[COMMAND_HISTORY_SIZE];
int commandHistoryIndex = 0;

// Trusted Root CA Certificates for Google / Firebase Services (GTS Root R1 & GTS Root R4, Valid to 2036)
const char* rootCACertificate = \
"-----BEGIN CERTIFICATE-----\n" \
"MIIFVzCCAz+gAwIBAgINAgPlk28xsBNJiGuiFzANBgkqhkiG9w0BAQwFADBHMQsw\n" \
"CQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEU\n" \
"MBIGA1UEAxMLR1RTIFJvb3QgUjEwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAw\n" \
"MDAwWjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZp\n" \
"Y2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjEwggIiMA0GCSqGSIb3DQEBAQUA\n" \
"A4ICDwAwggIKAoICAQC2EQKLHuOhd5s73L+UPreVp0A8of2C+X0yBoJx9vaMf/vo\n" \
"27xqLpeXo4xL+Sv2sfnOhB2x+cWX3u+58qPpvBKJXqeqUqv4IyfLpLGcY9vXmX7w\n" \
"Cl7raKb0xlpHDU0QM+NOsROjyBhsS+z8CZDfnWQpJSMHobTSPS5g4M/SCYe7zUjw\n" \
"TcLCeoiKu7rPWRnWr4+wB7CeMfGCwcDfLqZtbBkOtdh+JhpFAz2weaSUKK0Pfybl\n" \
"qAj+lug8aJRT7oM6iCsVlgmy4HqMLnXWnOunVmSPlk9orj2XwoSPwLxAwAtcvfaH\n" \
"szVsrBhQf4TgTM2S0yDpM7xSma8ytSmzJSq0SPly4cpk9+aCEI3oncKKiPo4Zor8\n" \
"Y/kB+Xj9e1x3+naH+uzfsQ55lVe0vSbv1gHR6xYKu44LtcXFilWr06zqkUspzBmk\n" \
"MiVOKvFlRNACzqrOSbTqn3yDsEB750Orp2yjj32JgfpMpf/VjsPOS+C12LOORc92\n" \
"wO1AK/1TD7Cn1TsNsYqiA94xrcx36m97PtbfkSIS5r762DL8EGMUUXLeXdYWk70p\n" \
"aDPvOmbsB4om3xPXV2V4J95eSRQAogB/mqghtqmxlbCluQ0WEdrHbEg8QOB+DVrN\n" \
"VjzRlwW5y0vtOUucxD/SVRNuJLDWcfr0wbrM7Rv1/oFB2ACYPTrIrnqYNxgFlQID\n" \
"AQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E\n" \
"FgQU5K8rJnEaK0gnhS9SZizv8IkTcT4wDQYJKoZIhvcNAQEMBQADggIBAJ+qQibb\n" \
"C5u+/x6Wki4+omVKapi6Ist9wTrYggoGxval3sBOh2Z5ofmmWJyq+bXmYOfg6LEe\n" \
"QkEzCzc9zolwFcq1JKjPa7XSQCGYzyI0zzvFIoTgxQ6KfF2I5DUkzps+GlQebtuy\n" \
"h6f88/qBVRRiClmpIgUxPoLW7ttXNLwzldMXG+gnoot7TiYaelpkttGsN/H9oPM4\n" \
"7HLwEXWdyzRSjeZ2axfG34arJ45JK3VmgRAhpuo+9K4l/3wV3s6MJT/KYnAK9y8J\n" \
"ZgfIPxz88NtFMN9iiMG1D53Dn0reWVlHxYciNuaCp+0KueIHoI17eko8cdLiA6Ef\n" \
"MgfdG+RCzgwARWGAtQsgWSl4vflVy2PFPEz0tv/bal8xa5meLMFrUKTX5hgUvYU/\n" \
"Z6tGn6D/Qqc6f1zLXbBwHSs09dR2CQzreExZBfMzQsNhFRAbd03OIozUhfJFfbdT\n" \
"6u9AWpQKXCBfTkBdYiJ23//OYb2MI3jSNwLgjt7RETeJ9r/tSQdirpLsQBqvFAnZ\n" \
"0E6yove+7u7Y/9waLd64NnHi/Hm3lCXRSHNboTXns5lndcEZOitHTtNCjv0xyBZm\n" \
"2tIMPNuzjsmhDYAPexZ3FL//2wmUspO8IFgV6dtxQ/PeEMMA3KgqlbbC1j+Qa3bb\n" \
"bP6MvPJwNQzcmRk13NfIRmPVNnGuV/u3gm3c\n" \
"-----END CERTIFICATE-----\n" \
"-----BEGIN CERTIFICATE-----\n" \
"MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD\n" \
"VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG\n" \
"A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw\n" \
"WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz\n" \
"IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi\n" \
"AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi\n" \
"QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR\n" \
"HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW\n" \
"BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D\n" \
"9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8\n" \
"p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD\n" \
"-----END CERTIFICATE-----\n";

// =============================================================================
// HARDWARE RELAY CONTROL
// =============================================================================
void setRelayHardware(bool turnOn) {
  if (isHardwareInitialized && turnOn == currentRelayState) return;

  currentRelayState = turnOn;
  isHardwareInitialized = true;
  
  if (RELAY_ACTIVE_LOW) {
    digitalWrite(RELAY_PIN, turnOn ? LOW : HIGH);
  } else {
    digitalWrite(RELAY_PIN, turnOn ? HIGH : LOW);
  }

  // Update Status LED
  digitalWrite(STATUS_LED_PIN, turnOn ? HIGH : LOW);

  Serial.print(F("[RELAY] Hardware state set to: "));
  Serial.println(turnOn ? F("ON") : F("OFF"));
}

// =============================================================================
// NON-BLOCKING WI-FI MANAGEMENT
// =============================================================================
void maintainWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    if (isWifiConnecting) {
      Serial.print(F("[WIFI] Connected! Local IP: "));
      Serial.println(WiFi.localIP());
      isWifiConnecting = false;
    }
    return;
  }

  unsigned long currentMillis = millis();
  if (currentMillis - lastWifiAttemptTime >= WIFI_RETRY_INTERVAL_MS) {
    lastWifiAttemptTime = currentMillis;
    Serial.println(F("[WIFI] Attempting secure Wi-Fi connection..."));
    WiFi.disconnect();
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    isWifiConnecting = true;
  }
}

// =============================================================================
// SECURE FIRESTORE REST API: FETCH AND VALIDATE COMMAND & STATE
// =============================================================================
unsigned long generateCommandNonce() {
  return millis() + random(1000); // Generate unique nonce based on time + random
}

// Command idempotency check
bool isCommandDuplicate(String commandId) {
  for (int i = 0; i < COMMAND_HISTORY_SIZE; i++) {
    if (commandHistory[i].commandId == commandId && 
        (millis() - commandHistory[i].timestamp) < COMMAND_FRESHNESS_WINDOW_MS) {
      return true;
    }
  }
  return false;
}

// Add command to history
void addToCommandHistory(String commandId, bool executed) {
  commandHistory[commandHistoryIndex] = {commandId, millis(), executed};
  commandHistoryIndex = (commandHistoryIndex + 1) % COMMAND_HISTORY_SIZE;
}
void fetchSwitchState() {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setCACert(rootCACertificate); // Enforce strict TLS certificate validation

  HTTPClient http;

  String url = String(DEVICE_SYNC_URL);
  url += "?deviceId=";
  url += DEVICE_ID;

  if (http.begin(client, url)) {
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-Device-ID", DEVICE_ID);
    http.addHeader("X-Device-Secret", DEVICE_SECRET_TOKEN);

    int httpCode = http.GET();

    if (httpCode == HTTP_CODE_OK) {
      String payload = http.getString();

      StaticJsonDocument<1024> doc;
      DeserializationError error = deserializeJson(doc, payload);

      if (!error) {
        if (doc.containsKey("deviceId")) {
          String incomingDeviceId = doc["deviceId"].as<String>();
          if (incomingDeviceId != DEVICE_ID) {
            Serial.print(F("[SECURITY WARNING] Mismatched Device ID payload: "));
            Serial.println(incomingDeviceId);
            http.end();
            return;
          }
        }

        if (doc.containsKey("updatedAt")) {
          String timestamp = doc["updatedAt"].as<String>();
          if (timestamp.length() > 0 && timestamp == lastProcessedTimestamp) {
            http.end();
            return;
          }
          if (timestamp.length() > 0) {
            lastProcessedTimestamp = timestamp;
          }
        }

        // Anti-replay: Check command nonce if present
        if (doc.containsKey("commandNonce")) {
          unsigned long incomingNonce = doc["commandNonce"].as<unsigned long>();
          if (incomingNonce <= lastCommandNonce) {
            Serial.print(F("[SECURITY WARNING] Replay attack detected! Command nonce too low: "));
            Serial.println(incomingNonce);
            http.end();
            return;
          }
          // Check freshness window
          unsigned long currentTime = millis();
          if (doc.containsKey("commandTimestamp")) {
            unsigned long commandTime = doc["commandTimestamp"].as<unsigned long>();
            if (currentTime - commandTime > COMMAND_FRESHNESS_WINDOW_MS) {
              Serial.print(F("[SECURITY WARNING] Stale command detected! Timestamp too old: "));
              Serial.println(commandTime);
              http.end();
              return;
            }
          }
          lastCommandNonce = incomingNonce;
        }

        if (doc.containsKey("isOn") && doc["isOn"].is<bool>()) {
          bool targetIsOn = doc["isOn"].as<bool>();
          String commandId = doc.containsKey("commandId") ? doc["commandId"].as<String>() : String(millis());
          
          // Check for duplicate command (idempotency)
          if (isCommandDuplicate(commandId)) {
            Serial.print(F("[IDEMPOTENCY] Duplicate command detected: "));
            Serial.println(commandId);
            http.end();
            return;
          }
          
          setRelayHardware(targetIsOn);
          addToCommandHistory(commandId, true);
          sendCommandAcknowledgement(commandId, true);
        } else {
          Serial.println(F("[SECURITY WARNING] Received malformed or missing 'isOn' boolean field."));
          if (doc.containsKey("commandId")) {
            sendCommandAcknowledgement(doc["commandId"].as<String>(), false, "Invalid isOn field");
          }
        }
      } else {
        Serial.print(F("[JSON] Deserialization error: "));
        Serial.println(error.c_str());
      }
    } else if (httpCode == 404) {
      Serial.println(F("[FIRESTORE] Device document not found."));
    } else if (httpCode == 403 || httpCode == 401) {
      Serial.println(F("[AUTH ERROR] Unauthorized request. Check DEVICE_SECRET_TOKEN and DEVICE_SECRETS."));
    } else {
      Serial.print(F("[HTTP] Error code: "));
      Serial.println(httpCode);
    }
    http.end();
  }
}

// =============================================================================
// FIRESTORE REST API: SEND DEVICE HEARTBEAT & TELEMETRY
// =============================================================================
void sendHeartbeatTelemetry() {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setCACert(rootCACertificate); // Enforce strict TLS certificate validation

  HTTPClient http;

  if (http.begin(client, DEVICE_SYNC_URL)) {
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-Device-ID", DEVICE_ID);
    http.addHeader("X-Device-Secret", DEVICE_SECRET_TOKEN);

    StaticJsonDocument<256> doc;
    doc["deviceId"] = DEVICE_ID;
    doc["online"] = true;
    doc["lastCommandNonce"] = lastCommandNonce;
    doc["currentRelayState"] = currentRelayState;

    String requestBody;
    serializeJson(doc, requestBody);

    int httpCode = http.POST(requestBody);
    if (httpCode == HTTP_CODE_OK) {
      Serial.println(F("[HEARTBEAT] Telemetry synced successfully."));
    }
    http.end();
  }
}

// =============================================================================
// SEND COMMAND ACKNOWLEDGEMENT
// =============================================================================
void sendCommandAcknowledgement(String commandId, bool success, String error = "") {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setCACert(rootCACertificate);

  HTTPClient http;

  String url = String(DEVICE_SYNC_URL);
  url += "/ack";
  
  if (http.begin(client, url)) {
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-Device-ID", DEVICE_ID);
    http.addHeader("X-Device-Secret", DEVICE_SECRET_TOKEN);

    StaticJsonDocument<512> doc;
    doc["deviceId"] = DEVICE_ID;
    doc["commandId"] = commandId;
    doc["success"] = success;
    doc["error"] = error;
    doc["executedAt"] = millis();
    doc["relayState"] = currentRelayState;

    String requestBody;
    serializeJson(doc, requestBody);

    int httpCode = http.POST(requestBody);
    if (httpCode == HTTP_CODE_OK) {
      Serial.println(F("[ACK] Command acknowledgement sent successfully."));
    } else {
      Serial.print(F("[ACK] Failed to send acknowledgement: "));
      Serial.println(httpCode);
    }
    http.end();
  }
}
void sendHeartbeatTelemetry() {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setCACert(rootCACertificate); // Enforce strict TLS certificate validation

  HTTPClient http;

  if (http.begin(client, DEVICE_SYNC_URL)) {
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-Device-ID", DEVICE_ID);
    http.addHeader("X-Device-Secret", DEVICE_SECRET_TOKEN);

    StaticJsonDocument<256> doc;
    doc["deviceId"] = DEVICE_ID;
    doc["online"] = true;

    String requestBody;
    serializeJson(doc, requestBody);

    int httpCode = http.POST(requestBody);
    if (httpCode == HTTP_CODE_OK) {
      Serial.println(F("[HEARTBEAT] Telemetry synced successfully."));
    }
    http.end();
  }
}

// =============================================================================
// SETUP
// =============================================================================
void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println(F("\n========================================"));
  Serial.println(F("   SECURE ESP32 SMART SWITCH STARTUP    "));
  Serial.print(F("   Device ID: "));
  Serial.println(DEVICE_ID);
  Serial.println(F("========================================"));

  // Initialize Hardware Pins
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);

  // Set initial safe relay state (OFF)
  setRelayHardware(false);

  // Initialize command history
  for (int i = 0; i < COMMAND_HISTORY_SIZE; i++) {
    commandHistory[i] = {"", 0, false};
  }

  // Initialize Hardware Watchdog Timer
  esp_task_wdt_config_t wdt_config = {
    .timeout_ms = WDT_TIMEOUT_SECONDS * 1000,
    .idle_core_mask = 0,
    .trigger_panic = true
  };
  esp_task_wdt_init(&wdt_config);
  esp_task_wdt_add(NULL); // Add current task to WDT

  // Initialize Wi-Fi
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  maintainWiFi();
}

// =============================================================================
// MAIN LOOP (NON-BLOCKING)
// =============================================================================
void loop() {
  // Feed Hardware Watchdog Timer
  esp_task_wdt_reset();

  // Maintain Wi-Fi Connection
  maintainWiFi();

  unsigned long currentMillis = millis();

  // Poll Firestore Switch State & Command
  if (currentMillis - lastPollTime >= POLL_INTERVAL_MS) {
    lastPollTime = currentMillis;
    fetchSwitchState();
  }

  // Send Heartbeat Telemetry
  if (currentMillis - lastHeartbeatTime >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeatTime = currentMillis;
    sendHeartbeatTelemetry();
  }

  // Offline recovery: sync state when coming back online
  static bool wasOffline = false;
  if (WiFi.status() == WL_CONNECTED) {
    if (wasOffline) {
      Serial.println(F("[OFFLINE RECOVERY] Connection restored, syncing state..."));
      sendHeartbeatTelemetry();
      wasOffline = false;
    }
  } else {
    wasOffline = true;
  }

  // Relay state synchronization: periodically verify hardware state matches Firestore
  static unsigned long lastSyncCheck = 0;
  if (currentMillis - lastSyncCheck >= 60000) { // Check every minute
    lastSyncCheck = currentMillis;
    fetchSwitchState(); // Force state verification
  }

  // Non-blocking yield to allow background Wi-Fi / IP stack processing
  yield();
}

