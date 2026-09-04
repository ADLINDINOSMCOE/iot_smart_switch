import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Helper to dispatch FCM notification to a specific user (or broadcast if targetUserId not specified)
 */
async function sendNotificationToUsers(
  title: string,
  body: string,
  dataPayload: Record<string, string>,
  targetUserId?: string
) {
  try {
    const tokens: string[] = [];

    if (targetUserId) {
      const userDoc = await db.collection('users').doc(targetUserId).get();
      if (userDoc.exists) {
        const userTokens = userDoc.data()?.fcmTokens;
        if (Array.isArray(userTokens)) {
          tokens.push(...userTokens.filter((t) => typeof t === 'string' && t.length > 0));
        }
      }
    } else {
      const usersSnap = await db.collection('users').get();
      usersSnap.forEach((doc) => {
        const userTokens = doc.data().fcmTokens;
        if (Array.isArray(userTokens)) {
          tokens.push(...userTokens.filter((t) => typeof t === 'string' && t.length > 0));
        }
      });
    }

    if (tokens.length === 0) {
      functions.logger.info(`No registered FCM tokens found for target user ${targetUserId || 'all'}. Skipping push notification.`);
      return;
    }

    const uniqueTokens = Array.from(new Set(tokens));

    const response = await messaging.sendEachForMulticast({
      tokens: uniqueTokens,
      notification: {
        title,
        body,
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        ...dataPayload,
      },
    });

    functions.logger.info(
      `Dispatched FCM notification to ${uniqueTokens.length} devices (Success: ${response.successCount}, Failures: ${response.failureCount})`
    );
  } catch (err) {
    functions.logger.error('Error dispatching FCM notification:', err);
  }
}

/**
 * Scheduled Cloud Function running every minute to process all pending timers and schedules.
 * Executes atomically with Firestore transactions to guarantee exact-once execution
 * and single-fire notification dispatch.
 */
export const processPendingSchedulesAndTimers = onSchedule('every 1 minutes', async (_event) => {
  const now = admin.firestore.Timestamp.now();

  const pendingSnapshot = await db
    .collection('schedules')
    .where('status', '==', 'pending')
    .where('time', '<=', now)
    .get();

  if (pendingSnapshot.empty) {
    return;
  }

  functions.logger.info(
    `Found ${pendingSnapshot.size} pending schedule/timer action(s) ready for execution.`
  );

  const executionPromises = pendingSnapshot.docs.map(async (docSnap) => {
    const scheduleId = docSnap.id;
    const scheduleRef = db.collection('schedules').doc(scheduleId);

    try {
      let shouldNotify = false;
      let notificationTitle = '';
      let notificationBody = '';
      let targetScreen = 'home';
      let switchName = '';
      let scheduleUserId: string | undefined;

      await db.runTransaction(async (transaction) => {
        const freshSnap = await transaction.get(scheduleRef);
        if (!freshSnap.exists) {
          return;
        }

        const data = freshSnap.data()!;
        // Strict Idempotency Check
        if (data.status !== 'pending') {
          functions.logger.warn(
            `Schedule/Timer ${scheduleId} status is already '${data.status}'. Bypassing duplicate execution.`
          );
          return;
        }

        const switchId = data.switchId;
        const action = (data.action || 'off').toLowerCase();
        const targetIsOn = action === 'on';
        const type = data.type || 'timer';
        scheduleUserId = data.userId;

        const switchRef = db.collection('switches').doc(switchId);
        const switchSnap = await transaction.get(switchRef);
        switchName = switchSnap.exists ? (switchSnap.data()?.name || switchId) : switchId;
        const deviceId = switchSnap.exists ? (switchSnap.data()?.deviceId || 'esp32_001') : 'esp32_001';

        // Update target switch document: update ONLY the existing 'isOn' field
        transaction.update(switchRef, { isOn: targetIsOn });

        // Update schedule document status to completed
        transaction.update(scheduleRef, {
          status: 'completed',
          executedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Record immutable audit log entry
        const logRef = db.collection('activity_logs').doc();
        transaction.set(logRef, {
          switchId,
          switchName,
          deviceId,
          userId: scheduleUserId || null,
          action: action.toUpperCase(),
          source: type,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        shouldNotify = true;
        if (type === 'timer') {
          notificationTitle = 'Timer Completed';
          notificationBody = `"${switchName}" was automatically turned ${action.toUpperCase()}.`;
          targetScreen = 'home';
        } else {
          notificationTitle = 'Schedule Executed';
          notificationBody = `"${switchName}" was turned ${action.toUpperCase()} as scheduled.`;
          targetScreen = 'schedules';
        }

        functions.logger.info(
          `Executed schedule/timer ${scheduleId} (${type}): switch '${switchId}' set to isOn = ${targetIsOn}`
        );
      });

      // Dispatch single-fire notification outside transaction once commit is successful
      if (shouldNotify) {
        await sendNotificationToUsers(
          notificationTitle,
          notificationBody,
          {
            target: targetScreen,
            scheduleId: scheduleId,
            type: 'execution_completed',
          },
          scheduleUserId
        );
      }
    } catch (e) {
      functions.logger.error(`Error executing schedule/timer ${scheduleId}:`, e);
    }
  });

  await Promise.all(executionPromises);
});

/**
 * Scheduled Cloud Function running every minute to evaluate device connectivity health.
 * Identifies offline devices when (now - lastSeen) > 25s.
 * Uses the isOfflineNotified latch to prevent spamming notifications.
 */
export const checkDeviceHealth = onSchedule('every 1 minutes', async (_event) => {
  const OFFLINE_THRESHOLD_MS = 25 * 1000; // 25 seconds timeout
  const nowMs = Date.now();

  try {
    const devicesSnap = await db.collection('devices').get();

    const devicePromises = devicesSnap.docs.map(async (docSnap) => {
      const deviceId = docSnap.id;
      const data = docSnap.data();
      const lastSeen = data.lastSeen;
      const isOfflineNotified = data.isOfflineNotified === true;

      let lastSeenMs = 0;
      if (lastSeen instanceof admin.firestore.Timestamp) {
        lastSeenMs = lastSeen.toMillis();
      } else if (typeof lastSeen === 'number') {
        lastSeenMs = lastSeen;
      } else if (typeof lastSeen === 'string') {
        lastSeenMs = Date.parse(lastSeen) || 0;
      }

      const diffMs = nowMs - lastSeenMs;
      const isDeviceOffline = diffMs > OFFLINE_THRESHOLD_MS;

      if (isDeviceOffline && !isOfflineNotified) {
        // Device just went offline -> Set latch and dispatch notification once
        await db.collection('devices').doc(deviceId).set(
          { isOfflineNotified: true },
          { merge: true }
        );

        functions.logger.warn(
          `Device '${deviceId}' is OFFLINE (last seen ${Math.round(diffMs / 1000)}s ago). Sending alert.`
        );

        await sendNotificationToUsers(
          'Device Offline Alert',
          `Device "${deviceId}" appears to be offline. Please verify Wi-Fi and power.`,
          {
            target: 'home',
            deviceId: deviceId,
            type: 'device_offline',
          }
        );
      } else if (!isDeviceOffline && isOfflineNotified) {
        // Device came back online -> Reset offline notification latch
        await db.collection('devices').doc(deviceId).set(
          { isOfflineNotified: false },
          { merge: true }
        );

        functions.logger.info(`Device '${deviceId}' is back ONLINE. Reset offline notification latch.`);
      }
    });

    await Promise.all(devicePromises);
  } catch (err) {
    functions.logger.error('Error checking device health:', err);
  }
});
