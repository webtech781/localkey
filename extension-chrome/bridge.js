// bridge.js
// Runs in the ISOLATED world and bridges messages between the MAIN world (content.js) and the background script.

// 1. (Content.js is now injected natively by Manifest V3 in the MAIN world to prevent race conditions)

// 2. Listen for messages from the injected MAIN world script
window.addEventListener("message", (event) => {
    if (event.source !== window) return;

    if (event.data && event.data.type === "VAULTMATE_PASSKEY_REQUEST") {
        const requestId = event.data.requestId;
        chrome.runtime.sendMessage({
            action: "intercept_passkey",
            operation: event.data.operation,
            options: event.data.options,
            url: window.location.href
        }, (response) => {
            if (chrome.runtime.lastError) {
                console.error("VaultMate bridge error:", chrome.runtime.lastError.message);
                window.postMessage({ type: "VAULTMATE_PASSKEY_RESPONSE", requestId, response: { error: chrome.runtime.lastError.message } }, "*");
                return;
            }
            window.postMessage({ type: "VAULTMATE_PASSKEY_RESPONSE", requestId, response: response || { error: "No response from VaultMate host" } }, "*");
        });
    }
});

// ─────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────

// Fires native events so React/Vue/Angular pages detect the value change
function setNativeValue(el, value) {
    const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
    setter.call(el, value);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    el.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true }));
    el.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
}

function findLoginInputs(anchor) {
    // Walk up to the form, or search the whole document
    const container = (anchor && anchor.closest) ? (anchor.closest('form') || document) : document;
    const passInputs = container.querySelectorAll('input[type="password"]');
    const userInputs = container.querySelectorAll('input[type="text"], input[type="email"], input[autocomplete*="username"], input[autocomplete*="email"]');
    return { passInputs, userInputs };
}

// ─────────────────────────────────────────────────────────────────
// 3. Credential Picker Popup (shown on focus of login fields)
// ─────────────────────────────────────────────────────────────────

let pickerEl = null;
let cachedCreds = null;
let cacheUrl = null;

function removePickerEl() {
    if (pickerEl) {
        pickerEl.remove();
        pickerEl = null;
    }
}

function createPickerStyles() {
    if (document.getElementById('vaultmate-styles')) return;
    const style = document.createElement('style');
    style.id = 'vaultmate-styles';
    style.textContent = `
        #vaultmate-picker {
            position: fixed;
            z-index: 2147483647;
            background: #1C1C1E;
            border: 1px solid #3A3A3C;
            border-radius: 12px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.55);
            min-width: 280px;
            max-width: 360px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            overflow: hidden;
            animation: vm-fadein 0.15s ease;
        }
        @keyframes vm-fadein {
            from { opacity: 0; transform: translateY(-6px); }
            to   { opacity: 1; transform: translateY(0); }
        }
        #vaultmate-picker .vm-header {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 10px 14px 8px;
            border-bottom: 1px solid #3A3A3C;
        }
        #vaultmate-picker .vm-logo {
            font-size: 16px;
        }
        #vaultmate-picker .vm-title {
            font-size: 12px;
            font-weight: 600;
            color: #8E8E93;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        #vaultmate-picker .vm-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 11px 14px;
            cursor: pointer;
            transition: background 0.1s;
            border-bottom: 1px solid #2C2C2E;
        }
        #vaultmate-picker .vm-item:last-child {
            border-bottom: none;
        }
        #vaultmate-picker .vm-item:hover {
            background: #2C2C2E;
        }
        #vaultmate-picker .vm-avatar {
            width: 34px;
            height: 34px;
            border-radius: 50%;
            background: linear-gradient(135deg, #007AFF, #5856D6);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 15px;
            color: white;
            flex-shrink: 0;
        }
        #vaultmate-picker .vm-info {
            flex: 1;
            min-width: 0;
        }
        #vaultmate-picker .vm-name {
            font-size: 13px;
            font-weight: 600;
            color: #F2F2F7;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        #vaultmate-picker .vm-user {
            font-size: 11px;
            color: #8E8E93;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        #vaultmate-picker .vm-fill-badge {
            font-size: 10px;
            color: #30D158;
            background: rgba(48,209,88,0.12);
            padding: 2px 7px;
            border-radius: 10px;
            font-weight: 600;
            flex-shrink: 0;
        }
    `;
    document.head.appendChild(style);
}

