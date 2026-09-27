# Real ESP32 End-to-End Test Guide

This guide provides comprehensive instructions for testing the ESP32 hardware end-to-end with the Flutter app and Firebase backend.

## Hardware Requirements

### Components
- ESP32 development board (ESP32-WROOM-32 or similar)
- 5V Relay module (HLA-S-108L or similar)
- Power supply (5V, 2A minimum)
- Jumper wires (male-to-male and male-to-female)
- LED (optional, for status indication)
- Resistors (330Ω for LED, if used)
- Breadboard (optional)

### Tools
- USB cable for ESP32 programming
- Arduino IDE (1.8.x or 2.x)
- ESP32 board support package
- Serial terminal (Serial Monitor, PuTTY, or similar)
- Multimeter (for testing)
- Wi-Fi network with internet access

## Firmware Setup

### 1. Arduino IDE Configuration

Install ESP32 board support:
1. Open Arduino IDE
2. Go to File → Preferences
3. Add to "Additional Board Manager URLs":
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
4. Go to Tools → Board → Boards Manager
5. Search for "esp32" and install "ESP32 by Espressif Systems"

### 2. Install Required Libraries

Install these libraries via Library Manager:
- WiFi (built-in)
- WiFiClientSecure (built-in)
- HTTPClient (built-in)
- ArduinoJson by Benoit Blanchon (version 6.x)

### 3. Configure Firmware

Copy `esp32/secrets.h.template` to `esp32/secrets.h`:
```bash
cp esp32/secrets.h.template esp32/secrets.h
```

Edit `esp32/secrets.h` with your credentials:
```cpp
#ifndef SECRETS_H
#define SECRETS_H

// Wi-Fi Credentials
#define WIFI_SSID "your_wifi_ssid"
#define WIFI_PASSWORD "your_wifi_password"

// Firebase Configuration
#define FIREBASE_PROJECT_ID "iot-switch-23826"
#define DEVICE_ID "esp32_relay_01"
#define DEVICE_SECRET_TOKEN "your_device_secret"

#endif
```

### 4. Upload Firmware

1. Connect ESP32 via USB
2. Select board: Tools → Board → ESP32 Arduino → ESP32 Dev Module
3. Select port: Tools → Port → /dev/cu.usbserial-...
4. Upload: Sketch → Upload

## Hardware Assembly

### Wiring Diagram

```
ESP32 Connections:
┌─────────────────┐
│ ESP32           │
│                 │
│ GPIO 23 ────────┼── Relay IN
│ 3.3V   ────────┼── LED (with 330Ω resistor) → GND
│ GND    ────────┼── Relay GND
│ 5V     ────────┼── Relay VCC
│                 │
└─────────────────┘

Relay Connections:
┌─────────────────┐
│ Relay Module    │
│                 │
│ IN  ────────────┼── ESP32 GPIO 23
│ VCC ────────────┼── ESP32 5V
│ GND ────────────┼── ESP32 GND
│ NO  ────────────┼── Load (light/appliance)
│ COM ────────────┼── Power source (5V-24V)
│ NC  ────────────┼── Not used
└─────────────────┘
```

### Safety Precautions

⚠️ **WARNING**: Working with mains voltage is dangerous. For testing, use low-voltage DC power (5V-12V) only.

- Never connect relay to mains voltage during testing
- Use insulated tools
- Double-check wiring before powering on
- Keep workspace dry
- Have a fire extinguisher nearby

## Firebase Setup

### 1. Register Device

Use the device registration endpoint or manually create device in Firestore:

```javascript
// In Firebase Console Firestore
collection: switches
document: esp32_relay_01
fields:
  deviceId: "esp32_relay_01"
  name: "Living Room Light"
  room: "Living Room"
  ownerId: "your_user_id"
  deviceSecret: "your_device_secret"
  isOn: false
  online: false
  createdAt: timestamp
  lastUpdatedAt: timestamp
```

### 2. Configure Device Secrets

Add device secret to Cloud Functions environment:
```bash
firebase functions:config:set DEVICE_SECRETS='{"esp32_relay_01":"your_device_secret"}'
```

### 3. Deploy Backend

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```

## Testing Procedure

### Test 1: Hardware Boot and Wi-Fi Connection

**Objective**: Verify ESP32 boots and connects to Wi-Fi

**Steps**:
1. Power on ESP32
2. Open Serial Monitor (115200 baud)
3. Observe boot sequence

**Expected Output**:
```
========================================
   SECURE ESP32 SMART SWITCH STARTUP    
   Device ID: esp32_relay_01
