// Echo Inspector — Content Script
// Injected into all pages to provide element picking and overlay UI.

(function () {
    'use strict';

    if (window.__echoInjected) return;
    window.__echoInjected = true;

    let inspectActive = false;
    let selectedElement = null;

    // ── DOM Elements ────────────────────────────────────────────────────────────

    const highlight = document.createElement('div');
    highlight.id = '__echo_highlight__';
    document.documentElement.appendChild(highlight);

    const tooltip = document.createElement('div');
    tooltip.id = '__echo_tooltip__';
    document.documentElement.appendChild(tooltip);

    // ── Utilities ────────────────────────────────────────────────────────────────

    function getXPath(el) {
        if (el.id) return `//*[@id="${el.id}"]`;
        const parts = [];
        let node = el;
        while (node && node.nodeType === Node.ELEMENT_NODE) {
            let idx = 1;
            let sib = node.previousSibling;
            while (sib) {
                if (sib.nodeType === Node.ELEMENT_NODE && sib.nodeName === node.nodeName) idx++;
                sib = sib.previousSibling;
            }
            parts.unshift(`${node.nodeName.toLowerCase()}[${idx}]`);
            node = node.parentNode;
        }
        return `/${parts.join('/')}`;
    }

    function getComputedStyles(el) {
        const cs = window.getComputedStyle(el);
        const props = ['color', 'background-color', 'font-size', 'font-family', 'font-weight',
            'display', 'position', 'width', 'height', 'margin', 'padding',
            'border', 'border-radius', 'z-index', 'opacity', 'visibility',
            'overflow', 'flex-direction', 'align-items', 'justify-content',
            'grid-template-columns', 'box-shadow', 'text-align', 'line-height'];
        const result = {};
        props.forEach(p => { result[p] = cs.getPropertyValue(p); });
        return result;
    }

    function getAttributes(el) {
        const attrs = {};
        Array.from(el.attributes).forEach(a => { attrs[a.name] = a.value; });
        return attrs;
    }

    function extractElementData(el) {
        const rect = el.getBoundingClientRect();
        return {
            tagName:     el.tagName,
            id:          el.id || '',
            className:   typeof el.className === 'string' ? el.className : '',
            innerText:   (el.innerText || '').trim().substring(0, 600),
            outerHTML:   el.outerHTML.substring(0, 3000),
            xpath:       getXPath(el),
            attributes:  getAttributes(el),
            computedCSS: getComputedStyles(el),
            bounds:      { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
            pageURL:     window.location.href,
            pageTitle:   document.title,
        };
    }

    // ── Overlay Positioning ──────────────────────────────────────────────────────

    function positionHighlight(el) {
        const r = el.getBoundingClientRect();
        Object.assign(highlight.style, {
            display: 'block',
            left:    `${r.left}px`,
            top:     `${r.top}px`,
            width:   `${r.width}px`,
            height:  `${r.height}px`,
        });
    }

    function positionTooltip(el, html) {
        tooltip.innerHTML = html;
        tooltip.style.display = 'block';
        const r = el.getBoundingClientRect();
        let top  = r.bottom + 10;
        let left = r.left;
        if (top + 120 > window.innerHeight) top = Math.max(8, r.top - 120);
        if (left + 360 > window.innerWidth)  left = Math.max(8, window.innerWidth - 368);
        tooltip.style.top  = `${top}px`;
        tooltip.style.left = `${left}px`;
    }

    function hideOverlays() {
        highlight.style.display = 'none';
        tooltip.style.display   = 'none';
    }

    // ── Tooltip Templates ────────────────────────────────────────────────────────

    function hoverTooltipHTML(el) {
        const tag = el.tagName.toLowerCase();
        const id  = el.id ? `<span style="color:#94a3b8">#${el.id}</span>` : '';
        const cls = el.className
            ? `<span style="color:#64748b">.${String(el.className).split(' ').slice(0, 2).join('.')}</span>`
            : '';
        return `<div style="color:#6366f1;font-weight:700;margin-bottom:3px">&lt;${tag}&gt; ${id}${cls}</div>
                <div style="color:#475569;font-size:11px">Click to inspect ◈</div>`;
    }

    function analysisTooltipHTML(analysis) {
        const { classification, insights, suggestions } = analysis;
        let html = `<div style="color:#6366f1;font-weight:700;margin-bottom:6px">◈ ${classification || 'Element'}</div>`;
        if (insights && insights.length) {
            html += insights.slice(0, 3).map(i =>
                `<div style="color:#c7d2fe;font-size:11px;margin:2px 0">• ${i}</div>`
            ).join('');
        }
        if (suggestions && suggestions.length) {
            html += `<div style="color:#f59e0b;font-size:11px;margin-top:6px;font-weight:600">Suggestions</div>`;
            html += suggestions.slice(0, 3).map(s =>
                `<div style="color:#fde68a;font-size:11px;margin:2px 0">⚠ ${s}</div>`
            ).join('');
        }
        return html;
    }

    // ── Event Listeners ──────────────────────────────────────────────────────────

    function onMouseMove(e) {
        const el = e.target;
        if (el === highlight || el === tooltip) return;
        positionHighlight(el);
        positionTooltip(el, hoverTooltipHTML(el));
    }

    function onClick(e) {
        const el = e.target;
        if (el === highlight || el === tooltip) return;
        e.preventDefault();
        e.stopPropagation();
        selectedElement = el;

        positionTooltip(el, `<div style="color:#6366f1;font-weight:700">Analyzing...</div>
                              <div style="color:#94a3b8;font-size:11px">&lt;${el.tagName.toLowerCase()}&gt;</div>`);

        const data = extractElementData(el);
        browser.runtime.sendMessage({ type: 'ELEMENT_SELECTED', data });
    }

    function onKeyDown(e) {
        if (e.key === 'Escape' && inspectActive) deactivate();
    }

    // ── Activation ───────────────────────────────────────────────────────────────

    function activate() {
        inspectActive = true;
        document.body.classList.add('__echo_inspect_mode__');
        document.addEventListener('mousemove', onMouseMove, true);
        document.addEventListener('click',     onClick,     true);
        document.addEventListener('keydown',   onKeyDown,   true);
    }

    function deactivate() {
        inspectActive = false;
        document.body.classList.remove('__echo_inspect_mode__');
        document.removeEventListener('mousemove', onMouseMove, true);
        document.removeEventListener('click',     onClick,     true);
        document.removeEventListener('keydown',   onKeyDown,   true);
        hideOverlays();
    }

    // ── Voice Guidance Overlay ───────────────────────────────────────────────────

    function showGuidanceOverlay(text, step, total) {
        let el = document.getElementById('__echo_guidance__');
        if (!el) {
            el = document.createElement('div');
            el.id = '__echo_guidance__';
            document.documentElement.appendChild(el);
        }
        el.innerHTML = `
            <div style="color:#6366f1;font-size:11px;font-weight:600;margin-bottom:6px;letter-spacing:.05em">
                ECHO GUIDE ${total > 1 ? `• Step ${step}/${total}` : ''}
            </div>
            <div style="font-size:14px">${text}</div>`;
        el.style.display = 'block';
        setTimeout(() => { el.style.display = 'none'; }, 8000);
    }

    // ── Message Listener ─────────────────────────────────────────────────────────

    browser.runtime.onMessage.addListener((msg) => {
        switch (msg.type) {
        case 'ACTIVATE_INSPECT':   activate();   break;
        case 'DEACTIVATE_INSPECT': deactivate(); break;
        case 'SHOW_ANALYSIS':
            if (selectedElement) positionTooltip(selectedElement, analysisTooltipHTML(msg.analysis));
            break;
        case 'VOICE_GUIDANCE':
            showGuidanceOverlay(msg.text, msg.step ?? 1, msg.total ?? 1);
            break;
        }
    });

    // Signal ready
    browser.runtime.sendMessage({ type: 'CONTENT_READY', url: window.location.href });

})();
