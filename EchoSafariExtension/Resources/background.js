// Echo Inspector — Background Service Worker

'use strict';

const NATIVE_APP = 'com.echo.extension';
const inspectTabs = new Set();

// ── Native messaging ──────────────────────────────────────────────────────────
// Safari uses one-shot sendNativeMessage (no persistent port from service workers).

async function sendNative(message) {
    try {
        return await browser.runtime.sendNativeMessage(NATIVE_APP, message);
    } catch (e) {
        console.warn('[Echo] Native message failed:', e.message);
        return null;
    }
}

// ── Message router ────────────────────────────────────────────────────────────

browser.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    const tabId = sender?.tab?.id;

    switch (msg.type) {

    case 'CONTENT_READY':
        // Re-activate inspect mode if tab was refreshed mid-session
        if (tabId !== undefined && inspectTabs.has(tabId)) {
            browser.tabs.sendMessage(tabId, { type: 'ACTIVATE_INSPECT' });
        }
        break;

    case 'ELEMENT_SELECTED': {
        browser.storage.local.set({ lastElement: msg.data, lastElementTime: Date.now() });

        sendNative({ type: 'ELEMENT_SELECTED', data: msg.data }).then(response => {
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

    case 'TOGGLE_VOICE':
        sendNative({ type: 'TOGGLE_VOICE', active: msg.active });
        break;

    case 'STATUS_REQUEST': {
        browser.tabs.query({ active: true, currentWindow: true }).then(([tab]) => {
            const active = tab ? inspectTabs.has(tab.id) : false;
            sendNative({ type: 'STATUS_REQUEST' }).then(native => {
                sendResponse({
                    nativeConnected: native?.nativeConnected ?? false,
                    inspectActive:   active,
                });
            });
        });
        return true; // keep channel open for async sendResponse
    }

    case 'VOICE_GUIDANCE_TEXT': {
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

// ── Tab lifecycle ─────────────────────────────────────────────────────────────

browser.tabs.onRemoved.addListener(tabId => inspectTabs.delete(tabId));

browser.tabs.onUpdated.addListener((tabId, info) => {
    if (info.status === 'loading') {
        inspectTabs.delete(tabId);
        browser.storage.local.set({ inspectActive: false });
    }
});
