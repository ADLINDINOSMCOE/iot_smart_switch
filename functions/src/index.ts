import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineString} from "firebase-functions/params";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp, DocumentData, QueryDocumentSnapshot} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {timingSafeEqual} from "crypto";
import {
  WEEKDAY_LABELS,
  computeFollowingRunAt,
  executionKey,
  isOneTime,
  normalizeDays,
  scheduleActionToState,
  toOffsetWallClock,
} from "./schedule";

initializeApp();
const db = getFirestore();

const deviceSecretsParam = defineString("DEVICE_SECRETS", {default: "{}"});

function secretsMap(): Record<string, string> {
  const raw = process.env.DEVICE_SECRETS || deviceSecretsParam.value() || "{}";
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (parsed && typeof parsed === "object") {
      return parsed as Record<string, string>;
    }
  } catch {
    // fall through
  }
  return {};
}

function secretsEqual(expected: string, provided: string): boolean {
  const a = Buffer.from(expected);
  const b = Buffer.from(provided);
  if (a.length !== b.length || a.length === 0) {
    return false;
  }
  return timingSafeEqual(a, b);
}

function parentDeviceId(schedulePath: string): string | null {
  const parts = schedulePath.split("/");
  const switchIndex = parts.indexOf("switches");
  if (switchIndex >= 0 && parts.length > switchIndex + 1) {
    return parts[switchIndex + 1];
  }
  return null;
}

function isLegacyDue(
  data: DocumentData,
  now: Date,
): boolean {
  const offsetMinutes = Number(data.timeZoneOffsetMinutes ?? 0);
  const wall = toOffsetWallClock(now, offsetMinutes);
  const hour = Number(data.hour ?? 0);
  const minute = Number(data.minute ?? 0);
  if (wall.getUTCHours() !== hour || wall.getUTCMinutes() !== minute) {
    return false;
  }
  const days = normalizeDays(data.days);
  if (days.size === 0) return true;
  const jsDay = wall.getUTCDay();
  const label = WEEKDAY_LABELS[jsDay === 0 ? 6 : jsDay - 1];
  return days.has(label);
}

function nextRunAfterNow(
  justExecutedUtc: Date,
  hour: number,
  minute: number,
  days: unknown,
  offsetMinutes: number,
  now: Date,
): Date {
  let cursor = justExecutedUtc;
  for (let i = 0; i < 400; i++) {
    cursor = computeFollowingRunAt({
      justExecutedUtc: cursor,
      hour,
      minute,
      days,
      offsetMinutes,
    });
    if (cursor.getTime() > now.getTime()) {
      return cursor;
    }
  }
  return cursor;
}

