(function () {
  // Empty states for a brand-new account. Same pattern everywhere: a quiet sky mark, a title, one line, one yellow action, an optional text link.
  const MONO = "ui-monospace,'SF Mono',Menlo,monospace", Y = '#FFD60A', V = '#B4A7FF';
  const ICON = {
    takes: '<rect x="3.5" y="6.5" width="14" height="14" rx="3.5"></rect><path d="M7.5 3.5h9.5a3.5 3.5 0 0 1 3.5 3.5v9.5"></path><path d="M9 10.6v5.8l4.8-2.9z" fill="currentColor" stroke="none"></path>',
    book: '<path d="M6.5 3.5h11a1.5 1.5 0 0 1 1.5 1.5v15.5H7.5a2.5 2.5 0 0 1-2.5-2.5V5a1.5 1.5 0 0 1 1.5-1.5z"></path><path d="M5 18a2.5 2.5 0 0 1 2.5-2.5H19"></path>',
    star: '<path d="M12 4C12.7 9.6 14.4 11.3 20 12C14.4 12.7 12.7 14.4 12 20C11.3 14.4 9.6 12.7 4 12C9.6 11.3 11.3 9.6 12 4Z" fill="currentColor" stroke="none"></path>',
    search: '<circle cx="10.5" cy="10.5" r="6"></circle><path d="M15 15l5 5"></path>'
  };
  const mark = (k, c) => '<div style="position:relative;width:88px;height:88px;display:flex;align-items:center;justify-content:center">' +
    '<div style="position:absolute;inset:0;border-radius:50%;box-shadow:inset 0 0 0 1px rgba(180,167,255,0.22)"></div><div style="position:absolute;inset:14px;border-radius:50%;background:radial-gradient(closest-side,rgba(157,140,255,0.22),rgba(157,140,255,0))"></div>' +
    '<div style="position:absolute;left:50%;top:-2px;width:5px;height:5px;margin-left:-2.5px;border-radius:50%;background:#FFE680;box-shadow:0 0 8px rgba(255,214,10,0.7);transform-origin:2.5px 46px;animation:__eOrb 14s linear infinite"></div>' +
    '<svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="' + (c || '#E4DEFF') + '" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" style="position:relative;color:' + (c || '#E4DEFF') + '">' + ICON[k] + '</svg></div>';
  const css = doc => { if (doc.__eCss) return; doc.__eCss = 1; const s = doc.createElement('style'); s.textContent = '@keyframes __eOrb{to{transform:rotate(360deg)}}@keyframes __eIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}@media (prefers-reduced-motion: reduce){[style*="__eOrb"]{animation:none!important}}'; doc.head.appendChild(s); };
  const block = (doc, o) => { css(doc); const w = doc.createElement('div'); w.setAttribute('data-empty', '1'); w.setAttribute('data-tool', 'empty');
    w.style.cssText = 'position:absolute;left:24px;right:24px;top:' + (o.top || 250) + 'px;display:flex;flex-direction:column;align-items:center;gap:14px;text-align:center;color:#fff;animation:__eIn .35s ease-out;z-index:5';
    w.innerHTML = mark(o.icon, o.c) + '<div style="display:flex;flex-direction:column;gap:6px;align-items:center"><div style="font-size:22px;line-height:28px;font-weight:700;letter-spacing:-0.02em">' + o.title + '</div><div style="font-size:15px;line-height:21px;color:rgba(225,228,245,0.62);max-width:280px">' + o.text + '</div></div>' +
      (o.primary ? '<button data-e="p" style="height:50px;padding:0 22px;border:0;border-radius:25px;background:' + Y + ';color:#000;font-family:inherit;font-size:16px;font-weight:700;display:flex;align-items:center;gap:8px;cursor:pointer;margin-top:4px">' + o.primary[0] + '</button>' : '') +
      (o.secondary ? '<button data-e="s" style="height:44px;padding:0 10px;border:0;background:none;color:rgba(225,228,245,0.8);font-family:inherit;font-size:15px;font-weight:600;cursor:pointer">' + o.secondary[0] + '</button>' : '');
    w.addEventListener('click', e => { const b = e.target.closest('[data-e]'); if (!b) return; e.stopPropagation(); const a = b.dataset.e === 'p' ? o.primary[1] : o.secondary[1]; if (typeof a === 'function') a(); else o.ctx.props.onAction && o.ctx.props.onAction(o.ctx.props.id, [a], { x: 0, y: 0 }); }, true);
    return w; };
  const hideBelow = (root, y, keep) => [...root.children].forEach(e => { const r = e.getBoundingClientRect(), st = e.getAttribute('style') || ''; if (/blur\(22px\)/.test(st) || e.classList.contains('sky') || /linear-gradient\(rgba\(10,11,18,0\)/.test(st) || (keep && keep(e))) return; if (r.top >= y) e.style.display = 'none'; });
  const swapText = (root, re, to) => { const tw = root.ownerDocument.createTreeWalker(root, NodeFilter.SHOW_TEXT); let t; while ((t = tw.nextNode())) if (re.test(t.data)) t.data = t.data.replace(re, to); };

  window.CueEmpty = function (doc, ctx, id) {
    if (!window.__cueEmpty || doc.__empty) return; doc.__empty = 1;
    const nd = () => doc.querySelectorAll('.__nudge').forEach(n => n.remove()); nd(); [300, 900, 1800].forEach(t => doc.defaultView.setTimeout(nd, t));
    const root = doc.querySelector('.night') || doc.body.firstElementChild || doc.body;
    if (id === '6.2') {
      hideBelow(root, 110); swapText(root, /\d+ TAKES · \d+ VIDEOS/, '00 TAKES · 00 VIDEOS');
      [...root.querySelectorAll('*')].filter(e => e.children.length === 0 && /^Select$/.test(e.textContent.trim())).forEach(e => { (e.closest('button') || e).style.visibility = 'hidden'; });
      root.appendChild(block(doc, { ctx, icon: 'takes', title: 'No takes yet', text: 'Record a script. Every take lands here.', primary: ['<span style="width:10px;height:10px;border-radius:5px;background:#FF3B30"></span>Record', '__rec'], secondary: ['Pick a script ›', '__goto:3.1'], top: 230 }));
    }
    if (id === '3.6') {
      const sheet = root.querySelector('.sheet') || root; const capt = [...sheet.querySelectorAll('*')].find(e => /hold to capture/i.test(e.getAttribute('aria-label') || '') || /^Hold to capture/i.test((e.textContent || '').trim()));
      let capBox = capt; while (capBox && capBox.parentElement !== sheet) capBox = capBox.parentElement;
      [...sheet.children].forEach(c => { const r = c.getBoundingClientRect(); if (r.top > 150 && c !== capBox && !/Done/.test(c.textContent.trim()) ) c.style.display = 'none'; });
      swapText(sheet, /WAITING · \d+/, 'WAITING · 0');
      const top = capBox ? Math.round(capBox.getBoundingClientRect().bottom - root.getBoundingClientRect().top) + 40 : 240;
      root.appendChild(block(doc, { ctx, icon: 'book', title: 'Your Logbook is empty', text: 'Hold the mic to catch an idea. Write it later.', top }));
    }
    if (id === '9.2') {
      [...root.children].forEach(c => { const t = c.textContent || ''; if (/TIKTOK ·|Morning routines|NEXT MILESTONE|in review|Share my universe/.test(t) && !/Scripts.*Takes/.test(t)) c.style.display = 'none'; }); swapText(root, /\d+ VIDEOS SHARED[^<]*/i, 'NO VIDEOS SHARED YET');
      root.appendChild(block(doc, { ctx, icon: 'star', c: '#FFE680', title: 'Your first star is one video away', text: 'Share a video and it lights up here.', primary: ['Go to Takes', '__goto:6.2'], top: 470 }));
    }
    if (id === '9.1') {
      swapText(root, /\b\d+ VIDEOS SHARED\b/i, 'NO VIDEOS YET'); swapText(root, /\b\d+ VIDEOS\b/i, '0 VIDEOS');
    }
  };

  // Scripts: when a platform filter leaves the list empty, say so and offer to create for it
  window.CueFilterEmpty = function (doc, ctx) {
    const root = doc.querySelector('.night') || doc.body.firstElementChild; if (!root || doc.__fEmpty) return; doc.__fEmpty = 1; css(doc);
    const note = doc.createElement('div'); note.setAttribute('data-tool', 'empty'); note.style.cssText = 'position:absolute;left:16px;right:16px;top:372px;display:none;flex-direction:column;align-items:center;gap:10px;padding:26px 16px;border-radius:20px;background:#161826;box-shadow:inset 0 0 0 0.5px rgba(180,167,255,0.14);text-align:center;color:#fff;z-index:4';
    root.appendChild(note);
    const check = () => { const rows = [...doc.querySelectorAll('[data-row]')]; if (!rows.length) return; const vis = rows.filter(r => r.offsetParent && r.getBoundingClientRect().height > 0).length; const act = [...doc.querySelectorAll('[role="tab"],[data-pf]')].find(t => /true|on/.test(t.getAttribute('aria-selected') || t.getAttribute('data-on') || '')); const name = act ? act.textContent.replace(/\d+/g, '').trim() : 'this platform';
      if (vis === 0) { note.innerHTML = '<div style="font-size:17px;font-weight:700">No ' + name + ' scripts yet</div><div style="font-size:14px;color:rgba(225,228,245,0.62)">Write one for it, or switch back to All.</div><button data-fe="1" style="height:40px;padding:0 16px;border:0;border-radius:20px;background:rgba(110,116,150,0.26);color:#fff;font-family:inherit;font-size:14.5px;font-weight:600;cursor:pointer;margin-top:2px">Create for ' + name + '</button>'; note.style.display = 'flex'; } else note.style.display = 'none'; };
    note.addEventListener('click', e => { if (e.target.closest('[data-fe]')) { e.stopPropagation(); ctx.props.onAction && ctx.props.onAction(ctx.props.id, ['__goto:3.4'], { x: 0, y: 0 }); } }, true);
    new doc.defaultView.MutationObserver(() => doc.defaultView.requestAnimationFrame(check)).observe(root, { subtree: true, attributes: true, attributeFilter: ['style', 'data-on', 'aria-selected', 'data-row'] });
  };
})();
