#pragma once
#include <Arduino.h>
#include <vector>
#include <map>

struct SwitchState {
  String switchId;
  String name;
  String room;
  String deviceId;
  bool isOn;
  bool isValid;
};

class FirestoreClient {
public:
  FirestoreClient();

  /// Executes an HTTPS REST runQuery to fetch all switches bound to targetDeviceId
  bool fetchAllSwitchesForDevice(
    const char* projectId,
    const char* apiKey,
    const char* targetDeviceId,
    std::vector<SwitchState>& outSwitches
  );

  /// Sends a real-time heartbeat and actual physical relay states map to devices/{deviceId}
  bool sendHeartbeat(
    const char* projectId,
    const char* apiKey,
    const char* deviceId,
    const std::map<String, bool>& actualStates
  );

private:
  String buildQueryPayload(const char* targetDeviceId);
  String getFormattedUtcTimestamp();
};
