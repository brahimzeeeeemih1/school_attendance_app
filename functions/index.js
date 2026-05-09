const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendAbsentNotification = functions.firestore
    .document("attendance/{attendanceId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();

      if (!data || data.status !== "absent") {
        return null;
      }

      const studentId = data.studentId;
      const studentName = data.studentName || "التلميذ";
      const date = data.date || "";
      const time = data.time || "";

      const studentDoc = await admin.firestore()
          .collection("students")
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        console.log("Student not found");
        return null;
      }

      const studentData = studentDoc.data();
      const parentId = studentData.parentId;

      if (!parentId) {
        console.log("Parent ID not found");
        return null;
      }

      const parentDoc = await admin.firestore()
          .collection("users")
          .doc(parentId)
          .get();

      if (!parentDoc.exists) {
        console.log("Parent document not found");
        return null;
      }

      const parentData = parentDoc.data();
      const fcmToken = parentData.fcmToken;

      if (!fcmToken) {
        console.log("FCM token not found");
        return null;
      }

      const bodyText =
      `تم تسجيل غياب ${studentName} ` +
      `بتاريخ ${date} على الساعة ${time}`;

      const message = {
        token: fcmToken,
        notification: {
          title: "غياب التلميذ",
          body: bodyText,
        },
        data: {
          type: "attendance_absent",
          studentId: studentId,
          studentName: studentName,
          date: date,
          time: time,
        },
      };

      await admin.messaging().send(message);
      console.log("Absent notification sent successfully");
      return null;
    });

exports.sendBehaviorNotification = functions.firestore
    .document("behavior/{behaviorId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();

      if (!data) {
        return null;
      }

      const studentId = data.studentId;
      const studentName = data.studentName || "التلميذ";
      const date = data.date || "";
      const time = data.time || "";
      const type = data.type || "";
      const title = data.title || "سلوك جديد";

      const studentDoc = await admin.firestore()
          .collection("students")
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        console.log("Student not found");
        return null;
      }

      const studentData = studentDoc.data();
      const parentId = studentData.parentId;

      if (!parentId) {
        console.log("Parent ID not found");
        return null;
      }

      const parentDoc = await admin.firestore()
          .collection("users")
          .doc(parentId)
          .get();

      if (!parentDoc.exists) {
        console.log("Parent document not found");
        return null;
      }

      const parentData = parentDoc.data();
      const fcmToken = parentData.fcmToken;

      if (!fcmToken) {
        console.log("FCM token not found");
        return null;
      }

      const bodyText =
      `تمت إضافة ${title} لـ ${studentName} ` +
      `بتاريخ ${date} على الساعة ${time}`;

      const message = {
        token: fcmToken,
        notification: {
          title: "سلوك جديد للتلميذ",
          body: bodyText,
        },
        data: {
          type: "behavior_note",
          studentId: studentId,
          studentName: studentName,
          behaviorType: type,
          date: date,
          time: time,
        },
      };

      await admin.messaging().send(message);
      console.log("Behavior notification sent successfully");
      return null;
    });