export async function executeDueSchedules(now = new Date()): Promise<number> {
  // Optimized query with compound index support
  // Index: enabled (asc) + nextRunAt (asc)
  const enabledSnap = await db.collectionGroup("schedules")
    .where("enabled", "==", true)
    .where("nextRunAt", "<=", Timestamp.fromDate(now))
    .orderBy("nextRunAt", "asc")
    .limit(500)
    .get();

  const dueDocs: QueryDocumentSnapshot[] = [];
  for (const doc of enabledSnap.docs) {
    const data = doc.data();
    const next = data.nextRunAt?.toDate?.() as Date | undefined;
    // Check for both nextRunAt and legacy schedules without nextRunAt
    const due = next instanceof Date
      ? next.getTime() <= now.getTime()
      : isLegacyDue(data, now);
    if (due) {
      dueDocs.push(doc);
    }
  }

  let executed = 0;

  for (const doc of dueDocs) {
    try {
      const data = doc.data();
      const deviceId = String(data.deviceId ?? parentDeviceId(doc.ref.path) ?? "");
      if (!deviceId) continue;

      const offsetMinutes = Number(data.timeZoneOffsetMinutes ?? 0);
      const wall = toOffsetWallClock(now, offsetMinutes);
      const key = executionKey(wall);
      if (data.lastExecutionKey === key) {
        continue;
      }

      const hour = Number(data.hour ?? 0);
      const minute = Number(data.minute ?? 0);
      const days = data.days;
      const oneTime = isOneTime(days);
      const targetIsOn = scheduleActionToState(data.action);
      const actor = String(data.createdBy ?? "system");
      const commandAction = targetIsOn ? "TURN_ON" : "TURN_OFF";

      const switchRef = db.collection("switches").doc(deviceId);
      const commandRef = switchRef.collection("commands").doc();
      const logRef = switchRef.collection("deviceLogs").doc();
      const scheduledAt = data.nextRunAt?.toDate?.() ?? now;
      const following = oneTime
        ? null
        : nextRunAfterNow(scheduledAt, hour, minute, days, offsetMinutes, now);

      const batch = db.batch();
      batch.update(switchRef, {
        isOn: targetIsOn,
        lastUpdatedAt: Timestamp.fromDate(now),
        lastUpdatedBy: actor,
        lastScheduleId: doc.id,
      });
      batch.set(commandRef, {
        action: commandAction,
        targetState: targetIsOn,
        requestedBy: actor,
        deviceId,
        timestamp: Timestamp.fromDate(now),
        status: "EXECUTED",
        source: "schedule",
        scheduleId: doc.id,
      });
      batch.set(logRef, {
        event: commandAction,
        userId: actor,
        deviceId,
        timestamp: Timestamp.fromDate(now),
        details: "schedule_executed",
        scheduleId: doc.id,
      });

      const scheduleUpdate: Record<string, unknown> = {
        lastExecutedAt: Timestamp.fromDate(now),
        lastExecutionKey: key,
      };
      if (oneTime || following == null) {
        scheduleUpdate.enabled = false;
        scheduleUpdate.nextRunAt = FieldValue.delete();
      } else {
        scheduleUpdate.nextRunAt = Timestamp.fromDate(following);
        scheduleUpdate.enabled = true;
      }
      batch.update(doc.ref, scheduleUpdate);

      await batch.commit();
      executed += 1;
    } catch (error) {
      console.error("Failed to execute schedule", doc.id, error);
    }
  }

  return executed;
}

export const executeSchedules = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "UTC",
    region: "us-central1",
  },
  async () => {
    await executeDueSchedules();
  },
);

export const deviceSync = onRequest(
  {
    region: "us-central1",
    cors: false,
    invoker: "public",
  },
  async (req, res) => {
    const deviceId = String(
      req.header("x-device-id") ??
      req.query.deviceId ??
      (req.body && req.body.deviceId) ??
      "",
    ).trim();
    const providedSecret = String(
      req.header("x-device-secret") ??
      (req.body && req.body.deviceSecret) ??
      "",
    );

    if (!deviceId) {
      res.status(400).json({error: "deviceId required"});
      return;
    }

    const expected = secretsMap()[deviceId];
    if (!expected || !secretsEqual(expected, providedSecret)) {
      res.status(401).json({error: "Unauthorized device"});
      return;
    }

    const switchRef = db.collection("switches").doc(deviceId);
    const snapshot = await switchRef.get();
    if (!snapshot.exists) {
      res.status(404).json({error: "Device document not found"});
      return;
    }

    const data = snapshot.data() ?? {};
    if (data.deviceId && String(data.deviceId) !== deviceId) {
      res.status(403).json({error: "Device ID mismatch"});
      return;
    }

    if (req.method === "POST") {
      const wasOnline = data.online === true;
      await switchRef.update({
        online: true,
        lastSyncAt: FieldValue.serverTimestamp(),
        lastHeartbeatAt: FieldValue.serverTimestamp(),
      });
      if (!wasOnline) {
        await switchRef.collection("deviceLogs").add({
          event: "DEVICE_ONLINE",
          userId: String(data.ownerId ?? "device"),
          deviceId,
          timestamp: FieldValue.serverTimestamp(),
          details: "heartbeat",
        });
      }
      res.status(200).json({ok: true, deviceId, online: true});
      return;
    }

    res.status(200).json({
      deviceId,
      isOn: data.isOn === true,
      online: data.online === true,
      updatedAt: data.lastUpdatedAt instanceof Timestamp
        ? data.lastUpdatedAt.toDate().toISOString()
        : null,
    });
  },
);

