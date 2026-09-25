// Echo Inspector — Popup Script

let inspectActive = false;
let voiceActive   = false;

// ── Init ──────────────────────────────────────────────────────────────────────

async function init() {
    const stored = await browser.storage.local.get(['lastElement', 'lastAnalysis', 'inspectActive']);

    if (stored.inspectActive) {
        inspectActive = true;
        updateInspectBtn();
    }

    try {
        const status = await browser.runtime.sendMessage({ type: 'STATUS_REQUEST' });
        setStatus(status?.nativeConnected ?? false);
    } catch {
        setStatus(false);
    }

    if (stored.lastElement) showElement(stored.lastElement, stored.lastAnalysis ?? null);

    browser.storage.onChanged.addListener((changes) => {
        if (changes.lastElement?.newValue)  showElement(changes.lastElement.newValue, null);
        if (changes.lastAnalysis?.newValue) fillAnalysis(changes.lastAnalysis.newValue);
        if (changes.inspectActive !== undefined) {
            inspectActive = changes.inspectActive.newValue;
            updateInspectBtn();
        }
    });
}

// ── Status ────────────────────────────────────────────────────────────────────

function setStatus(connected) {
    document.getElementById('statusDot').className   = connected ? 'dot on' : 'dot';
    document.getElementById('statusText').textContent = connected
        ? 'Connected to Echo app'
        : 'Open Echo app to connect';
}

// ── Inspect toggle ────────────────────────────────────────────────────────────

async function toggleInspect() {
    await browser.runtime.sendMessage({ type: 'TOGGLE_INSPECT' });
}

function updateInspectBtn() {
    const btn = document.getElementById('inspectBtn');
    btn.textContent = inspectActive ? '✕  Stop Inspecting' : '◈  Start Inspecting';
    btn.classList.toggle('active', inspectActive);
}

// ── Voice toggle ──────────────────────────────────────────────────────────────

async function toggleVoice() {
    voiceActive = !voiceActive;
    await browser.runtime.sendMessage({ type: 'TOGGLE_VOICE', active: voiceActive });
    const btn = document.getElementById('voiceBtn');
    btn.textContent = voiceActive ? '🔴 Stop Guide' : '🎙 Guide';
    btn.classList.toggle('active', voiceActive);
}

// ── Deep link ─────────────────────────────────────────────────────────────────

function openApp() {
    browser.tabs.create({ url: 'echo://open' });
}

// ── Element display ───────────────────────────────────────────────────────────

function showElement(el, analysis) {
    document.getElementById('emptyState').style.display = 'none';
    document.getElementById('analysis').style.display   = 'block';

    const tag = (el.tagName || 'UNKNOWN').toLowerCase();
    const id  = el.id ? `#${el.id}` : '';
    const cls = el.className
        ? '.' + el.className.split(' ').filter(Boolean).slice(0, 2).join('.')
        : '';

    document.getElementById('elTag').textContent = `<${tag}>`;
    document.getElementById('elSub').textContent = `${id}${cls}` || 'no id or class';

    if (analysis) fillAnalysis(analysis);
}

function fillAnalysis(analysis) {
    const sEl = document.getElementById('suggestions');
    const iEl = document.getElementById('insights');
    sEl.innerHTML = '';
    iEl.innerHTML = '';

    const { suggestions = [], insights = [] } = analysis;

    if (suggestions.length) {
        const lbl = document.createElement('div');
        lbl.className = 'label';
        lbl.textContent = 'Suggestions';
        sEl.appendChild(lbl);
        suggestions.slice(0, 3).forEach(s => {
            const d = document.createElement('div');
            d.className = 'row-s';
            d.textContent = s;
            sEl.appendChild(d);
        });
    }

    if (insights.length) {
        const lbl = document.createElement('div');
        lbl.className = 'label';
        lbl.textContent = 'Insights';
        iEl.appendChild(lbl);
        insights.slice(0, 3).forEach(i => {
            const d = document.createElement('div');
            d.className = 'row-i';
            d.textContent = i;
            iEl.appendChild(d);
        });
    }
}

// Make toggle functions available to onclick attributes
window.toggleInspect = toggleInspect;
window.toggleVoice   = toggleVoice;
window.openApp       = openApp;

init();
