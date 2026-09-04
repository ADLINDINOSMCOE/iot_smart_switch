#include "firestore_client.h"
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include "../include/google_root_ca.h"

FirestoreClient::FirestoreClient() {}

String FirestoreClient::getFormattedUtcTimestamp() {
  time_t now = time(nullptr);
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);

  char buf[30];
  // If time is valid (year > 2020), format real ISO-8601 UTC string
  if (timeinfo.tm_year > (2020 - 1900)) {
    strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
    return String(buf);
  }
  // Fallback if NTP sync is still in progress
  return String("2026-09-01T18:00:00Z");
}

String FirestoreClient::buildQueryPayload(const char* targetDeviceId) {
  // Construct Firestore structuredQuery JSON payload
  JsonDocument doc;
  JsonObject structuredQuery = doc["structuredQuery"].to<JsonObject>();

  JsonArray from = structuredQuery["from"].to<JsonArray>();
  JsonObject collection = from.add<JsonObject>();
  collection["collectionId"] = "switches";

  JsonObject where = structuredQuery["where"].to<JsonObject>();
  JsonObject fieldFilter = where["fieldFilter"].to<JsonObject>();

  JsonObject field = fieldFilter["field"].to<JsonObject>();
  field["fieldPath"] = "deviceId";

  fieldFilter["op"] = "EQUAL";

  JsonObject value = fieldFilter["value"].to<JsonObject>();
  value["stringValue"] = targetDeviceId;

  String output;
  serializeJson(doc, output);
  return output;
}

bool FirestoreClient::fetchAllSwitchesForDevice(
    const char* projectId,
    const char* apiKey,
    const char* targetDeviceId,
    std::vector<SwitchState>& outSwitches) {

  outSwitches.clear();

  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  WiFiClientSecure client;
  // Apply Google Trust Services Root R1 CA Certificate for TLS validation
  client.setCACert(GOOGLE_ROOT_CA);

  HTTPClient https;
  String url = "https://firestore.googleapis.com/v1/projects/";
  url += projectId;
  url += "/databases/(default)/documents:runQuery?key=";
  url += apiKey;

  if (!https.begin(client, url)) {
    Serial.println("[FIRESTORE] HTTPS connection failed to begin.");
    return false;
  }

  https.addHeader("Content-Type", "application/json");
  String requestPayload = buildQueryPayload(targetDeviceId);

  const int httpCode = https.POST(requestPayload);

  if (httpCode != HTTP_CODE_OK) {
    Serial.printf("[FIRESTORE] Query failed. HTTP Code: %d\n", httpCode);
    if (httpCode > 0) {
      String response = https.getString();
      Serial.printf("[FIRESTORE] Response: %s\n", response.c_str());
    }
    https.end();
    return false;
  }

  String response = https.getString();
  https.end();

  // Parse JSON response array
  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, response);

  if (error) {
    Serial.printf("[FIRESTORE] JSON Deserialization error: %s\n", error.c_str());
    return false;
  }

  JsonArray results = doc.as<JsonArray>();
  for (JsonObject result : results) {
    if (!result.containsKey("document")) {
      continue;
    }

    JsonObject docObj = result["document"];
    String docName = docObj["name"].as<String>();
    int lastSlash = docName.lastIndexOf('/');
    String switchId = lastSlash != -1 ? docName.substring(lastSlash + 1) : docName;

    JsonObject fields = docObj["fields"];
    String name = fields["name"]["stringValue"].as<String>();
    String room = fields["room"]["stringValue"].as<String>();
    String deviceId = fields["deviceId"]["stringValue"].as<String>();
    bool isOn = fields["isOn"]["booleanValue"].as<bool>();

    if (deviceId == targetDeviceId) {
      SwitchState st;
      st.switchId = switchId;
      st.name = name;
      st.room = room;
      st.deviceId = deviceId;
      st.isOn = isOn;
      st.isValid = true;
      outSwitches.push_back(st);
    }
  }

  return true;
}

bool FirestoreClient::sendHeartbeat(
    const char* projectId,
    const char* apiKey,
    const char* deviceId,
    const std::map<String, bool>& actualStates) {

  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  WiFiClientSecure client;
  client.setCACert(GOOGLE_ROOT_CA);

  HTTPClient https;
  String url = "https://firestore.googleapis.com/v1/projects/";
  url += projectId;
  url += "/databases/(default)/documents/devices/";
  url += deviceId;
  url += "?updateMask.fieldPaths=lastSeen&updateMask.fieldPaths=actualStates&key=";
  url += apiKey;

  if (!https.begin(client, url)) {
    return false;
  }

  https.addHeader("Content-Type", "application/json");

  // Construct heartbeat payload with live UTC timestamp
  JsonDocument doc;
  JsonObject fields = doc["fields"].to<JsonObject>();

  JsonObject lastSeenObj = fields["lastSeen"].to<JsonObject>();
  lastSeenObj["timestampValue"] = getFormattedUtcTimestamp();

  JsonObject actualStatesObj = fields["actualStates"].to<JsonObject>();
  JsonObject mapValueObj = actualStatesObj["mapValue"].to<JsonObject>();
  JsonObject stateFields = mapValueObj["fields"].to<JsonObject>();

  for (const auto& kv : actualStates) {
    JsonObject switchState = stateFields[kv.first].to<JsonObject>();
    switchState["booleanValue"] = kv.second;
  }

  String requestBody;
  serializeJson(doc, requestBody);

  const int httpCode = https.PATCH(requestBody);
  https.end();

  return (httpCode == HTTP_CODE_OK || httpCode == 200 || httpCode == 201);
}
