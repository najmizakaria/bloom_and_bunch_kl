/* Generated public Firebase configuration is injected by the web build. */
importScripts('https://www.gstatic.com/firebasejs/12.18.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.18.0/firebase-messaging-compat.js');
importScripts('/firebase-messaging-config.js');
firebase.initializeApp(self.bloomFirebaseConfig);
firebase.messaging();
