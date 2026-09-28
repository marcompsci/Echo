// Echo Inspector — Background Service Worker
// Relays messages between content scripts and the native Swift app.

'use strict';

// ── State ─────────────────────────────────────────────────────────────────────

const inspectTabs = new Set();   // tabIds currently in inspect mode

// ── Native Messaging ─────────────────────────────────────────────────────────

// Safari does not support persistent native messaging ports from service workers
// the same way Chrome does. We use sendNativeMessage (one-shot) for each message.
const NATIVE_APP_ID = 'com.echo.extension';

async function sendToNative(message) {
    try {
        return await browser.runtime.sendNativeMessage(NATIVE_APP_ID, message);
    } catch (e) {
        // App may not be open; fall through and use storage as fallback
        console.warn('[Echo] Native message failed:', e.message);
        return null;
    }
}

// ── Message Router ────────────────────────────────────────────────────────────

browser.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    const tabId = sender?.tab?.id;

    switch (msg.type) {

    case 'CONTENT_READY':
        // Content script loaded — nothing to do, state is in inspectTabs
        break;

    case 'ELEMENT_SELECTED': {
        // Store locally so popup can read it without the app
        browser.storage.local.set({ lastElement: msg.data, lastElementTime: Date.now() });

        // Forward to native app
        sendToNative({ type: 'ELEMENT_SELECTED', data: msg.data }).then(response => {
            if (response?.analysis && tabId !== undefined) {
                browser.tabs.sendMessage(tabId, { type: 'SHOW_ANALYSIS', analysis: response.analysis });
                browser.storage.local.set({ lastAnalysis: response.analysis });
            }
        });
        break;
    }

    case 'TOGGLE_INSPECT': {
        browser.tabs.query({ active: true, currentWindow: true }).then(([tab]) => {
            if (!tab) return;
            const id = tab.id;
            const nowActive = !inspectTabs.has(id);
            if (nowActive) {
                inspectTabs.add(id);
                browser.tabs.sendMessage(id, { type: 'ACTIVATE_INSPECT' });
            } else {
                inspectTabs.delete(id);
                browser.tabs.sendMessage(id, { type: 'DEACTIVATE_INSPECT' });
            }
            browser.storage.local.set({ inspectActive: nowActive });
        });
        break;
    }

    case 'TOGGLE_VOICE': {
        sendToNative({ type: 'TOGGLE_VOICE', active: msg.active });
        break;
    }

    case 'STATUS_REQUEST': {
        browser.tabs.query({ active: true, currentWindow: true }).then(([tab]) => {
            const active = tab ? inspectTabs.has(tab.id) : false;
            sendToNative({ type: 'STATUS_REQUEST' }).then(native => {
                sendResponse({
                    nativeConnected: native?.nativeConnected ?? false,
                    inspectActive:   active,
                });
            });
        });
        return true; // keep channel open for async sendResponse
    }

    case 'VOICE_GUIDANCE_TEXT': {
        // Forward voice guidance from native app to active tab
        browser.tabs.query({ active: true, currentWindow: true }).then(([tab]) => {
            if (tab) {
                browser.tabs.sendMessage(tab.id, {
                    type:  'VOICE_GUIDANCE',
                    text:  msg.text,
                    step:  msg.step  ?? 1,
                    total: msg.total ?? 1,
                });
            }
        });
        break;
    }

    }
});

// ── Tab Cleanup ───────────────────────────────────────────────────────────────

browser.tabs.onRemoved.addListener(tabId => inspectTabs.delete(tabId));

browser.tabs.onUpdated.addListener((tabId, info) => {
    // Re-inject content script state after navigation
    if (info.status === 'loading' && inspectTabs.has(tabId)) {
        inspectTabs.delete(tabId);
        browser.storage.local.set({ inspectActive: false });
    }
});
