// Echo Inspector — Popup Script

let inspectActive = false;
let voiceActive   = false;

// ── Init ─────────────────────────────────────────────────────────────────────

async function init() {
    // Load persisted state from storage
    const stored = await browser.storage.local.get(['lastElement', 'lastAnalysis', 'inspectActive']);
    if (stored.inspectActive) {
        inspectActive = true;
        updateInspectButton();
    }

    // Request live status from background
    try {
        const status = await browser.runtime.sendMessage({ type: 'STATUS_REQUEST' });
        setStatus(status?.nativeConnected ?? false);
    } catch {
        setStatus(false);
    }

    if (stored.lastElement) {
        showElement(stored.lastElement, stored.lastAnalysis);
    }

    // Watch for storage updates while popup is open
    browser.storage.onChanged.addListener((changes) => {
        if (changes.lastElement?.newValue)  showElement(changes.lastElement.newValue, null);
        if (changes.lastAnalysis?.newValue) updateAnalysis(changes.lastAnalysis.newValue);
        if (changes.inspectActive !== undefined) {
            inspectActive = changes.inspectActive.newValue;
            updateInspectButton();
        }
    });
}

// ── Status ───────────────────────────────────────────────────────────────────

function setStatus(connected) {
    const dot  = document.getElementById('statusDot');
    const text = document.getElementById('statusText');
    dot.className  = connected ? 'dot on' : 'dot';
    text.textContent = connected ? 'Connected to Echo' : 'Open Echo app to connect';
}

// ── Inspect Toggle ────────────────────────────────────────────────────────────

async function toggleInspect() {
    await browser.runtime.sendMessage({ type: 'TOGGLE_INSPECT' });
    // State update comes back via storage.onChanged
}

function updateInspectButton() {
    const btn = document.getElementById('inspectBtn');
    if (inspectActive) {
        btn.textContent = '✕  Stop Inspecting';
        btn.classList.add('active');
    } else {
        btn.textContent = '◈  Start Inspecting';
        btn.classList.remove('active');
    }
}

// ── Voice Toggle ──────────────────────────────────────────────────────────────

async function toggleVoice() {
    voiceActive = !voiceActive;
    await browser.runtime.sendMessage({ type: 'TOGGLE_VOICE', active: voiceActive });
    const btn = document.getElementById('voiceBtn');
    if (voiceActive) {
        btn.textContent = '🔴 Stop Guide';
        btn.classList.add('active');
    } else {
        btn.textContent = '🎙 Guide';
        btn.classList.remove('active');
    }
}

// ── Open App ──────────────────────────────────────────────────────────────────

function openApp() {
    // Deep link into the Echo app (requires URL scheme configured in Info.plist)
    browser.tabs.create({ url: 'echo://open' });
}

// ── Element Display ───────────────────────────────────────────────────────────

function showElement(el, analysis) {
    document.getElementById('emptyState').style.display = 'none';
    document.getElementById('analysis').style.display   = 'block';

    const tag = (el.tagName || 'UNKNOWN').toLowerCase();
    const id  = el.id      ? `#${el.id}` : '';
    const cls = el.className
        ? '.' + el.className.split(' ').filter(Boolean).slice(0, 2).join('.')
        : '';

    document.getElementById('elemTag').textContent = `<${tag}>`;
    document.getElementById('elemSub').textContent = `${id}${cls}` || 'no id or class';

    if (analysis) updateAnalysis(analysis);
}

function updateAnalysis(analysis) {
    const suggEl = document.getElementById('suggestions');
    const insgEl = document.getElementById('insights');
    suggEl.innerHTML = '';
    insgEl.innerHTML = '';

    const { suggestions = [], insights = [] } = analysis;

    if (suggestions.length) {
        const label = document.createElement('div');
        label.className = 'label';
        label.textContent = 'Suggestions';
        suggEl.appendChild(label);
        suggestions.slice(0, 3).forEach(s => {
            const d = document.createElement('div');
            d.className = 'row-suggest';
            d.textContent = s;
            suggEl.appendChild(d);
        });
    }

    if (insights.length) {
        const label = document.createElement('div');
        label.className = 'label';
        label.textContent = 'Insights';
        insgEl.appendChild(label);
        insights.slice(0, 3).forEach(i => {
            const d = document.createElement('div');
            d.className = 'row-insight';
            d.textContent = i;
            insgEl.appendChild(d);
        });
    }
}

// ── Start ─────────────────────────────────────────────────────────────────────

init();
