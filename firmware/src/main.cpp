#include <Arduino.h>
#include <WiFi.h>
#include <esp_task_wdt.h>
#include <map>
#include <vector>
#include "config.h"
#include "firestore_client.h"

// System State for 4-Channel Relays
static std::map<String, bool> currentRelayStates = {
  {"switch_1", false},
  {"switch_2", false},
  {"switch_3", false},
  {"switch_4", false}
};

static unsigned long lastPollTime = 0;
static unsigned long lastHeartbeatTime = 0;
static unsigned long lastWifiCheckTime = 0;
static FirestoreClient firestoreClient;

// Pin mapping helper
int getPinForSwitch(const String& switchId) {
  if (switchId == "switch_1") return RELAY_PIN_1;
  if (switchId == "switch_2") return RELAY_PIN_2;
  if (switchId == "switch_3") return RELAY_PIN_3;
  if (switchId == "switch_4") return RELAY_PIN_4;
  return -1;
}

// ==========================================
// Heartbeat & Telemetry Sender
// ==========================================
void sendHeartbeatTelemetry(bool force = false) {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  const unsigned long now = millis();
  if (!force && (now - lastHeartbeatTime < HEARTBEAT_INTERVAL_MS)) {
    return;
  }
  lastHeartbeatTime = now;

  const bool success = firestoreClient.sendHeartbeat(
    FIREBASE_PROJECT_ID,
    FIREBASE_API_KEY,
    DEVICE_ID,
    currentRelayStates
  );

  if (success) {
    Serial.printf("[HEARTBEAT] Telemetry sent -> Device: %s, Relays: [S1:%d, S2:%d, S3:%d, S4:%d]\n",
                  DEVICE_ID,
                  currentRelayStates["switch_1"],
                  currentRelayStates["switch_2"],
                  currentRelayStates["switch_3"],
                  currentRelayStates["switch_4"]);
  } else {
    Serial.printf("[HEARTBEAT] Telemetry write failed for device %s\n", DEVICE_ID);
  }
}

// ==========================================
// GPIO & Relay Control Driver (4 Channels)
// ==========================================
void setRelayState(const String& switchId, bool newState, const char* switchName = "Switch") {
  const int pin = getPinForSwitch(switchId);
  if (pin < 0) return;

  // Idempotency: Do not actuate if state has not changed
  if (currentRelayStates[switchId] == newState) {
    return;
  }

  currentRelayStates[switchId] = newState;
  const uint8_t pinLevel = (newState == (RELAY_ACTIVE_LEVEL == HIGH)) ? HIGH : LOW;
  digitalWrite(pin, pinLevel);

  // Status LED indicates if any switch is ON
  bool anyOn = false;
  for (const auto& kv : currentRelayStates) {
    if (kv.second) anyOn = true;
  }
  digitalWrite(STATUS_LED_PIN, anyOn ? HIGH : LOW);

  Serial.println("------------------------------------------");
  Serial.printf ("[RELAY ACTION] Switch: \"%s\" (%s)\n", switchName, switchId.c_str());
  Serial.printf ("[RELAY ACTION] Target State: %s\n", newState ? "ON" : "OFF");
  Serial.printf ("[RELAY ACTION] GPIO %d Output: %s\n", pin, pinLevel == HIGH ? "HIGH" : "LOW");
  Serial.println("------------------------------------------");

  // Send immediate state confirmation heartbeat to Firestore
  sendHeartbeatTelemetry(true);
}

void initHardware() {
  pinMode(RELAY_PIN_1, OUTPUT);
  pinMode(RELAY_PIN_2, OUTPUT);
  pinMode(RELAY_PIN_3, OUTPUT);
  pinMode(RELAY_PIN_4, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);

  // Safe Default: Ensure all 4 relays are strictly OFF on boot
  const uint8_t safeOffLevel = (RELAY_ACTIVE_LEVEL == HIGH) ? LOW : HIGH;
  digitalWrite(RELAY_PIN_1, safeOffLevel);
  digitalWrite(RELAY_PIN_2, safeOffLevel);
  digitalWrite(RELAY_PIN_3, safeOffLevel);
  digitalWrite(RELAY_PIN_4, safeOffLevel);
  digitalWrite(STATUS_LED_PIN, LOW);

  Serial.println("[HARDWARE] 4-Channel GPIOs initialized. Safe default: All relays OFF.");
}

