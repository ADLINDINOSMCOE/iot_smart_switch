# IoT Smart Switch — System Runbook & Setup Guide

This document contains the authoritative setup, deployment, hardware wiring, security policies, and operational verification instructions for the **Production IoT Smart Switch System** (Tuya / Smart Life standard).

---

## 1. System Architecture Overview

```text
┌─────────────────────────────────────────────────────────┐
│                   Flutter Mobile App                    │
│   (AuthGate, HomeScreen, SwitchDetail, Logs, Telemetry) │
└────────────────────────────┬────────────────────────────┘
                             │ HTTPS / WebSocket Stream (Live)
                             ▼
┌─────────────────────────────────────────────────────────┐
│               Google Cloud Firestore                    │
│   Collections: switches, schedules, devices, users,     │
│                activity_logs                            │
└──────────────┬───────────────────────────┬──────────────┘
               │ HTTPS REST (NTP + TLS)    │ FCM Push Alerts (Scoped)
               ▼                           ▼
┌───────────────────────────┐ ┌───────────────────────────┐
│    ESP32 Microcontroller  │ │ Firebase Cloud Functions  │
│  (4-Ch GPIO, Task WDT)    │ │ (processPending, health)  │
└──────────────┬────────────┘ └───────────────────────────┘
               │ GPIO 23, 22, 21, 19
               ▼
┌───────────────────────────┐
│   4-Channel Relay Module  │
│ (Active-HIGH/Active-LOW)  │
└──────────────┬────────────┘
               │ 110V / 230V AC Mains
               ▼
┌───────────────────────────┐
│  Lights / Fans / Loads    │
└───────────────────────────┘
```

> **Single Source of Truth**: All switch state changes, timers, schedules, audit logs, and telemetry flow exclusively through **Cloud Firestore**. There is **zero direct Flutter-to-ESP32 communication**.

---

## 2. Authoritative Cloud Firestore Schema & Security

### 1. `switches/{switch_id}`
| Field | Type | Description |
|---|---|---|
| `name` | `string` | Human-readable switch name (e.g. `"Living Room Main Light"`). |
| `room` | `string` | Room grouping name (e.g. `"Living Room"`, `"Kitchen"`). |
| `isOn` | `boolean` | Desired state requested from app/timer/schedule. (Only field mutable by clients). |
| `deviceId` | `string` | Target microcontroller binding (e.g. `"esp32_001"`). |
| `ownerId` | `string` \| `null` | Owner User UID for multi-tenant isolation. |

### 2. `schedules/{schedule_id}`
| Field | Type | Description |
|---|---|---|
| `switchId` | `string` | ID of the target switch in `switches` collection. |
| `action` | `string` | Target action: `"on"` or `"off"`. |
| `time` | `timestamp` | Target execution timestamp stored in canonical **UTC**. |
| `type` | `string` | `"timer"` (one-shot) or `"schedule"` (scheduled time). |
| `status` | `string` | `"pending"` \| `"completed"` \| `"cancelled"`. |
| `executedAt` | `timestamp` \| `null` | Timestamp recorded at the moment of execution. |
| `userId` | `string` \| `null` | Creator User UID for scoped access. |
| `repeatDays`| `array<string>` | Optional list of repeating days (e.g. `["mon", "wed", "fri"]`). |

### 3. `devices/{deviceId}`
| Field | Type | Description |
|---|---|---|
| `lastSeen` | `timestamp` | Real UTC timestamp received from ESP32 SNTP clock. |
| `actualStates` | `map<string, boolean>` | Map of switchId to confirmed physical relay state. |
| `isOfflineNotified` | `boolean` | Anti-spam latch preventing duplicate offline alerts. |

### 4. `users/{userId}`
| Field | Type | Description |
|---|---|---|
| `name` | `string` | User display name. |
| `email` | `string` | User email address. |
| `fcmTokens` | `array<string>` | Active FCM push notification tokens. |
| `updatedAt` | `timestamp` | Last profile sync timestamp. |

### 5. `activity_logs/{logId}`
| Field | Type | Description |
|---|---|---|
| `switchId` | `string` | Target switch ID. |
| `switchName` | `string` | Switch display name. |
| `deviceId` | `string` | Microcontroller ID. |
| `userId` | `string` \| `null` | Acting user UID. |
| `action` | `string` | `"ON"`, `"OFF"`, `"TIMER"`, `"SCHEDULE"`. |
| `source` | `string` | `"mobile_app"`, `"timer"`, `"schedule"`, `"hardware"`. |
| `timestamp` | `timestamp` | Immutable event timestamp. |

---

## 3. Flutter App Setup & Run Instructions

### Prerequisites
- Flutter SDK (>= 3.29.0) & Dart (>= 3.7.0)
- Android Studio / Xcode (for iOS/macOS)

