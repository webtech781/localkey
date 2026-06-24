// background.js - Forwards requests to the Python Native Host

// Keep service worker alive with a periodic alarm so it's ready for passkey interception
chrome.runtime.onInstalled.addListener(() => {
  chrome.alarms.create('keepAlive', { periodInMinutes: 0.4 });
});
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'keepAlive') {
    // No-op: just keeps the service worker alive
  }
});

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  console.log("LocalKey: received message", request.action);

  if (request.action === "intercept_passkey" || request.action === "autofill_request" || request.action === "auto_save" || request.action === "ping" || request.action === "auto_save_confirm") {
    chrome.runtime.sendNativeMessage('com.localkey.passkey', request, (response) => {
      if (chrome.runtime.lastError) {
        const errMsg = chrome.runtime.lastError.message;
        console.error("LocalKey Native Messaging Error:", errMsg);
        sendResponse({ error: errMsg });
      } else {
        console.log("LocalKey: response from native host", response);
        sendResponse(response);
      }
    });
    // Keep message channel open for async response
    return true;
  }
});
