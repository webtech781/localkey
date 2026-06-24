// background.js - Forwards requests to the Python Native Host

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  console.log("Sending request to LocalKey Native Host...", request.action);
  
  chrome.runtime.sendNativeMessage('com.localkey.passkey', request, (response) => {
    if (chrome.runtime.lastError) {
      console.error("Native Messaging Error: ", chrome.runtime.lastError.message);
      sendResponse({ error: "LocalKey application is not running or not installed correctly." });
    } else {
      console.log("Received response from LocalKey:", response);
      sendResponse(response);
    }
  });
  
  // Return true to indicate we wish to send a response asynchronously
  return true;
});
