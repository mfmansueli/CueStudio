(function () {
  const MONO = "ui-monospace,'SF Mono',Menlo,monospace", Y = '#FFD60A', V = '#B4A7FF';
  const esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
  const FMT = [
    ['auto', 'Auto', 'Cue picks from your idea', ['Hook', 'Body', 'CTA']],
    ['talking', 'Talking head', 'You, the camera, one clear point', ['Hook', 'Point', 'Why it matters', 'CTA']],
    ['tutorial', 'Tutorial', 'Show how, step by step', ['Hook', 'Steps', 'Result', 'CTA']],
    ['story', 'Storytime', 'Something that happened to you', ['Hook', 'Setup', 'Turn', 'Lesson']],
    ['list', 'List / tips', '3 to 5 quick tips', ['Hook', 'Tip 1–3', 'Bonus', 'CTA']],
    ['review', 'Review', 'Honest take on a product or place', ['Hook', 'What it is', 'Good / bad', 'Verdict']],
    ['myth', 'Myth vs fact', 'Bust one belief', ['Myth', 'Why people think it', 'Fact', 'CTA']],
    ['pov', 'POV', 'Put the viewer in a moment', ['POV line', 'Scene', 'Twist']],
    ['ad', 'Sponsored ad', 'A paid partnership, done your way', ['Hook', 'Problem', 'Product', 'Proof', 'CTA', '#ad']]
  ];
  const F = id => FMT.find(f => f[0] === id) || FMT[0];
  const st = ctx => (ctx._script = ctx._script || { format: 'auto', brand: null, brands: [{ name: 'Oat & Co.', product: 'Barista oat milk', must: 'Froths like dairy · 1 L carton', avoid: 'Health claims', link: 'oatandco.com/maya', code: 'MAYA10' }], last: null });
  const shell = (doc, ctx) => { ctx.shCss(doc); if (!doc.__fmtCss) { doc.__fmtCss = 1; const s = doc.createElement('style'); s.textContent = '.__ft{display:grid;grid-template-columns:1fr 1fr;gap:8px}.__ft>div{border-radius:16px;background:rgba(31,34,54,0.9);padding:10px 12px;display:flex;flex-direction:column;gap:4px;cursor:pointer;min-height:76px;box-sizing:border-box}.__ft>div.on{background:rgba(255,214,10,0.12);box-shadow:inset 0 0 0 2px ' + Y + '}.__ft b{font-size:14px;font-weight:600}.__ft span{font-size:12px;line-height:1.3;color:rgba(225,228,245,0.55)}.__ft i{font-style:normal;' + 'font-family:' + MONO + ';font-size:9px;font-weight:600;letter-spacing:.06em;color:rgba(225,228,245,0.45);margin-top:auto}.__fi{display:flex;flex-direction:column;gap:4px}.__fi label{font-size:12.5px;font-weight:600;color:rgba(225,228,245,0.6);padding:0 4px}.__fi input{height:42px;border-radius:12px;border:0;outline:none;background:rgba(31,34,54,0.9);color:#fff;font:inherit;font-size:15px;padding:0 12px;caret-color:' + Y + '}'; doc.head.appendChild(s); }
    const old = doc.querySelector('.__fmtwrap'); if (old) old.remove(); const w = doc.createElement('div'); w.className = '__shwrap __fmtwrap'; doc.body.appendChild(w); return w; };
  const toast = (ctx, m) => ctx.props.onAction && ctx.props.onAction(ctx.props.id, ['__toast'], { x: 0, y: 0, msg: m });

  // ── Format picker (from the LET'S CUE chip or from + › Start from a format)
  window.CueFormatSheet = function (doc, ctx, mode, onPick) {
    const S = st(ctx), w = shell(doc, ctx); let sel = mode === 'blank' && S.format === 'auto' ? 'talking' : S.format;
    const draw = () => { const f = F(sel);
      w.innerHTML = '<div class="__shb"></div><div class="__sh" style="box-sizing:border-box;max-height:calc(100% - 66px);overflow-y:auto;scrollbar-width:none"><div class="gr"></div><div class="hd"><div><div class="mo">' + (mode === 'blank' ? 'START FROM A FORMAT · YOU WRITE IT' : 'FORMAT · CUE WRITES IT') + '</div><div class="tt">What kind of video?</div></div><div class="ok" data-a="ok">' + (mode === 'blank' ? 'Open' : 'Done') + '</div></div>' +
        '<div class="__ft">' + FMT.filter(x => mode !== 'blank' || x[0] !== 'auto').map(([id, n, d, sec]) => '<div data-f="' + id + '" class="' + (sel === id ? 'on' : '') + '"><b>' + esc(n) + (id === 'ad' ? ' <span style="color:' + V + ';font-size:11px">· needs brand info</span>' : '') + '</b><span>' + esc(d) + '</span><i>' + sec.join(' › ').toUpperCase() + '</i></div>').join('') + '</div>' +
        '<div class="lab" style="font-weight:400;line-height:1.4">' + (sel === 'ad' ? 'Next: brand brief. #ad is added for you.' : mode === 'blank' ? 'Opens as a draft with these sections.' : 'Comes ready: sections, cues, timing.') + '</div></div>'; };
    draw();
    w.addEventListener('click', e => { e.stopPropagation(); if (e.target.classList.contains('__shb')) { w.remove(); return; } const x = e.target.closest('[data-f],[data-a]'); if (!x) return;
      if (x.dataset.f) { sel = x.dataset.f; return draw(); }
      if (x.dataset.a === 'ok') { w.remove(); if (sel === 'ad') return window.CueAdBrief(doc, ctx, () => { S.format = 'ad'; onPick && onPick('ad'); }); S.format = sel; onPick && onPick(sel); } }, true);
  };

  // ── Sponsored ad brief: what the AI may not invent
  window.CueAdBrief = function (doc, ctx, done) {
    const S = st(ctx), w = shell(doc, ctx); let b = { ...(S.brand || S.brands[0]) }, save = true;
    const fld = (k, l, ph) => '<div class="__fi"><label>' + l + '</label><input data-k="' + k + '" value="' + esc(b[k] || '') + '" placeholder="' + esc(ph) + '"></div>';
    const draw = () => { const ok = (b.name || '').trim() && (b.product || '').trim();
      w.innerHTML = '<div class="__shb"></div><div class="__sh" style="box-sizing:border-box;max-height:calc(100% - 66px);overflow-y:auto;scrollbar-width:none"><div class="gr"></div><div class="hd"><div><div class="mo">SPONSORED AD · BRAND BRIEF</div><div class="tt">Who is it for?</div></div><div class="ok" data-a="close" style="background:rgba(110,116,150,0.26);color:#fff">Cancel</div></div>' +
        (S.brands.length ? '<div class="chips">' + S.brands.map((x, i) => '<div class="sm ' + (x.name === b.name ? 'on' : '') + '" data-brand="' + i + '">' + esc(x.name) + '</div>').join('') + '<div class="sm plus" data-brand="new">+ New brand</div></div>' : '') +
        fld('name', 'Brand', 'e.g. Oat & Co.') + fld('product', 'Product or offer', 'e.g. Barista oat milk') + fld('must', 'Must say', 'Key claims the brand approved') + fld('avoid', 'Never say', 'e.g. health claims, competitor names') + '<div style="display:flex;gap:8px">' + fld('link', 'Link', 'oatandco.com/you').replace('class="__fi"', 'class="__fi" style="flex:1.4"') + fld('code', 'Code', 'MAYA10').replace('class="__fi"', 'class="__fi" style="flex:1"') + '</div>' +
        '<div class="card"><div class="row"><div class="l">Paid partnership label<div class="s">Adds #ad · reminds you of the platform label</div></div><span class="__mono" style="color:#34C759">ALWAYS ON</span></div><div class="row" data-a="save" style="cursor:pointer"><div class="l">Save this brand for next time</div><div class="sw' + (save ? ' on' : '') + '"></div></div></div>' +
        '<div class="btn" data-a="go" style="background:' + (ok ? Y : 'rgba(110,116,150,0.26)') + ';color:' + (ok ? '#000' : 'rgba(225,228,245,0.4)') + '">✦ Write the ad</div><div class="lab" style="font-weight:400;line-height:1.4">Cue uses only this. No invented claims or prices.</div></div>'; };
    draw();
    w.addEventListener('input', e => { const k = e.target.dataset && e.target.dataset.k; if (k) { b[k] = e.target.value; const btn = w.querySelector('[data-a="go"]'), ok = (b.name || '').trim() && (b.product || '').trim(); btn.style.background = ok ? Y : 'rgba(110,116,150,0.26)'; btn.style.color = ok ? '#000' : 'rgba(225,228,245,0.4)'; } });
    w.addEventListener('click', e => { e.stopPropagation(); if (e.target.classList.contains('__shb')) { w.remove(); return; } const x = e.target.closest('[data-a],[data-brand]'); if (!x) return;
      if (x.dataset.brand != null) { b = x.dataset.brand === 'new' ? { name: '', product: '', must: '', avoid: '', link: '', code: '' } : { ...S.brands[+x.dataset.brand] }; return draw(); }
      if (x.dataset.a === 'close') { w.remove(); return; }
      if (x.dataset.a === 'save') { save = !save; return draw(); }
      if (x.dataset.a === 'go') { if (!((b.name || '').trim() && (b.product || '').trim())) { toast(ctx, 'Add brand and product'); return; } if (save && !S.brands.some(x => x.name === b.name)) S.brands.push({ ...b }); S.brand = b; w.remove(); done && done(); } }, true);
  };

  // ── Scripts home: Format chip on the LET'S CUE card
  window.CueFormatChip = function (doc, ctx) {
    const S = st(ctx); const row = doc.querySelector('[data-voicechip]'); if (!row || doc.querySelector('[data-fmtchip]')) return;
    const c = doc.createElement('div'); c.setAttribute('role', 'button'); c.setAttribute('data-fmtchip', '1'); c.setAttribute('data-tool', 'home');
    c.style.cssText = 'height:30px;padding:0 11px;border-radius:15px;background:rgba(5,6,12,0.42);display:flex;align-items:center;gap:5px;font-size:13px;font-weight:600;cursor:pointer;white-space:nowrap';
    const paint = () => { const f = F(S.format); c.innerHTML = (S.format === 'ad' ? '<span style="' + 'font-family:' + MONO + ';font-size:9.5px;font-weight:700;color:#000;background:' + Y + ';border-radius:4px;padding:1px 4px">AD</span>' + esc(S.brand ? S.brand.name : 'Sponsored') : esc(f[1] === 'Auto' ? 'Format' : f[1])) + '<span style="color:rgba(225,228,245,0.5)">⌄</span>'; };
    paint(); row.parentElement.insertBefore(c, row);
    const voice = row.childNodes; // compact voice chip so 3 chips fit
    const lbl = [...row.childNodes].find(n => n.nodeType === 3 && /In your voice/.test(n.textContent)); if (lbl) lbl.textContent = 'Voice';
    doc.addEventListener('click', e => { if (!e.target.closest('[data-fmtchip]')) return; e.stopImmediatePropagation(); e.preventDefault(); window.CueFormatSheet(doc, ctx, 'ai', () => { paint(); toast(ctx, S.format === 'ad' ? 'Sponsored ad for ' + S.brand.name + ' · #ad on' : 'Format: ' + F(S.format)[1]); }); }, true);
  };
  window.CueFormatOnSend = function (ctx) { const S = st(ctx); S.last = { format: S.format, brand: S.format === 'ad' && S.brand ? S.brand.name : null, stage: 'READY', cues: 4, fromCue: true }; return S.format === 'ad' ? '✦ Writing a sponsored ad for ' + (S.brand ? S.brand.name : 'the brand') : S.format === 'auto' ? '✦ Writing in your voice' : '✦ Writing a ' + F(S.format)[1].toLowerCase() + ' in your voice'; };

  // ── + New script: “Start from a format”
  window.CueNewScriptFormat = function (doc, ctx) {
    if (doc.querySelector('[data-fmtstart]')) return;
    const leaf = [...doc.querySelectorAll('*')].find(e => e.children.length === 0 && /^write it myself/i.test(e.textContent.trim())); if (!leaf) return;
    let row = leaf; for (let i = 0; i < 6 && row.parentElement; i++) { if (row.getBoundingClientRect().width > 300 && row.getBoundingClientRect().height >= 44) break; row = row.parentElement; }
    const c = row.cloneNode(true); c.setAttribute('data-fmtstart', '1'); c.setAttribute('data-tool', 'new');
    const leaves = [...c.querySelectorAll('*')].filter(e => e.children.length === 0 && e.textContent.trim());
    if (leaves[0]) leaves[0].textContent = 'Start from a format'; if (leaves[1]) leaves[1].textContent = 'Talking head, tutorial, sponsored ad… you write it'; leaves.slice(2).forEach(l => { if (!/›|❯/.test(l.textContent)) l.textContent = ''; });
    const cs = doc.defaultView.getComputedStyle(row); if (cs.position === 'absolute') { const h = row.getBoundingClientRect().height + 8; c.style.top = (parseFloat(cs.top) + h) + 'px'; [...row.parentElement.children].forEach(sib => { if (sib !== row && doc.defaultView.getComputedStyle(sib).position === 'absolute' && sib.getBoundingClientRect().top > row.getBoundingClientRect().top + 2) sib.style.top = (parseFloat(doc.defaultView.getComputedStyle(sib).top) + h) + 'px'; }); row.after(c); }
    else row.after(c);
    row.addEventListener('click', () => { st(ctx).last = { format: 'none', stage: 'DRAFT', cues: 0, blank: true }; }, true);
    const imp = [...doc.querySelectorAll('*')].find(e => e.children.length === 0 && /^import/i.test(e.textContent.trim())); if (imp) { let ir = imp; for (let i = 0; i < 6 && ir.parentElement; i++) { if (ir.getBoundingClientRect().width > 300) break; ir = ir.parentElement; } ir.setAttribute('data-tool', 'new'); ir.addEventListener('click', e => { e.stopPropagation(); e.preventDefault(); window.CueImportSheet(doc, ctx); }, true); }
    c.addEventListener('click', e => { e.stopPropagation(); e.preventDefault(); window.CueFormatSheet(doc, ctx, 'blank', f => { const S = st(ctx); S.last = { format: f, brand: f === 'ad' && S.brand ? S.brand.name : null, stage: 'DRAFT', cues: 0, blank: true }; ctx.props.onAction && ctx.props.onAction(ctx.props.id, ['__goto:4.2'], { x: 0, y: 0 }); }); }, true);
  };

  // ── Script page (4.1 / 4.2): state follows intent — Done = finished, back with changes = draft. Shape is a tool.
  window.CueOpenScript = function (ctx, info) { st(ctx).last = { format: 'talking', cues: 4, ...info }; };
  window.CueScriptStrip = function (doc, ctx, id) {
    const S = st(ctx); if (doc.querySelector('[data-sstrip]')) return;
    const L = S.last || (S.last = id === '4.2' ? { format: 'talking', stage: 'DRAFT', cues: 0 } : { format: 'talking', stage: 'READY', cues: 4 });
    const f = L.format === 'none' ? null : F(L.format === 'auto' ? 'talking' : L.format);
    let dirty = false, done = false;
    const win = doc.defaultView, box = doc.querySelector('.night') || doc.body.firstElementChild || doc.body;
    if (!box.__stripShift) { box.__stripShift = 1; [...box.children].forEach(e => { const cs = win.getComputedStyle(e); if (cs.position !== 'absolute' || (e.style.bottom && !e.style.top)) return; const r = e.getBoundingClientRect(); if (r.top >= 96 && r.height < 700) e.style.setProperty('top', (parseFloat(cs.top) + 48) + 'px', 'important'); }); }
    const bar = doc.createElement('div'); bar.setAttribute('data-sstrip', '1'); bar.setAttribute('data-tool', 'strip');
    bar.style.cssText = 'position:absolute;left:16px;right:16px;top:100px;z-index:30;border-radius:16px;background:rgba(14,16,28,0.92);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);box-shadow:inset 0 0 0 0.5px rgba(180,167,255,0.3);padding:6px 6px 6px 12px;display:flex;align-items:center;gap:8px;color:#fff;min-height:44px;box-sizing:border-box';
    const tag = (t, c, bg) => '<span style="height:22px;padding:0 8px;border-radius:11px;background:' + bg + ';color:' + c + ';font-family:' + MONO + ';font-size:9.5px;font-weight:700;letter-spacing:.08em;display:flex;align-items:center;flex-shrink:0">' + t + '</span>';
    const btn = (k, label, prim, extra) => '<div data-s="' + k + '" role="button" style="height:32px;padding:0 12px;border-radius:16px;background:' + (prim ? Y : extra || 'rgba(110,116,150,0.26)') + ';color:' + (prim ? '#000' : '#fff') + ';display:flex;align-items:center;gap:5px;font-size:13px;font-weight:700;cursor:pointer;flex-shrink:0;white-space:nowrap">' + label + '</div>';
    const recOut = () => [...doc.querySelectorAll('button')].some(b => !bar.contains(b) && /record( reply)?$/i.test((b.textContent || '').trim()));
    let hasRec = false;
    const recB = btn('rec', '<span style="width:10px;height:10px;border-radius:5px;background:#FF3B30"></span>Record', true);
    const draw = () => { hasRec = recOut(); const draft = L.stage === 'DRAFT', recd = L.stage === 'RECORDED';
      const stTag = draft ? tag('DRAFT', 'rgba(225,228,245,0.8)', 'rgba(110,116,150,0.26)') : recd ? tag('RECORDED ×' + (L.takes || 3), 'rgba(225,228,245,0.85)', 'rgba(110,116,150,0.26)') : tag('READY', '#34C759', 'rgba(52,199,89,0.14)');
      const info = recd && dirty ? 'CHANGED SINCE TAKE ' + (L.takes || 3) : dirty ? 'EDITED · TAP DONE' : (f ? esc(f[1].toUpperCase()) + ' · ' : 'YOUR SCRIPT · ') + (L.cues ? L.cues + ' CUES' : 'NO CUES');
      bar.innerHTML = stTag + (L.format === 'ad' ? tag('#AD', '#000', Y) : '') +
        '<div style="flex:1;min-width:0;font-family:' + MONO + ';font-size:9.5px;font-weight:600;letter-spacing:.06em;color:' + (recd && dirty ? Y : 'rgba(225,228,245,0.6)') + ';white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + info + '</div>' +
        (!L.cues ? btn('shape', '<span style="color:' + V + '">✦</span>Shape', false, 'rgba(157,140,255,0.2)') : '') +
        (draft ? btn('done', 'Done', !hasRec) : recd ? (hasRec ? '' : btn('rec', '<span style="width:10px;height:10px;border-radius:5px;background:#FF3B30"></span>Retake', !!dirty)) : '<div data-s="done" role="button" style="font-size:14px;font-weight:600;color:rgba(225,228,245,0.75);padding:0 6px;cursor:pointer">Done</div>' + (hasRec ? '' : recB)); };
    draw(); box.appendChild(bar);
    { let last = hasRec, n = 0; const iv = win.setInterval(() => { if (!bar.isConnected || ++n > 40) return win.clearInterval(iv); if (recOut() !== last) { last = recOut(); draw(); } }, 250); }
    const confirm = (msg, yes, no, onYes) => { ctx.shCss(doc); const w = doc.createElement('div'); w.className = '__shwrap'; w.innerHTML = '<div class="__shb"></div><div class="__sh" style="box-sizing:border-box"><div class="gr"></div><div class="tt" style="font-size:19px;padding:4px 4px 0">' + esc(msg) + '</div><div style="display:flex;gap:8px"><div class="btn" data-c="no" style="flex:1;background:rgba(110,116,150,0.26);color:#fff">' + no + '</div><div class="btn" data-c="yes" style="flex:1;background:' + Y + ';color:#000">' + yes + '</div></div></div>'; doc.body.appendChild(w);
      w.addEventListener('click', e => { e.stopPropagation(); const c = e.target.closest('[data-c]'); if (e.target.classList.contains('__shb') || c) { w.remove(); if (c && c.dataset.c === 'yes') onYes(); } }, true); };
    const finish = () => { L.stage = 'READY'; dirty = false; done = true; L.blank = false; draw(); toast(ctx, 'Ready to record' + (L.cues ? '' : ' · ✦ Shape adds cues')); };
    const markDirty = () => { if (dirty) return; dirty = true; if (L.stage === 'READY') L.stage = 'DRAFT'; draw(); };
    bar.addEventListener('click', e => { e.stopPropagation(); const k = (e.target.closest('[data-s]') || {}).dataset; if (!k || !k.s) return;
      if (k.s === 'shape') { L.cues = 4; markDirty(); draw(); toast(ctx, '✦ 4 cues added'); return; }
      if (k.s === 'rec') { if (dirty && L.stage === 'DRAFT') { L.stage = 'READY'; dirty = false; } done = true; ctx.props.onAction && ctx.props.onAction(ctx.props.id, ['__rec'], { x: 0, y: 0 }); return; }
      if (k.s === 'done') { if (L.stage === 'READY' && !dirty) { ctx.props.onAction && ctx.props.onAction(ctx.props.id, ['__back'], { x: 0, y: 0 }); return; }
        if (L.blank && !dirty) { if (!f) { toast(ctx, 'Nothing to save yet'); return; } return confirm((f[3].length - 1) + ' sections are still empty.', 'Done anyway', 'Keep writing', finish); } finish(); } }, true);
    doc.addEventListener('input', e => { if (e.target.closest && e.target.closest('[contenteditable="true"]') && !e.target.closest('.__shwrap')) markDirty(); }, true);
    win.addEventListener('pagehide', () => { if (dirty && !done && L.stage !== 'RECORDED') { L.stage = 'DRAFT'; toast(ctx, 'Saved as draft'); } });
  };

  // ── Import (3.5): review imported text, “Use this script” counts as Done
  window.CueImportSheet = function (doc, ctx) {
    const w = shell(doc, ctx); const TXT = 'Okay, real talk. I tried every budget app. This is the only rule that stuck: fifty percent needs, thirty wants, twenty savings. Write it on a sticky note. Save this for payday.';
    w.innerHTML = '<div class="__shb"></div><div class="__sh" style="box-sizing:border-box;max-height:calc(100% - 66px);overflow-y:auto;scrollbar-width:none"><div class="gr"></div><div class="hd"><div><div class="mo">IMPORT · SCAN · PHOTO · FILE · PASTE</div><div class="tt">Is this your script?</div></div><div class="ok" data-a="close" style="background:rgba(110,116,150,0.26);color:#fff">Cancel</div></div>' +
      '<div class="seg"><div class="on">Paste</div><div>Scan</div><div>Photo</div><div>File</div></div><div contenteditable="true" style="border-radius:16px;background:rgba(31,34,54,0.9);padding:12px 14px;font-size:16px;line-height:1.45;outline:none;caret-color:' + Y + '">' + TXT + '</div><div class="lab" style="font-weight:400">42 words · ~0:17 · edit before using</div><div class="btn" data-a="use" style="background:' + Y + ';color:#000">Use this script</div></div>';
    doc.body.appendChild(w);
    w.addEventListener('click', e => { e.stopPropagation(); if (e.target.classList.contains('__shb') || e.target.closest('[data-a="close"]')) return w.remove(); const sg = e.target.closest('.seg > div'); if (sg) { [...sg.parentElement.children].forEach(x => x.classList.toggle('on', x === sg)); return; } if (e.target.closest('[data-a="use"]')) { st(ctx).last = { format: 'none', stage: 'READY', cues: 0, imported: true }; w.remove(); toast(ctx, 'Imported · Ready to record'); ctx.props.onAction && ctx.props.onAction(ctx.props.id, ['__goto:4.1'], { x: 0, y: 0 }); } }, true);
  };

  window.CueFirstVisit = function (doc, ctx) { const b = [...doc.querySelectorAll('button')].find(x => /^write my own/i.test(x.textContent.trim())); if (b) b.addEventListener('click', () => window.CueOpenScript(ctx, { format: 'none', stage: 'DRAFT', cues: 0, blank: true }), true); const i = [...doc.querySelectorAll('button')].find(x => /^import ›$/i.test(x.textContent.trim())); if (i) i.addEventListener('click', e => { e.stopPropagation(); e.preventDefault(); window.CueImportSheet(doc, ctx); }, true); [...doc.querySelectorAll('button')].filter(x => x.querySelector('span[style*="flex: 1"]')).forEach(x => x.addEventListener('click', () => { st(ctx).last = { format: 'auto', stage: 'READY', cues: 4, fromCue: true }; }, true)); };

  // ── Share (8.1): sponsored reminder
  window.CueShareAdNote = function (doc, ctx) {
    const S = st(ctx), L = S.last; if (!L || L.format !== 'ad' || doc.querySelector('[data-adnote]')) return;
    const n = doc.createElement('div'); n.setAttribute('data-adnote', '1'); n.setAttribute('data-tool', 'adnote');
    n.style.cssText = 'position:absolute;left:16px;right:16px;top:64px;z-index:30;border-radius:16px;background:rgba(14,16,28,0.94);box-shadow:inset 0 0 0 1px rgba(255,214,10,0.45);padding:10px 12px;display:flex;align-items:center;gap:10px;color:#fff;font-size:13.5px;line-height:1.35';
    n.innerHTML = '<span style="font-family:' + MONO + ';font-size:9.5px;font-weight:700;color:#000;background:' + Y + ';border-radius:4px;padding:2px 5px;flex-shrink:0">AD</span><span style="flex:1">Paid partnership with ' + esc(L.brand || 'the brand') + ' · <b>#ad</b> in caption. Turn on the platform label.</span>';
    doc.body.appendChild(n);
  };
})();