// Device registration endpoint
export const registerDevice = onRequest(
  {
    region: "us-central1",
    cors: false,
  },
  async (req, res) => {
    const authHeader = req.header("authorization");

    if (!authHeader) {
      res.status(401).json({error: "Authorization header required"});
      return;
    }

    // Extract and verify Firebase Auth token
    const auth = getAuth();
    let uid: string | null = null;

    try {
      const token = authHeader.replace("Bearer ", "");
      const decodedToken = await auth.verifyIdToken(token);
      uid = decodedToken.uid;
    } catch (error) {
      res.status(401).json({error: "Invalid or expired token"});
      return;
    }

    const { deviceId, deviceName, deviceSecret } = req.body || {};

    if (!deviceId || !deviceName || !deviceSecret) {
      res.status(400).json({error: "deviceId, deviceName, and deviceSecret are required"});
      return;
    }

    // Validate device ID format
    if (!/^[a-zA-Z0-9_-]{3,50}$/.test(deviceId)) {
      res.status(400).json({error: "Invalid deviceId format. Use 3-50 alphanumeric characters, hyphens, or underscores"});
      return;
    }

    try {
      const switchRef = db.collection("switches").doc(deviceId);
      const snapshot = await switchRef.get();

      if (snapshot.exists) {
        const data = snapshot.data() || {};
        if (data.ownerId !== uid) {
          res.status(403).json({error: "Device already registered by another user"});
          return;
        }
        // Device exists and belongs to this user, update secret
        await switchRef.update({
          deviceSecret: deviceSecret,
          lastUpdatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        // Create new device
        await switchRef.set({
          deviceId,
          name: deviceName,
          room: "Unassigned",
          isOn: false,
          online: false,
          ownerId: uid,
          sharedWith: {},
          sharedWithUids: [],
          sharedUsers: [],
          deviceSecret: deviceSecret,
          createdAt: FieldValue.serverTimestamp(),
          lastUpdatedAt: FieldValue.serverTimestamp(),
          lastUpdatedBy: uid,
          timerActive: false,
          totalRuntimeSeconds: 0,
          energyConsumptionKwh: 0,
        });
      }

      res.status(200).json({success: true, deviceId, message: "Device registered successfully"});
    } catch (error) {
      console.error("Error registering device:", error);
      res.status(500).json({error: "Failed to register device"});
    }
  },
);

// Device offline detection - runs every 5 minutes
export const detectOfflineDevices = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "UTC",
    region: "us-central1",
  },
  async () => {
    const offlineThreshold = Timestamp.fromDate(new Date(Date.now() - 5 * 60 * 1000)); // 5 minutes ago

    const offlineSnap = await db.collection("switches")
      .where("online", "==", true)
      .where("lastHeartbeatAt", "<", offlineThreshold)
      .get();

    const batch = db.batch();
    for (const doc of offlineSnap.docs) {
      const data = doc.data();
      const deviceId = doc.id;

      batch.update(doc.ref, {
        online: false,
        offlineSince: FieldValue.serverTimestamp(),
      });

      batch.set(doc.ref.collection("deviceLogs").doc(), {
        event: "DEVICE_OFFLINE",
        userId: String(data.ownerId ?? "system"),
        deviceId,
        timestamp: FieldValue.serverTimestamp(),
        details: "heartbeat_timeout",
      });
    }

    if (offlineSnap.size > 0) {
      await batch.commit();
      console.log(`Marked ${offlineSnap.size} devices as offline`);
    }
  },
);

