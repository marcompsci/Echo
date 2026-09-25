// Echo Inspector — Content Script
// Injected into every page. Provides the element picker overlay and voice guidance UI.

(function () {
    'use strict';

    if (window.__echoInjected) return;
    window.__echoInjected = true;

    let inspectActive = false;
    let selectedElement = null;

    // ── Create overlay DOM elements ───────────────────────────────────────────

    const highlight = document.createElement('div');
    highlight.id = '__echo_highlight__';
    highlight.style.display = 'none';   // initial state via JS (CSS has no !important here)
    document.documentElement.appendChild(highlight);

    const tooltip = document.createElement('div');
    tooltip.id = '__echo_tooltip__';
    tooltip.style.display = 'none';
    document.documentElement.appendChild(tooltip);

    // ── Utilities ─────────────────────────────────────────────────────────────

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

    // ── Overlay positioning ───────────────────────────────────────────────────

    function positionHighlight(el) {
        const r = el.getBoundingClientRect();
        highlight.style.display = 'block';
        highlight.style.left   = `${r.left}px`;
        highlight.style.top    = `${r.top}px`;
        highlight.style.width  = `${r.width}px`;
        highlight.style.height = `${r.height}px`;
    }

    function positionTooltip(el, html) {
        tooltip.innerHTML = html;
        tooltip.style.display = 'block';
        const r = el.getBoundingClientRect();
        let top  = r.bottom + 10;
        let left = r.left;
        if (top + 130 > window.innerHeight) top = Math.max(8, r.top - 140);
        if (left + 360 > window.innerWidth)  left = Math.max(8, window.innerWidth - 368);
        tooltip.style.top  = `${top}px`;
        tooltip.style.left = `${left}px`;
    }

    function hideOverlays() {
        highlight.style.display = 'none';
        tooltip.style.display   = 'none';
    }

    // ── Tooltip templates ─────────────────────────────────────────────────────

    function hoverHTML(el) {
        const tag = el.tagName.toLowerCase();
        const id  = el.id ? `<span style="color:#94a3b8"> #${el.id}</span>` : '';
        const cls = el.className
            ? `<span style="color:#64748b"> .${String(el.className).split(' ').filter(Boolean).slice(0, 2).join('.')}</span>`
            : '';
        return `<div style="color:#6366f1;font-weight:700;margin-bottom:4px">&lt;${tag}&gt;${id}${cls}</div>
                <div style="color:#475569;font-size:11px">Click to inspect &nbsp;◈</div>`;
    }

    function analysisHTML({ classification, insights, suggestions }) {
        let html = `<div style="color:#6366f1;font-weight:700;margin-bottom:6px">◈ ${classification || 'Element'}</div>`;
        if (insights?.length) {
            html += insights.slice(0, 3).map(i =>
                `<div style="color:#c7d2fe;font-size:11px;margin:2px 0">• ${i}</div>`
            ).join('');
        }
        if (suggestions?.length) {
            html += `<div style="color:#f59e0b;font-size:11px;margin-top:6px;font-weight:600">Suggestions</div>`;
            html += suggestions.slice(0, 3).map(s =>
                `<div style="color:#fde68a;font-size:11px;margin:2px 0">⚠ ${s}</div>`
            ).join('');
        }
        return html;
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    function onMouseMove(e) {
        const el = e.target;
        if (el === highlight || el === tooltip || el.id === '__echo_guidance__') return;
        positionHighlight(el);
        positionTooltip(el, hoverHTML(el));
    }

    function onClick(e) {
        const el = e.target;
        if (el === highlight || el === tooltip || el.id === '__echo_guidance__') return;
        e.preventDefault();
        e.stopPropagation();
        selectedElement = el;

        positionTooltip(el, `
            <div style="color:#6366f1;font-weight:700">Analyzing…</div>
            <div style="color:#94a3b8;font-size:11px">&lt;${el.tagName.toLowerCase()}&gt;</div>
        `);

        browser.runtime.sendMessage({ type: 'ELEMENT_SELECTED', data: extractElementData(el) });
    }

    function onKeyDown(e) {
        if (e.key === 'Escape') deactivate();
    }

    // ── Inspect mode ──────────────────────────────────────────────────────────

    function activate() {
        if (inspectActive) return;
        inspectActive = true;
        document.body.classList.add('__echo_inspect__');
        document.addEventListener('mousemove', onMouseMove, true);
        document.addEventListener('click',     onClick,     true);
        document.addEventListener('keydown',   onKeyDown,   true);
    }

    function deactivate() {
        if (!inspectActive) return;
        inspectActive = false;
        document.body.classList.remove('__echo_inspect__');
        document.removeEventListener('mousemove', onMouseMove, true);
        document.removeEventListener('click',     onClick,     true);
        document.removeEventListener('keydown',   onKeyDown,   true);
        hideOverlays();
    }

    // ── Voice guidance banner ─────────────────────────────────────────────────

    function showGuidance(text, step, total) {
        let el = document.getElementById('__echo_guidance__');
        if (!el) {
            el = document.createElement('div');
            el.id = '__echo_guidance__';
            document.documentElement.appendChild(el);
        }
        const stepLabel = total > 1 ? ` &nbsp;•&nbsp; Step ${step}/${total}` : '';
        el.innerHTML = `
            <div style="color:#6366f1;font-size:11px;font-weight:700;letter-spacing:.06em;margin-bottom:6px">
                ECHO GUIDE${stepLabel}
            </div>
            <div style="font-size:14px">${text}</div>`;
        el.style.display = 'block';
        clearTimeout(el.__echoTimer);
        el.__echoTimer = setTimeout(() => { el.style.display = 'none'; }, 8000);
    }

    // ── Message listener ──────────────────────────────────────────────────────

    browser.runtime.onMessage.addListener((msg) => {
        switch (msg.type) {
        case 'ACTIVATE_INSPECT':   activate();   break;
        case 'DEACTIVATE_INSPECT': deactivate(); break;
        case 'SHOW_ANALYSIS':
            if (selectedElement) positionTooltip(selectedElement, analysisHTML(msg.analysis));
            break;
        case 'VOICE_GUIDANCE':
            showGuidance(msg.text, msg.step ?? 1, msg.total ?? 1);
            break;
        }
    });

    browser.runtime.sendMessage({ type: 'CONTENT_READY', url: window.location.href });

})();