### Setup Steps
```bash
# 1. Navigate to project root
cd /Users/adlinthomas/.gemini/antigravity/scratch/iot_smart_switch

# 2. Install dependencies
flutter pub get

# 3. Run static analysis
flutter analyze

# 4. Run automated test suite (67/67 tests)
flutter test

# 5. Launch the application
flutter run
```

---

## 4. Firebase Cloud Functions Deployment

Cloud Functions handle background timer/schedule execution, scoped FCM dispatch, and device health monitoring even when the mobile app is terminated.

```bash
cd functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Deploy Cloud Functions to Firebase
firebase deploy --only functions
```

### Deployed Cloud Functions:
1. `processPendingSchedulesAndTimers`: Runs every minute via Cloud Scheduler. Executes pending timers and schedules in an atomic Firestore transaction, writes immutable activity logs, and dispatches scoped FCM push alerts.
2. `checkDeviceHealth`: Runs every minute. Checks device `lastSeen` against the **25-second timeout threshold** and sends an offline alert with anti-spam latching.

---

## 5. ESP32 Firmware Setup & Flashing

### Firmware Directory: `firmware/`

### 1. Configure Private Secrets (`secrets.h`)
Copy `firmware/include/secrets.h.template` to `firmware/include/secrets.h`:
```c
// firmware/include/secrets.h
#pragma once

#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
#define FIREBASE_PROJECT_ID "your-firebase-project-id"
#define FIREBASE_API_KEY "AIzaSy..."
```
*(Note: `secrets.h` is strictly gitignored to prevent credential exposure).*

### 2. 4-Channel Hardware Pin Configuration (`firmware/src/config.h`)
```c
#define DEVICE_ID "esp32_001"
#define RELAY_PIN_1 23          // Switch 1: Living Room Main Light
#define RELAY_PIN_2 22          // Switch 2: Ceiling Fan
#define RELAY_PIN_3 21          // Switch 3: Kitchen Overhead Lamp
#define RELAY_PIN_4 19          // Switch 4: Bedroom Nightstand Lamp
#define STATUS_LED_PIN 2        // Built-in LED
#define RELAY_ACTIVE_LEVEL HIGH // HIGH for Active-High, LOW for Active-Low
#define FIRESTORE_POLL_INTERVAL_MS 2000 // 2.0s polling
#define HEARTBEAT_INTERVAL_MS 10000     // 10.0s telemetry
#define WATCHDOG_TIMEOUT_SEC 15         // Task Watchdog Timer
```

### 3. Flash to ESP32 using PlatformIO
```bash
cd firmware

# Build firmware
pio run

# Flash to connected ESP32
pio run -t upload

# Open Serial Monitor at 115200 baud
pio device monitor -b 115200
```

---

## 6. Hardware Wiring & Safety Notes

### Wiring Diagram (ESP32 to 4-Channel Relay Module)
| ESP32 Pin | Relay Board Pin | Circuit Controlled |
|---|---|---|
| **GPIO 23** | **IN 1** | Switch 1 (Living Room Main Light) |
| **GPIO 22** | **IN 2** | Switch 2 (Ceiling Fan) |
| **GPIO 21** | **IN 3** | Switch 3 (Kitchen Overhead Lamp) |
| **GPIO 19** | **IN 4** | Switch 4 (Bedroom Nightstand Lamp) |
| **5V / VIN** | **VCC** | Relay board power (5V DC) |
| **GND** | **GND** | Common ground reference |

### Safety Precautions
> [!CAUTION]
> **Mains Voltage Safety (110V - 240V AC)**:
> 1. Always disconnect AC mains power from the circuit breaker before wiring relay terminals.
> 2. Ensure mains live (L) and neutral (N) wires are securely seated in the relay screw terminals (COM and NO).
> 3. Use an isolated enclosure for the relay module to prevent accidental contact with high voltage contacts.
> 4. Keep ESP32 logic ground strictly separated from AC mains lines.

### Safe Boot Behavior
- Firmware initializes all 4 GPIO channels (23, 22, 21, 19) to **OFF** immediately upon boot before any Wi-Fi or Firestore connection is established.
- Task Watchdog Timer automatically resets the microcontroller if network lockup occurs for > 15 seconds.

---

## 7. Operational Verification Matrix

1. **Authentication & Session Persistence**: Log in -> close app -> reopen -> direct landing on `HomeScreen` without login prompt.
2. **Device Ownership Authorization**: User A cannot read or modify User B's switches; field-level rules prevent unauthorized key modification.
3. **Live Real-Time Streaming**: `SwitchDetailScreen` instantly updates on remote or hardware state change.
4. **SNTP Real-Time Telemetry**: ESP32 synchronizes live UTC time from NTP servers and transmits accurate ISO timestamps to `devices/{deviceId}`.
5. **Activity Audit Trail**: All user toggles and cloud executions record timestamped entries in `activity_logs`.
