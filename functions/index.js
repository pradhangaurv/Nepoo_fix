const admin = require('firebase-admin');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');

admin.initializeApp();
const db = admin.firestore();

const REQUEST_TIMEOUT_MINUTES = 1;

async function sendToUserTokens(userId, { title, body, data = {} }) {
  const userSnap = await db.collection('users').doc(userId).get();
  if (!userSnap.exists) {
    logger.info(`User ${userId} not found`);
    return;
  }

  const userData = userSnap.data() || {};
  const tokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];

  if (tokens.length === 0) {
    logger.info(`No FCM tokens found for user ${userId}`);
    return;
  }

  const invalidTokens = [];

  for (const token of tokens) {
    try {
      await admin.messaging().send({
        token,
        notification: {
          title,
          body,
        },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
        android: {
          priority: 'high',
        },
      });

      logger.info(`Notification sent to user ${userId}`);
    } catch (error) {
      logger.error(`FCM send failed for user ${userId}`, error);

      const code = error?.errorInfo?.code || error?.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        invalidTokens.push(token);
      }
    }
  }

  if (invalidTokens.length > 0) {
    await db.collection('users').doc(userId).set(
      {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    logger.info(`Removed invalid tokens for user ${userId}`);
  }
}

exports.notifyProviderOnBookingCreated = onDocumentCreated(
  {
    document: 'service_requests/{requestId}',
    region: 'us-central1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.warn('No snapshot data found in booking create trigger');
      return;
    }

    const requestId = event.params.requestId;
    const request = snap.data() || {};

    const providerId = request.providerId || '';
    const userName = request.userName || 'Customer';
    const serviceType = request.serviceType || 'Service';

    if (!providerId) {
      logger.warn(`Request ${requestId} has no providerId`);
      return;
    }

    try {
      await sendToUserTokens(providerId, {
        title: 'New booking request',
        body: `${userName} requested ${serviceType}`,
        data: {
          type: 'new_booking',
          requestId,
          providerId,
        },
      });

      await snap.ref.set(
        {
          providerNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      logger.info(`Provider notified for request ${requestId}`);
    } catch (error) {
      logger.error(`Failed to notify provider for request ${requestId}`, error);
    }
  }
);

exports.expirePendingBookings = onSchedule(
  {
    schedule: 'every 1 minutes',
    region: 'us-central1',
    timeZone: 'Asia/Kathmandu',
  },
  async () => {
    try {
      const cutoffMillis =
        Date.now() - REQUEST_TIMEOUT_MINUTES * 60 * 1000;

      const pendingSnap = await db
        .collection('service_requests')
        .where('status', '==', 'pending')
        .get();

      if (pendingSnap.empty) {
        logger.info('No pending bookings found');
        return;
      }

      const expiredDocs = pendingSnap.docs.filter((doc) => {
        const data = doc.data() || {};
        const createdAt = data.createdAt;

        if (!createdAt || typeof createdAt.toMillis !== 'function') {
          logger.info(`Skipping ${doc.id} because createdAt is missing or invalid`);
          return false;
        }

        return createdAt.toMillis() <= cutoffMillis;
      });

      if (expiredDocs.length === 0) {
        logger.info('No expired pending bookings found');
        return;
      }

      for (const doc of expiredDocs) {
        const request = doc.data() || {};
        const requestId = doc.id;
        const userId = request.userId || '';
        const providerId = request.providerId || '';
        const serviceType = request.serviceType || '';

        let wasCancelled = false;

        try {
          await db.runTransaction(async (tx) => {
            const freshSnap = await tx.get(doc.ref);

            if (!freshSnap.exists) {
              logger.info(`Request ${requestId} no longer exists`);
              return;
            }

            const freshData = freshSnap.data() || {};
            const freshStatus = freshData.status || '';
            const freshCreatedAt = freshData.createdAt;

            if (freshStatus !== 'pending') {
              logger.info(`Skipping ${requestId}, status already changed to ${freshStatus}`);
              return;
            }

            if (
              !freshCreatedAt ||
              typeof freshCreatedAt.toMillis !== 'function'
            ) {
              logger.info(`Skipping ${requestId}, createdAt still missing`);
              return;
            }

            if (freshCreatedAt.toMillis() > cutoffMillis) {
              logger.info(`Skipping ${requestId}, not expired yet`);
              return;
            }

            tx.update(doc.ref, {
              status: 'cancelled',
              cancelReason: 'no_provider_response',
              autoCancelledAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            wasCancelled = true;
          });

          if (wasCancelled) {
            if (userId) {
              await sendToUserTokens(userId, {
                title: 'Booking not accepted',
                body: 'No provider accepted your request in time.',
                data: {
                  type: 'booking_expired',
                  requestId,
                },
              });
            }

            logger.info(`Expired pending booking handled: ${requestId}`, {
              providerId,
              serviceType,
            });
          }
        } catch (error) {
          logger.error(`Failed to expire booking ${requestId}`, error);
        }
      }
    } catch (error) {
      logger.error('expirePendingBookings failed', error);
    }
  }
);