// Device cascade deletion - delete device and all subcollections
export const deleteDeviceCascade = onRequest(
  {
    region: "us-central1",
    cors: false,
  },
  async (req, res) => {
    const deviceId = req.query.deviceId as string;
    const authHeader = req.header("authorization");

    if (!deviceId) {
      res.status(400).json({error: "deviceId required"});
      return;
    }

    if (!authHeader) {
      res.status(401).json({error: "Authorization header required"});
      return;
    }

    // Extract and verify Firebase Auth token
    const auth = getAuth();
    let uid: string | null = null;

    try {
      const token = authHeader.replace("Bearer ", "");
      const decodedToken = await auth.verifyIdToken(token);
      uid = decodedToken.uid;
    } catch (error) {
      res.status(401).json({error: "Invalid or expired token"});
      return;
    }

    const db = getFirestore();
    const deviceRef = db.collection("switches").doc(deviceId);
    const deviceDoc = await deviceRef.get();

    if (!deviceDoc.exists) {
      res.status(404).json({error: "Device not found"});
      return;
    }

    const deviceData = deviceDoc.data() || {};
    if (deviceData.ownerId !== uid) {
      res.status(403).json({error: "Only device owner can delete"});
      return;
    }

    try {
      // Delete all subcollections
      const subcollections = ["schedules", "timerHistory", "commands", "deviceLogs"];
      const batch = db.batch();

      for (const subcol of subcollections) {
        const subcolSnap = await deviceRef.collection(subcol).get();
        for (const subDoc of subcolSnap.docs) {
          batch.delete(subDoc.ref);
        }
      }

      // Delete the device document
      batch.delete(deviceRef);

      await batch.commit();

      res.status(200).json({success: true, message: "Device and all data deleted"});
    } catch (error) {
      console.error("Error deleting device cascade:", error);
      res.status(500).json({error: "Failed to delete device"});
    }
  },
);

// Account deletion cleanup - triggered when user document is deleted
export const cleanupUserDataOnDelete = onRequest(
  {
    region: "us-central1",
    cors: false,
  },
  async (req, res) => {
    const authHeader = req.header("authorization");

    if (!authHeader) {
      res.status(401).json({error: "Authorization header required"});
      return;
    }

    // Extract and verify Firebase Auth token
    const auth = getAuth();
    let uid: string | null = null;

    try {
      const token = authHeader.replace("Bearer ", "");
      const decodedToken = await auth.verifyIdToken(token);
      uid = decodedToken.uid;
    } catch (error) {
      res.status(401).json({error: "Invalid or expired token"});
      return;
    }

    const db = getFirestore();

    try {
      // Delete user profile document
      await db.collection("users").doc(uid).delete();

      // Find all devices owned by this user
      const ownedDevices = await db.collection("switches")
        .where("ownerId", "==", uid)
        .get();

      // Cascade delete all owned devices and their subcollections
      const batch = db.batch();
      for (const deviceDoc of ownedDevices.docs) {
        // Delete all subcollections
        const subcollections = ["schedules", "timerHistory", "commands", "deviceLogs"];
        for (const subcol of subcollections) {
          const subcolSnap = await deviceDoc.ref.collection(subcol).get();
          for (const subDoc of subcolSnap.docs) {
            batch.delete(subDoc.ref);
          }
        }

        // Delete the device document
        batch.delete(deviceDoc.ref);
      }

      if (ownedDevices.size > 0) {
        await batch.commit();
        console.log(`Deleted ${ownedDevices.size} devices and subcollections for user ${uid}`);
      }

      // Remove user from shared devices
      const sharedDevices = await db.collection("switches")
        .where("sharedWithUids", "array-contains", uid)
        .get();

      for (const deviceDoc of sharedDevices.docs) {
        const data = deviceDoc.data();
        const sharedWith = data.sharedWith || {};
        const sharedWithUids = data.sharedWithUids || [];
        const sharedUsers = data.sharedUsers || [];

        // Remove user from sharedWith map
        delete sharedWith[uid];

        // Remove user from sharedWithUids array
        const updatedSharedWithUids = sharedWithUids.filter((id: string) => id !== uid);

        // Remove user from sharedUsers array
        const updatedSharedUsers = sharedUsers.filter((user: any) => user.uid !== uid);

        await deviceDoc.ref.update({
          sharedWith,
          sharedWithUids: updatedSharedWithUids,
          sharedUsers: updatedSharedUsers,
          lastUpdatedAt: FieldValue.serverTimestamp(),
        });
      }

      // Delete Firebase Auth user
      await auth.deleteUser(uid);

      res.status(200).json({success: true, message: "User data cleaned up successfully"});
    } catch (error) {
      console.error(`Error cleaning up user data for ${uid}:`, error);
      res.status(500).json({error: "Failed to cleanup user data"});
    }
  },
);

export {computeFollowingRunAt, isOneTime, executionKey};