========================================
[BOOT] Connecting to Wi-Fi...
[BOOT] Wi-Fi connected
[BOOT] IP address: 192.168.1.xxx
```

**Pass Criteria**:
- ESP32 boots without crashes
- Wi-Fi connection succeeds
- IP address is assigned

### Test 2: Firebase Authentication

**Objective**: Verify device authenticates with Firebase

**Steps**:
1. Monitor serial output
2. Wait for Firebase sync attempts

**Expected Output**:
```
[SYNC] Authenticating with Firebase...
[SYNC] Authentication successful
[SYNC] Fetching device state...
```

**Pass Criteria**:
- Authentication succeeds
- No TLS errors
- Certificate validation passes

### Test 3: Device Registration

**Objective**: Verify device is registered in Firebase

**Steps**:
1. Check Firebase Console → Firestore
2. Navigate to switches collection
3. Find document with deviceId "esp32_relay_01"

**Expected Result**:
- Document exists
- online field is true
- lastHeartbeatAt is recent

**Pass Criteria**:
- Document created/updated
- Heartbeat timestamp is current

### Test 4: App-to-Device Control

**Objective**: Verify Flutter app can control ESP32

**Steps**:
1. Open Flutter app
2. Login with Firebase account
3. Navigate to device list
4. Tap device to turn ON
5. Monitor ESP32 serial output
6. Observe relay state change

**Expected Output**:
```
[SYNC] Command received: TURN_ON
[SYNC] Target state: true
[SYNC] Executing command...
[RELAY] Turning relay ON
[SYNC] Command executed successfully
[ACK] Acknowledgement sent
```

**Expected Behavior**:
- Relay clicks (audible or visible)
- LED turns on (if connected)
- App shows device as ON

**Pass Criteria**:
- Command received by ESP32
- Relay state changes
- Acknowledgement sent
- App updates to show ON state

### Test 5: Device-to-App Sync

**Objective**: Verify device state syncs to app

**Steps**:
1. Manually toggle relay (if physically accessible)
2. Wait for heartbeat interval (10 seconds)
3. Check app device state

**Expected Behavior**:
- App updates to show correct state
- Firebase document updates
- No lag > 15 seconds

**Pass Criteria**:
- State syncs within heartbeat interval
- App shows correct state
- Firebase document matches hardware state

### Test 6: Anti-Replay Protection

**Objective**: Verify anti-replay protection works

**Steps**:
1. Capture a valid command from serial output
2. Note the command nonce/timestamp
3. Manually send the same command again (via Firestore)
4. Monitor ESP32 response

**Expected Output**:
```
[SECURITY WARNING] Replay attack detected! Command nonce too low: xxx
[SYNC] Ignoring duplicate command
```

**Pass Criteria**:
- Duplicate command is rejected
- No relay state change
- Security warning logged

### Test 7: Command Idempotency

**Objective**: Verify duplicate commands are not executed

**Steps**:
1. Send TURN_ON command
2. Immediately send same TURN_ON command
3. Monitor ESP32 response

**Expected Output**:
```
[IDEMPOTENCY] Duplicate command detected: xxx
[SYNC] Ignoring duplicate command
```

**Pass Criteria**:
- Duplicate command detected
- Only one relay state change
- No unexpected behavior

### Test 8: Command Acknowledgement

**Objective**: Verify ESP32 sends command acknowledgements

**Steps**:
1. Send a command from app
2. Check Firestore commands subcollection
3. Verify acknowledgement document

**Expected Result**:
- Acknowledgement document created
- Contains success: true
- Contains executedAt timestamp
- Contains relayState

**Pass Criteria**:
- Acknowledgement sent successfully
- All required fields present
- Timestamp is current

### Test 9: Offline Recovery

**Objective**: Verify device recovers from network loss

**Steps**:
1. Disconnect Wi-Fi (disable router or ESP32)
2. Wait 30 seconds
3. Reconnect Wi-Fi
4. Monitor ESP32 serial output

**Expected Output**:
```
[NETWORK] Wi-Fi disconnected
[NETWORK] Attempting reconnection...
[NETWORK] Wi-Fi reconnected
[OFFLINE RECOVERY] Connection restored, syncing state...
[HEARTBEAT] Telemetry synced successfully.
```

**Pass Criteria**:
- Device detects offline state
- Automatic reconnection succeeds
- State syncs after reconnection
- No manual intervention required

### Test 10: Relay State Synchronization

**Objective**: Verify relay state syncs with Firebase

**Steps**:
1. Set relay to ON via app
2. Power cycle ESP32
3. Wait for boot and Wi-Fi connection
4. Check relay state

**Expected Behavior**:
- Relay returns to last known state (ON)
- Firebase document matches hardware state
- No manual reset required

**Pass Criteria**:
- State persists across power cycle
- Hardware matches Firebase
- No state loss

### Test 11: Timer Functionality

**Objective**: Verify timer execution works

**Steps**:
1. Set a 1-minute timer in app
2. Monitor ESP32 serial output
3. Observe relay behavior
4. Verify timer completion

**Expected Output**:
```
[SYNC] Timer command received
[SYNC] Timer started
[TIMER] Timer running...
[TIMER] Timer completed
[RELAY] Turning relay OFF
```

**Pass Criteria**:
- Timer starts correctly
- Relay turns off after timer
- Timer history recorded in Firestore

### Test 12: Schedule Execution

**Objective**: Verify scheduled commands execute

**Steps**:
1. Create a schedule for 1 minute from now
2. Wait for scheduled time
3. Monitor ESP32 serial output
4. Verify relay state change

**Expected Output**:
```
[SYNC] Schedule received
[SCHEDULE] Waiting for execution time...
[SCHEDULE] Executing scheduled command
[RELAY] Turning relay ON
```

**Pass Criteria**:
- Schedule created successfully
- Command executes at scheduled time
- Relay state changes as expected

### Test 13: Device Registration Endpoint

**Objective**: Verify device registration API works

**Steps**:
1. Use a test user's Firebase auth token
2. Call registerDevice endpoint
3. Verify device created in Firestore

**Request Example**:
```bash
curl -X POST \
  https://us-central1-iot-switch-23826.cloudfunctions.net/registerDevice \
  -H "Authorization: Bearer <firebase_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "test_device_001",
    "deviceName": "Test Switch",
    "deviceSecret": "test_secret_123"
  }'