function showPicker(anchorEl, credentials) {
    removePickerEl();
    createPickerStyles();

    const picker = document.createElement('div');
    picker.id = 'vaultmate-picker';

    // Header
    const header = document.createElement('div');
    header.className = 'vm-header';
    header.innerHTML = '<span class="vm-logo">🔐</span><span class="vm-title">VaultMate — Saved Credentials</span>';
    picker.appendChild(header);

    // Credential items
    credentials.forEach(cred => {
        const item = document.createElement('div');
        item.className = 'vm-item';

        const initial = (cred.username || cred.name || '?')[0].toUpperCase();
        item.innerHTML = `
            <div class="vm-avatar">${initial}</div>
            <div class="vm-info">
                <div class="vm-name">${escapeHtml(cred.name || cred.username)}</div>
                <div class="vm-user">${escapeHtml(cred.username)}</div>
            </div>
            <div class="vm-fill-badge">Fill</div>
        `;

        item.addEventListener('mousedown', (e) => {
            e.preventDefault(); // prevent input blur before fill
            fillCredential(anchorEl, cred);
            removePickerEl();
        });
        picker.appendChild(item);
    });

    document.body.appendChild(picker);
    pickerEl = picker;

    // Position below the anchor input
    positionPicker(anchorEl, picker);
}

function positionPicker(anchorEl, picker) {
    const rect = anchorEl.getBoundingClientRect();
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const pickerH = picker.offsetHeight || 200;
    const pickerW = picker.offsetWidth || 300;

    let top = rect.bottom + 6;
    let left = rect.left;

    // Flip up if not enough room below
    if (top + pickerH > vh - 20) top = rect.top - pickerH - 6;
    // Keep within viewport horizontally
    if (left + pickerW > vw - 12) left = vw - pickerW - 12;
    if (left < 6) left = 6;

    picker.style.top = `${top}px`;
    picker.style.left = `${left}px`;
}

function escapeHtml(str) {
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function fillCredential(anchorEl, cred) {
    const { passInputs, userInputs } = findLoginInputs(anchorEl);

    if (userInputs.length > 0) {
        const target = anchorEl.type === 'password' ? userInputs[0] : anchorEl;
        setNativeValue(target, cred.username);
        // Try the first visible user input if anchor was password
        if (anchorEl.type === 'password') setNativeValue(userInputs[0], cred.username);
    }
    if (passInputs.length > 0) {
        setNativeValue(passInputs[passInputs.length - 1], cred.password);
    }
}

function fetchAndShowPicker(inputEl) {
    const url = window.location.href;

    // Use cached creds if URL hasn't changed
    if (cachedCreds !== null && cacheUrl === url) {
        if (cachedCreds.length > 0) showPicker(inputEl, cachedCreds);
        return;
    }

    chrome.runtime.sendMessage({ action: "autofill_request", url }, (response) => {
        if (chrome.runtime.lastError) return;
        if (response && response.status === "success" && response.credentials && response.credentials.length > 0) {
            cachedCreds = response.credentials;
            cacheUrl = url;
            showPicker(inputEl, cachedCreds);
        } else {
            cachedCreds = [];
            cacheUrl = url;
        }
    });
}

// Show picker when a login field gains focus
document.addEventListener('focusin', (e) => {
    const el = e.target;
    if (!el || el.tagName !== 'INPUT') return;
    const type = el.type ? el.type.toLowerCase() : 'text';
    if (type === 'password' || type === 'text' || type === 'email') {
        fetchAndShowPicker(el);
    }
}, true);

// Hide picker when clicking outside
document.addEventListener('mousedown', (e) => {
    if (pickerEl && !pickerEl.contains(e.target)) {
        removePickerEl();
    }
}, true);

// Hide picker on Escape
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') removePickerEl();
}, true);

// ─────────────────────────────────────────────────────────────────
// 4. Auto-Save Logic (on form submit / button click)
// ─────────────────────────────────────────────────────────────────

function captureAndSave(formOrElement) {
    const container = (formOrElement && formOrElement.closest) ? (formOrElement.closest('form') || document) : document;
    const passwordInputs = container.querySelectorAll('input[type="password"]');
    if (passwordInputs.length === 0) return;

    const passwordInput = passwordInputs[passwordInputs.length - 1];
    if (passwordInput && passwordInput.value && passwordInput.value.length >= 3) {
        let username = "";
        const userInputs = container.querySelectorAll('input[type="text"], input[type="email"]');
        if (userInputs.length > 0) username = userInputs[0].value;

        chrome.runtime.sendMessage({
            action: "auto_save",
            url: window.location.href,
            name: document.title || window.location.hostname,
            username: username.trim(),
            password: passwordInput.value
        });

        // Invalidate cache after save
        cachedCreds = null;
    }
}

document.addEventListener('submit', (e) => { captureAndSave(e.target); }, true);

document.addEventListener('click', (e) => {
    if (e.target.tagName === 'BUTTON' || (e.target.tagName === 'INPUT' && (e.target.type === 'submit' || e.target.type === 'button'))) {
        captureAndSave(e.target);
    }
}, true);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && e.target.tagName === 'INPUT' && e.target.type === 'password') {
        captureAndSave(e.target);
    }
}, true);
