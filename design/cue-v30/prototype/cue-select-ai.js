(function () {
  const MONO = "ui-monospace,'SF Mono',Menlo,monospace", V = '#B4A7FF', VS = '#E4DEFF', Y = '#FFD60A';
  const KNOWN = {
    'no emails, no scrolling, just water and daylight.': { Rewrite: ['No inbox, no feed. Just water and some daylight.', 'Nothing on a screen. Water first, then daylight.'], Shorter: ['Just water and daylight.'], Punchier: ['No emails. No scrolling. Water. Daylight.'], 'More me': ['Real talk: no emails, no scrolling. Just water and daylight.'] },
    'three tiny habits completely changed my mornings.': { Rewrite: ['Three small habits turned my mornings around.', 'My mornings changed because of three tiny habits.'], Shorter: ['Three habits fixed my mornings.'], Punchier: ['Three tiny habits. Completely new mornings.'], 'More me': ['Okay, three tiny habits. My mornings? Totally different.'] },
    'one: no phone for the first twenty minutes.': { Rewrite: ['First: my phone stays off for twenty minutes.', 'One: the first twenty minutes are phone-free.'], Shorter: ['One: no phone for 20 minutes.'], Punchier: ['One: no phone. Twenty minutes.'], 'More me': ['One, and this is the big one: no phone for twenty minutes.'] },
    'two: i write down one thing that would make today a win.': { Rewrite: ['Two: I pick one thing that would make today a win.', 'Two: one line on paper. What makes today a win?'], Shorter: ['Two: I write down today’s one win.'], Punchier: ['Two: one win. Written down. Every day.'], 'More me': ['Two: I grab a pen and write the one thing that makes today a win.'] }
  };
  const SYN = [[/\bcompletely\b/i, 'totally'], [/\bchanged\b/i, 'transformed'], [/\btiny\b/i, 'small'], [/\bthing\b/i, 'step'], [/\balways\b/i, 'every time'], [/\breally\b/i, 'honestly'], [/\bstart\b/i, 'kick off'], [/\bjust\b/i, 'simply'], [/\bkeep\b/i, 'hold on to'], [/\bhonest answer\b/i, 'truth is']];
  const cap = s => s.charAt(0).toUpperCase() + s.slice(1), low = s => s.charAt(0).toLowerCase() + s.slice(1);
  const end = s => /[.!?…]$/.test(s) ? s : s + '.';
  const gen = (kind, s, n) => {
    const core = s.trim(), k = KNOWN[core.toLowerCase()];
    if (k && k[kind]) return k[kind][n % k[kind].length];
    const bare = core.replace(/[.!?…]+$/, ''), w = bare.split(/\s+/);
    if (kind === 'Shorter') { if (w.length <= 4) return end(bare); return end(w.slice(0, Math.max(3, Math.ceil(w.length * 0.55))).join(' ').replace(/[,;:—-]+$/, '')); }
    if (kind === 'Punchier') { let p = bare.split(/,\s*|\s+—\s+|;\s*|\s+and\s+/i).filter(Boolean); if (p.length < 2 && w.length > 5) p = [w.slice(0, Math.ceil(w.length / 2)).join(' '), w.slice(Math.ceil(w.length / 2)).join(' ')]; return p.map((x, i) => i ? cap(x.trim()) : x.trim()).join('. ') + '.'; }
    if (kind === 'More me') return n % 2 ? 'Honestly? ' + end(low(bare)) : 'Okay, real talk: ' + end(low(bare));
    let out = bare, hit = 0; for (const [re, r] of SYN) { if (re.test(out) && hit < 2) { out = out.replace(re, r); hit++; } }
    if (n % 2 || !hit) out = (n % 2 ? 'Here’s the thing: ' : 'Honestly, ') + low(out);
    return end(out);
  };

  window.CueSelectAI = function (doc, ctx, id) {
    if (doc.__selAI) return; doc.__selAI = 1;
    const win = doc.defaultView;
    const css = doc.createElement('style');
    css.textContent = '.__sab{position:fixed;z-index:70;height:40px;padding:0 4px;border-radius:20px;background:rgba(22,20,52,0.97);box-shadow:inset 0 0 0 0.5px rgba(180,167,255,0.45),0 12px 30px rgba(0,0,0,0.5);display:flex;align-items:center;gap:2px;white-space:nowrap;color:' + VS + ';font-size:13.5px;font-weight:600;animation:__sabIn .16s ease-out}' +
      '@keyframes __sabIn{from{opacity:0;transform:translateY(4px)}to{opacity:1;transform:none}}' +
      '.__sab>[data-k]{height:32px;padding:0 10px;border-radius:16px;display:flex;align-items:center;gap:5px;cursor:pointer;-webkit-user-select:none;user-select:none}' +
      '.__sab>[data-k].pri{background:rgba(157,140,255,0.3)}.__sab>[data-k].dim{color:rgba(225,228,245,0.75);font-weight:500}.__sab .sep{width:0.5px;height:18px;background:rgba(180,167,255,0.4)}' +
      '.__sab.busy>[data-k]{opacity:.35}.__sab .busyL{font-family:' + MONO + ';font-size:10.5px;letter-spacing:.08em;padding:0 10px;background:linear-gradient(90deg,rgba(180,167,255,.35),#fff,rgba(180,167,255,.35));background-size:160px 100%;-webkit-background-clip:text;background-clip:text;color:transparent;animation:__sabSh 1s linear infinite}@keyframes __sabSh{0%{background-position:-160px 0}100%{background-position:160px 0}}' +
      '.__ai{color:' + VS + ';background:rgba(157,140,255,0.16);border-radius:4px;box-shadow:0 0 0 2px rgba(157,140,255,0.16)}.__ai.cut{color:rgba(225,228,245,0.4);text-decoration:line-through;background:none;box-shadow:none}' +
      '.__sakb{display:inline-flex;align-items:center;gap:5px;height:30px;padding:0 11px;border-radius:15px;background:rgba(157,140,255,0.22);box-shadow:inset 0 0 0 0.5px rgba(196,184,255,0.45);color:' + VS + ';font-size:13px;font-weight:600;cursor:pointer;flex-shrink:0;white-space:nowrap}';
    doc.head.appendChild(css);
    const eds = () => [...doc.querySelectorAll('[contenteditable="true"]')].filter(e => !e.closest('.__shwrap'));
    const inEd = n => { const el = n && (n.nodeType === 1 ? n : n.parentElement); return el && el.closest && el.closest('[contenteditable="true"]'); };
    const toast = m => ctx.props.onAction && ctx.props.onAction(ctx.props.id, ['__toast'], { x: 0, y: 0, msg: m });
    let bar = null, saved = null, pending = null, hinted = false;
    const kill = () => { if (bar) bar.remove(); bar = null; };
    const place = (el, r) => { const w = el.offsetWidth, x = Math.max(8, Math.min(win.innerWidth - w - 8, r.left + r.width / 2 - w / 2)); let y = r.top - 48; if (y < 96) y = r.bottom + 10; el.style.left = x + 'px'; el.style.top = y + 'px'; };
    const mk = (html, r) => { kill(); bar = doc.createElement('div'); bar.className = '__sab'; bar.setAttribute('data-tool', 'selai'); bar.innerHTML = html; doc.body.appendChild(bar); place(bar, r); bar.addEventListener('mousedown', e => e.preventDefault(), true); bar.addEventListener('pointerdown', e => e.preventDefault(), true); bar.addEventListener('click', onBar, true); return bar; };
    const full = r => mk('<span data-k="Rewrite" class="pri"><span style="color:' + V + '">✦</span>Rewrite</span><span data-k="Shorter">Shorter</span><span data-k="Punchier">Punchier</span><span data-k="More me">More me</span><span class="sep"></span><span data-k="Cut" class="dim">Cut</span>', r);
    const mini = r => mk('<span data-k="sel" class="dim">Select sentence</span><span class="sep"></span><span data-k="rw" class="pri"><span style="color:' + V + '">✦</span>Rewrite</span>', r);
    const result = (r, cut) => mk('<span data-k="keep" class="pri">✓ Keep</span><span data-k="undo">↺ Undo</span>' + (cut ? '' : '<span class="sep"></span><span data-k="again" class="dim">✦ Try again</span>'), r);
    const sentence = (ed, node, off) => {
      const tw = doc.createTreeWalker(ed, NodeFilter.SHOW_TEXT), nodes = []; let t, total = 0, at = 0;
      while ((t = tw.nextNode())) { if (t.parentElement.closest('.cue')) continue; if (t === node) at = total + off; nodes.push([t, total]); total += t.data.length; }
      const txt = nodes.map(n => n[0].data).join('');
      let a = at; while (a > 0 && !/[.!?]/.test(txt[a - 1])) a--; while (a < txt.length && /\s/.test(txt[a])) a++;
      let b = at; while (b < txt.length && !/[.!?]/.test(txt[b])) b++; if (b < txt.length) b++;
      const pos = g => { for (let i = nodes.length - 1; i >= 0; i--) if (g >= nodes[i][1]) return [nodes[i][0], Math.min(g - nodes[i][1], nodes[i][0].data.length)]; return [nodes[0][0], 0]; };
      if (!nodes.length || b <= a) return null; const rg = doc.createRange(); const [sn, so] = pos(a), [en, eo] = pos(b); rg.setStart(sn, so); rg.setEnd(en, eo); return rg;
    };
    const selectRange = rg => { const s = win.getSelection(); s.removeAllRanges(); s.addRange(rg); saved = rg.cloneRange(); full(rg.getBoundingClientRect()); };
    const apply = (kind, rg, n) => {
      const ed = inEd(rg.startContainer); const orig = rg.toString(); if (!orig.trim()) return;
      bar.classList.add('busy'); bar.insertAdjacentHTML('beforeend', '<span class="busyL">✦ WRITING…</span>');
      win.setTimeout(() => {
        const sp = doc.createElement('span'); sp.className = '__ai' + (kind === 'Cut' ? ' cut' : ''); sp.textContent = kind === 'Cut' ? orig : gen(kind, orig, n || 0) + (/\s$/.test(orig) ? ' ' : '');
        rg.deleteContents(); rg.insertNode(sp); win.getSelection().removeAllRanges();
        pending = { sp, orig, kind, n: n || 0, ed };
        if (ed) ed.dispatchEvent(new win.Event('input', { bubbles: true }));
        result(sp.getBoundingClientRect(), kind === 'Cut');
      }, 650);
    };
    const settle = keep => { if (!pending) return; const { sp, orig, kind } = pending; if (keep) { if (kind === 'Cut') sp.remove(); else sp.replaceWith(doc.createTextNode(sp.textContent)); toast(kind === 'Cut' ? 'Cut' : '✦ ' + kind + ' kept'); } else { sp.replaceWith(doc.createTextNode(orig)); toast('Undone'); } pending = null; kill(); };
    function onBar(e) { e.stopPropagation(); e.preventDefault(); const k = (e.target.closest('[data-k]') || {}).dataset; if (!k || !k.k || (bar && bar.classList.contains('busy'))) return;
      if (k.k === 'keep') return settle(true); if (k.k === 'undo') return settle(false);
      if (k.k === 'again' && pending) { const { sp, orig, kind, n } = pending; const rg = doc.createRange(); const tn = doc.createTextNode(orig); sp.replaceWith(tn); rg.selectNodeContents(tn); pending = null; full(rg.getBoundingClientRect()); return apply(kind, rg, n + 1); }
      if (k.k === 'sel' || k.k === 'rw') { if (!saved) return; const rg = sentence(inEd(saved.startContainer), saved.startContainer, saved.startOffset); if (rg) selectRange(rg); return; }
      const s = win.getSelection(); const rg = s.rangeCount && !s.isCollapsed ? s.getRangeAt(0) : saved; if (!rg) return; apply(k.k, rg.cloneRange());
    }
    doc.addEventListener('selectionchange', () => { if (pending) return; const s = win.getSelection(); if (!s.rangeCount) return; const rg = s.getRangeAt(0); if (!inEd(rg.startContainer)) return;
      if (!s.isCollapsed && rg.toString().trim().length > 1) { saved = rg.cloneRange(); full(rg.getBoundingClientRect()); } });
    doc.addEventListener('click', e => { if (e.target.closest('.__sab,[data-sakb]')) return; if (pending && !e.target.closest('.__ai')) settle(true);
      const ed = inEd(e.target); if (!ed) { if (!pending) kill(); return; }
      win.setTimeout(() => { const s = win.getSelection(); if (!s.rangeCount || pending) return; if (s.isCollapsed) kill(); }, 20); }, true);
    doc.addEventListener('keydown', e => { if (inEd(e.target) && !pending) kill(); }, true);
    doc.addEventListener('scroll', () => { if (!pending) kill(); }, true);
    // 4.2: the demo selection stays as designed, and its bar now works on it
    if (id === '4.2') {
      const st = [...doc.querySelectorAll('.rise')].find(x => /Rewrite/.test(x.textContent) && /Punchier/.test(x.textContent));
      const hl = [...doc.querySelectorAll('span')].find(s => /255,214,10,0\.28|255, 214, 10, 0\.28/.test(s.getAttribute('style') || ''));
      const handles = [...doc.querySelectorAll('span')].filter(s => { const q = s.getAttribute('style') || ''; return /position: absolute/.test(q) && /#FFD60A/.test(q) && /(width: 2px|width: 8px)/.test(q); });
      if (st && hl) {
        const clearDemo = () => { handles.forEach(h => h.remove()); st.style.display = 'none'; };
        const ks = [...st.children].filter(c => /^(✦?\s*Rewrite|Shorter|Punchier|More me|Cut)$/.test(c.textContent.trim()));
        ks.forEach(c => { c.style.cursor = 'pointer'; c.setAttribute('data-tool', 'selai'); c.addEventListener('mousedown', e => e.preventDefault(), true); c.addEventListener('click', e => { e.stopPropagation(); e.preventDefault(); if (!hl.isConnected) return; const kind = c.textContent.replace('✦', '').trim(); const rg = doc.createRange(); rg.selectNode(hl); const text = hl.textContent; const tn = doc.createTextNode(text); hl.replaceWith(tn); rg.selectNodeContents(tn); clearDemo(); full(rg.getBoundingClientRect()); apply(kind, rg); }, true); });
        st.setAttribute('data-tool', 'selai');
        doc.addEventListener('selectionchange', () => { const s = win.getSelection(); if (s.rangeCount && !s.isCollapsed && hl.isConnected && inEd(s.getRangeAt(0).startContainer)) { hl.replaceWith(doc.createTextNode(hl.textContent)); clearDemo(); } });
      }
    }
  };
})();