// ==========================================
// Network Manager & SNTP Time Synchronization
// ==========================================
void maintainWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  const unsigned long now = millis();
  if (now - lastWifiCheckTime < 5000) {
    return; // Non-blocking retry backoff
  }
  lastWifiCheckTime = now;

  Serial.printf("[WIFI] Attempting connection to: %s ...\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

void onWiFiConnected() {
  static bool wasConnected = false;
  if (WiFi.status() == WL_CONNECTED && !wasConnected) {
    wasConnected = true;
    Serial.println("==========================================");
    Serial.printf ("[WIFI] Connected successfully!\n");
    Serial.printf ("[WIFI] IP Address  : %s\n", WiFi.localIP().toString().c_str());
    Serial.printf ("[WIFI] Signal (RSSI): %d dBm\n", WiFi.RSSI());
    Serial.printf ("[DEVICE] Device ID  : %s\n", DEVICE_ID);
    Serial.printf ("[CONFIG] Project ID : %s\n", FIREBASE_PROJECT_ID);
    Serial.println("==========================================");

    // Initialize SNTP Real-Time Clock
    Serial.println("[SNTP] Synchronizing UTC time via pool.ntp.org...");
    configTime(0, 0, "pool.ntp.org", "time.google.com");

    // Initial heartbeat on connect
    sendHeartbeatTelemetry(true);
  } else if (WiFi.status() != WL_CONNECTED) {
    wasConnected = false;
  }
}

// ==========================================
// Firestore Multi-Switch Polling Routine
// ==========================================
void pollFirestore() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  std::vector<SwitchState> switches;
  const bool success = firestoreClient.fetchAllSwitchesForDevice(
    FIREBASE_PROJECT_ID,
    FIREBASE_API_KEY,
    DEVICE_ID,
    switches
  );

  if (success) {
    for (const auto& sw : switches) {
      setRelayState(sw.switchId, sw.isOn, sw.name.c_str());
    }
  }
}

// ==========================================
// Arduino Entrypoints
// ==========================================
void setup() {
  Serial.begin(SERIAL_BAUD_RATE);
  delay(1000);

  Serial.println("\n\n==========================================");
  Serial.println(" ESP32 IoT Smart Switch - Production Firmware");
  Serial.printf (" Device ID       : %s\n", DEVICE_ID);
  Serial.printf (" Relays Pins     : GPIO %d, %d, %d, %d\n",
                 RELAY_PIN_1, RELAY_PIN_2, RELAY_PIN_3, RELAY_PIN_4);
  Serial.printf (" Active Level    : %s\n", RELAY_ACTIVE_LEVEL == HIGH ? "Active-HIGH" : "Active-LOW");
  Serial.printf (" Poll Frequency  : %d ms\n", FIRESTORE_POLL_INTERVAL_MS);
  Serial.printf (" Heartbeat Period: %d ms\n", HEARTBEAT_INTERVAL_MS);
  Serial.println("==========================================");

  initHardware();

  // Initialize Task Watchdog Timer
  esp_task_wdt_init(WATCHDOG_TIMEOUT_SEC, true);
  esp_task_wdt_add(NULL);

  maintainWiFi();
}

void loop() {
  esp_task_wdt_reset(); // Feed watchdog

  maintainWiFi();
  onWiFiConnected();

  const unsigned long now = millis();

  // Non-blocking Firestore switch polling
  if (now - lastPollTime >= FIRESTORE_POLL_INTERVAL_MS) {
    lastPollTime = now;
    pollFirestore();
  }

  // Periodic heartbeat telemetry
  if (now - lastHeartbeatTime >= HEARTBEAT_INTERVAL_MS) {
    sendHeartbeatTelemetry(false);
  }

  delay(10); // Yield to FreeRTOS scheduler
}
