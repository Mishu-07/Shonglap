const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendChatNotification = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const senderId = message.senderId;
    const text = message.text || "Sent an image";

    const chatDoc = await admin.firestore().collection("chats").doc(context.params.chatId).get();
    const participants = chatDoc.data().participants;

    const recipientId = participants.find((id) => id !== senderId);

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const recipientDoc = await admin.firestore().collection("users").doc(recipientId).get();

    const senderName = senderDoc.data().name;
    const recipientToken = recipientDoc.data().fcmToken;

    if (!recipientToken) {
      console.log("Recipient does not have a FCM token.");
      return;
    }

    const payload = {
      notification: {
        title: `New message from ${senderName}`,
        body: text,
        sound: "default",
      },
      data: {
        "chatId": context.params.chatId,
      },
    };

    return admin.messaging().sendToDevice(recipientToken, payload);
  });