```

**Expected Response**:
```json
{
  "success": true,
  "deviceId": "test_device_001",
  "message": "Device registered successfully"
}
```

**Pass Criteria**:
- Device created in Firestore
- Ownership set to requesting user
- Device secret stored correctly

### Test 14: Energy Tracking

**Objective**: Verify energy consumption tracking

**Steps**:
1. Turn device ON
2. Wait 1 minute
3. Turn device OFF
4. Check Firestore document

**Expected Result**:
- totalRuntimeSeconds increased
- energyConsumptionKwh calculated
- turnedOnAt cleared

**Pass Criteria**:
- Runtime tracked accurately
- Energy calculated correctly
- Fields updated on OFF

### Test 15: Error Handling

**Objective**: Verify error handling works

**Test 15a: Invalid Device Secret**
1. Change device secret in firmware
2. Re-upload firmware
3. Monitor serial output

**Expected Output**:
```
[SYNC] Authentication failed
[SYNC] Unauthorized device
```

**Test 15b: Invalid Device ID**
1. Change device ID in firmware
2. Re-upload firmware
3. Monitor serial output

**Expected Output**:
```
[SYNC] Device document not found
[SYNC] Device ID mismatch
```

**Test 15c: Network Timeout**
1. Disconnect internet from router
2. Wait for sync attempt
3. Monitor serial output

**Expected Output**:
```
[NETWORK] Connection timeout
[NETWORK] Retrying...
```

**Pass Criteria**:
- Errors logged appropriately
- No crashes or undefined behavior
- Recovery attempts work

## Performance Tests

### Test 16: Latency Measurement

**Objective**: Measure command-to-execution latency

**Steps**:
1. Record timestamp when command sent from app
2. Record timestamp when relay activates
3. Calculate latency

**Expected Result**:
- Latency < 2 seconds for local network
- Latency < 5 seconds for typical internet

**Pass Criteria**:
- Latency within acceptable range
- Consistent performance

### Test 17: Memory Usage

**Objective**: Verify ESP32 memory usage is acceptable

**Steps**:
1. Monitor free heap memory in serial output
2. Observe memory during operation

**Expected Result**:
- Free heap > 100KB
- No memory leaks over time

**Pass Criteria**:
- Memory usage stable
- No heap exhaustion

### Test 18: Power Consumption

**Objective**: Measure ESP32 power consumption

**Steps**:
1. Measure current with multimeter
2. Compare idle vs active states

**Expected Result**:
- Idle: < 100mA
- Active (with Wi-Fi): < 200mA

**Pass Criteria**:
- Power consumption within specifications
- No excessive current draw

## Stress Tests

### Test 19: Rapid Command Execution

**Objective**: Verify device handles rapid commands

**Steps**:
1. Send 10 commands in quick succession
2. Monitor ESP32 response
3. Verify all commands processed

**Expected Result**:
- All commands processed
- No crashes or hangs
- Final state correct

**Pass Criteria**:
- Commands processed sequentially
- No state corruption

### Test 20: Long-Running Stability

**Objective**: Verify device stability over extended period

**Steps**:
1. Run device for 24 hours
2. Monitor serial output periodically
3. Check heartbeat continuity

**Expected Result**:
- No crashes or reboots
- Heartbeats continue
- Memory stable

**Pass Criteria**:
- Stable operation
- No memory leaks
- No watchdog resets

## Security Tests

### Test 21: TLS Certificate Validation

**Objective**: Verify TLS certificate validation works

**Steps**:
1. Attempt to connect to server with invalid certificate
2. Monitor ESP32 response

**Expected Output**:
```
[TLS] Certificate validation failed
[TLS] Connection rejected
```

**Pass Criteria**:
- Invalid certificates rejected
- Only valid certificates accepted

### Test 22: Device Secret Protection

**Objective**: Verify device secret is protected

**Steps**:
1. Check firmware binary for secrets
2. Verify secrets are not in plaintext

**Expected Result**:
- Secrets not easily extractable
- Use of secure storage if possible

**Pass Criteria**:
- Secrets protected
- No plaintext secrets in code

## Test Results Summary

Create a test results document:

| Test # | Test Name | Status | Notes |
|--------|-----------|--------|-------|
| 1 | Hardware Boot and Wi-Fi Connection | ☐ | |
| 2 | Firebase Authentication | ☐ | |
| 3 | Device Registration | ☐ | |
| 4 | App-to-Device Control | ☐ | |
| 5 | Device-to-App Sync | ☐ | |
| 6 | Anti-Replay Protection | ☐ | |
| 7 | Command Idempotency | ☐ | |
| 8 | Command Acknowledgement | ☐ | |
| 9 | Offline Recovery | ☐ | |
| 10 | Relay State Synchronization | ☐ | |
| 11 | Timer Functionality | ☐ | |
| 12 | Schedule Execution | ☐ | |
| 13 | Device Registration Endpoint | ☐ | |
| 14 | Energy Tracking | ☐ | |
| 15 | Error Handling | ☐ | |
| 16 | Latency Measurement | ☐ | |
| 17 | Memory Usage | ☐ | |
| 18 | Power Consumption | ☐ | |
| 19 | Rapid Command Execution | ☐ | |
| 20 | Long-Running Stability | ☐ | |
| 21 | TLS Certificate Validation | ☐ | |
| 22 | Device Secret Protection | ☐ | |

## Troubleshooting

### Common Issues

**ESP32 won't connect to Wi-Fi**
- Check SSID and password in secrets.h
- Verify Wi-Fi network is 2.4GHz (ESP32 doesn't support 5GHz)
- Check router settings (WPA2/WPA3 compatibility)

**Firebase authentication fails**
- Verify Firebase project ID is correct
- Check device secret matches Firestore
- Verify internet connectivity
- Check firewall settings

**Relay doesn't respond**
- Check GPIO wiring (GPIO 23)
- Verify relay power supply (5V)
- Test relay with manual trigger
- Check relay module is not damaged

**Commands not received**
- Verify device is online in Firestore
- Check heartbeat is being sent
- Verify Cloud Functions are deployed
- Check Firestore rules allow writes

**Certificate validation errors**
- Verify Root CA certificates are correct
- Check date/time on ESP32 (if RTC present)
- Verify Firebase certificate is valid

## Cleanup

After testing:
1. Remove test device from Firestore
2. Remove test user if created
3. Clear test data from Firestore
4. Disconnect hardware safely
5. Document any issues found

## Final Verification

Before declaring end-to-end test complete:
- [ ] All functional tests pass
- [ ] All performance tests meet criteria
- [ ] All stress tests stable
- [ ] All security tests pass
- [ ] Documentation updated
- [ ] Known issues documented
- [ ] Test results signed off

---

**Test Environment**: Document test setup and conditions  
**Test Date**: Record test execution date  
**Test Operator**: Record who performed tests  
**Status**: Pass/Fail/Partial