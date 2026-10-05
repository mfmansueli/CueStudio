(function () {
  // LET'S CUE! card: an always-on, quiet sky (drifting dust, a slow violet nebula, twinkles with cross glints, a shooting star every 12 s).
  // Sending an idea launches a star from the arrow into the sky above; it stays there as one of “your stars”.
  window.CueConstellation = function (doc, ctx) {
    if (doc.__cst) return; const hero = [...doc.querySelectorAll('.hero')].find(h => h.dataset.dock || /LET.S CUE/i.test(h.textContent)); if (!hero) return; doc.__cst = 1;
    const win = doc.defaultView, NS = 'http://www.w3.org/2000/svg', reduce = win.matchMedia && win.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const hr = hero.getBoundingClientRect(), W = hr.width, H = hr.height;
    // obstacles: real text extents (via Range) + any field, chip, button or input box
    const obs = [];
    const tw = doc.createTreeWalker(hero, NodeFilter.SHOW_TEXT); let tn;
    while ((tn = tw.nextNode())) { if (!tn.data.trim()) continue; const rg = doc.createRange(); rg.selectNodeContents(tn); [...rg.getClientRects()].forEach(r => { if (r.width && r.height) obs.push(r); }); }
    [...hero.querySelectorAll('*')].forEach(e => { if (e.tagName === 'svg' || e.closest('svg')) return; const cs = win.getComputedStyle(e), r = e.getBoundingClientRect(); if (!r.width || r.width > W - 4) return;
      const bg = cs.backgroundColor, hasBg = bg && !/rgba\(0, 0, 0, 0\)|transparent/.test(bg); if (hasBg || /^(BUTTON|INPUT|TEXTAREA)$/.test(e.tagName) || e.getAttribute('role') === 'button' || e.isContentEditable) obs.push(r); });
    const free = (x, y, pad) => { const X = hr.left + x, Y = hr.top + y; return x > 8 && x < W - 8 && y > 4 && y < H - 4 && !obs.some(r => X > r.left - pad && X < r.right + pad && Y > r.top - pad && Y < r.bottom + pad); };
    // scan a coarse grid for free spots, keep them spread out
    const cand = []; for (let y = 6; y < H - 4; y += 4) for (let x = 12; x < W - 8; x += 6) if (free(x, y, 7)) cand.push([x, y]);
    const pts = []; const far = (p, m) => pts.every(q => Math.hypot(p[0] - q[0], p[1] - q[1]) >= m);
    const pref = [[W * 0.42, 14], [W * 0.55, 24], [W * 0.66, 10], [W * 0.5, 6], [W - 22, H - 36], [W - 14, H - 16], [W * 0.3, H - 10], [W - 14, H * 0.5]];
    for (const [px, py] of pref) { if (pts.length >= 6) break; const c = cand.filter(p => far(p, 22)).sort((a, b) => Math.hypot(a[0] - px, a[1] - py) - Math.hypot(b[0] - px, b[1] - py))[0]; if (c && Math.hypot(c[0] - px, c[1] - py) < 70) pts.push(c); }
    for (const c of cand) { if (pts.length >= 6) break; if (far(c, 24)) pts.push(c); }
    if (pts.length < 3) return;
    // order left→right along the top, then down the right edge, so lines stay short
    pts.sort((p, q) => (p[1] < H / 2 ? 0 : 1) - (q[1] < H / 2 ? 0 : 1) || (p[1] < H / 2 ? p[0] - q[0] : p[1] - q[1]));
    const svg = doc.createElementNS(NS, 'svg'); svg.setAttribute('width', W); svg.setAttribute('height', H); svg.setAttribute('aria-hidden', 'true');
    svg.style.cssText = 'position:absolute;left:0;top:0;pointer-events:none;overflow:hidden';
    if (!doc.__cstCss) { doc.__cstCss = 1; const st = doc.createElement('style');
      st.textContent = '@keyframes cstTw{0%,100%{opacity:.12}50%{opacity:.8}}@keyframes cstGl{0%,100%{opacity:.25;transform:scale(.55)}50%{opacity:1;transform:scale(1)}}' +
        '@keyframes cstShoot{0%,86%{transform:translate(0,0);opacity:0}88%{opacity:.9}96%{opacity:0}100%{transform:translate(' + Math.round(W * 0.55) + 'px,' + Math.round(H * 0.22) + 'px);opacity:0}}' +
        '@keyframes cstDust{from{background-position:0 0,0 0}to{background-position:-120px 60px,-200px 100px}}@keyframes cstNeb{0%{transform:translate(-10%,-6%) scale(1)}100%{transform:translate(18%,10%) scale(1.15)}}' +
        '@keyframes cstSky{0%,100%{opacity:.35;transform:scale(.8)}50%{opacity:1;transform:scale(1.15)}}' +
        '.cstS{animation:cstTw 5s ease-in-out infinite}.cstG{transform-box:fill-box;transform-origin:center;animation:cstGl 3.6s ease-in-out infinite}.cstShoot{animation:cstShoot 12s linear infinite}' +
        '.cstDust{position:absolute;inset:0;pointer-events:none;opacity:.55;background-image:radial-gradient(1px 1px at 12% 30%,rgba(255,255,255,.7) 50%,transparent 51%),radial-gradient(1px 1px at 64% 18%,rgba(228,222,255,.6) 50%,transparent 51%),radial-gradient(1px 1px at 38% 70%,rgba(255,255,255,.5) 50%,transparent 51%),radial-gradient(1px 1px at 86% 56%,rgba(255,230,128,.55) 50%,transparent 51%);background-size:120px 60px,200px 100px,120px 60px,200px 100px;animation:cstDust 48s linear infinite}' +
        '.cstNeb{position:absolute;left:-20%;top:-30%;width:70%;height:120%;border-radius:50%;pointer-events:none;background:radial-gradient(closest-side,rgba(180,167,255,0.22),rgba(180,167,255,0));filter:blur(6px);animation:cstNeb 22s ease-in-out infinite alternate}' +
        '.cstSkyStar{position:absolute;width:3px;height:3px;margin:-1.5px 0 0 -1.5px;border-radius:50%;background:#FFE680;box-shadow:0 0 6px 1px rgba(255,214,10,.6);pointer-events:none;animation:cstSky 4s ease-in-out infinite}' +
        '@keyframes cstPulse{0%,100%{opacity:.45}50%{opacity:1}}@keyframes cstFlash{0%{transform:scale(.2);opacity:.95}100%{transform:scale(7);opacity:0}}' +
        '@media (prefers-reduced-motion: reduce){.cstS,.cstG,.cstShoot,.cstDust,.cstNeb,.cstSkyStar{animation:none}.cstShoot{display:none}}';
      doc.head.appendChild(st); }
    svg.innerHTML = '<defs><linearGradient id="cstTail" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#E4DEFF" stop-opacity="0"></stop><stop offset="1" stop-color="#fff" stop-opacity="0.95"></stop></linearGradient></defs>';
    pts.forEach((p, i) => { if (i === 0 || i === 3) { const g = doc.createElementNS(NS, 'path'); const [x, y] = p, s = 4.5; g.setAttribute('d', 'M' + x + ' ' + (y - s) + 'Q' + x + ' ' + y + ' ' + (x + s) + ' ' + y + 'Q' + x + ' ' + y + ' ' + x + ' ' + (y + s) + 'Q' + x + ' ' + y + ' ' + (x - s) + ' ' + y + 'Q' + x + ' ' + y + ' ' + x + ' ' + (y - s) + 'Z'); g.setAttribute('fill', i === 3 ? '#FFE680' : '#fff'); g.setAttribute('class', 'cstG'); g.style.animationDelay = (-i * 1.1) + 's'; svg.appendChild(g); return; }
      const c = doc.createElementNS(NS, 'circle'); c.setAttribute('cx', p[0]); c.setAttribute('cy', p[1]); c.setAttribute('r', i % 2 ? '1.1' : '1.4'); c.setAttribute('fill', '#fff');
      c.setAttribute('class', 'cstS'); c.style.animationDelay = (-(i * 1.3) % 5).toFixed(1) + 's'; c.style.animationDuration = (4.2 + (i % 3) * 0.9).toFixed(1) + 's'; svg.appendChild(c); });
    const sx = Math.max(12, (pts[0] || [W * 0.3])[0] - 50), sy = 3;
    const sg = doc.createElementNS(NS, 'g'); sg.setAttribute('class', 'cstShoot'); sg.style.animationDelay = '-4s';
    sg.innerHTML = '<line x1="' + (sx - 34) + '" y1="' + (sy - 6) + '" x2="' + sx + '" y2="' + sy + '" stroke="url(#cstTail)" stroke-width="1.1" stroke-linecap="round"></line><circle cx="' + sx + '" cy="' + sy + '" r="1.2" fill="#fff"></circle>';
    svg.appendChild(sg);
    const neb = doc.createElement('div'); neb.className = 'cstNeb'; const dust = doc.createElement('div'); dust.className = 'cstDust';
    hero.insertBefore(neb, hero.children[0] || null); hero.insertBefore(dust, neb.nextSibling); hero.insertBefore(svg, dust.nextSibling); if (hero.dataset.dock) [neb, dust, svg].forEach(x => { x.style.display = 'none'; });
    // ── your stars: each idea you send becomes a star in the sky above
    const root = hero.parentElement, SKY = (ctx._sky = ctx._sky || []);
    const putSky = (x, y, i) => { const s = doc.createElement('div'); s.className = 'cstSkyStar'; s.style.left = x + 'px'; s.style.top = y + 'px'; s.style.animationDelay = (-i * 0.7) + 's'; root.insertBefore(s, root.firstChild ? root.firstChild.nextSibling : null); return s; };
    SKY.slice(-14).forEach((p, i) => putSky(p[0], p[1], i));
    let going = false;
    const launch = () => new Promise(res => {
      const send = hero.querySelector('[data-send]'); const rr = root.getBoundingClientRect(), sr = (send || hero).getBoundingClientRect();
      const x0 = sr.left + sr.width / 2 - rr.left, y0 = sr.top + sr.height / 2 - rr.top;
      const titles = [...root.querySelectorAll('*')].filter(n => n.children.length === 0 && (n.textContent || '').trim() && n.getBoundingClientRect().top - rr.top < 110).map(n => n.getBoundingClientRect());
      let x1, y1, k = 0; do { x1 = 24 + Math.random() * (rr.width - 48); y1 = 14 + Math.random() * 28; k++; } while (k < 30 && titles.some(t => x1 + rr.left > t.left - 8 && x1 + rr.left < t.right + 8 && y1 + rr.top > t.top - 8 && y1 + rr.top < t.bottom + 8));
      SKY.push([Math.round(x1), Math.round(y1)]);
      if (reduce) { putSky(x1, y1, SKY.length); return win.setTimeout(res, 150); }
      const star = doc.createElement('div'); star.setAttribute('aria-hidden', 'true');
      star.style.cssText = 'position:absolute;z-index:95;left:0;top:0;width:7px;height:7px;margin:-3.5px 0 0 -3.5px;border-radius:50%;background:#fff;box-shadow:0 0 10px 3px rgba(255,214,10,.75),0 0 2px 1px #FFE680;pointer-events:none';
      root.appendChild(star);
      const cx = (x0 + x1) / 2 + (x1 > x0 ? -60 : 60), cy = Math.min(y0, y1) - 40, frames = [];
      for (let i = 0; i <= 14; i++) { const t = i / 14, u = 1 - t; const x = u * u * x0 + 2 * u * t * cx + t * t * x1, y = u * u * y0 + 2 * u * t * cy + t * t * y1; frames.push({ transform: 'translate(' + x + 'px,' + y + 'px) scale(' + (1 - t * 0.45) + ')' }); }
      const an = star.animate(frames, { duration: 760, easing: 'cubic-bezier(.35,.1,.25,1)', fill: 'forwards' });
      let n = 0; const trail = win.setInterval(() => { if (++n > 12) return win.clearInterval(trail); const m = new win.DOMMatrix(win.getComputedStyle(star).transform); const d = doc.createElement('div'); d.style.cssText = 'position:absolute;z-index:94;left:' + m.e + 'px;top:' + m.f + 'px;width:3px;height:3px;margin:-1.5px 0 0 -1.5px;border-radius:50%;background:#FFE680;pointer-events:none;opacity:.7;transition:opacity .45s,transform .45s'; root.appendChild(d); win.requestAnimationFrame(() => { d.style.opacity = '0'; d.style.transform = 'scale(.3)'; }); win.setTimeout(() => d.remove(), 500); }, 55);
      an.onfinish = () => { star.remove(); const sky = putSky(x1, y1, SKY.length);
        const gl = doc.createElementNS(NS, 'svg'); gl.setAttribute('width', 26); gl.setAttribute('height', 26); gl.setAttribute('viewBox', '-13 -13 26 26'); gl.style.cssText = 'position:absolute;z-index:95;left:' + (x1 - 13) + 'px;top:' + (y1 - 13) + 'px;pointer-events:none;transition:opacity .5s,transform .5s';
        gl.innerHTML = '<path d="M0 -12Q0 0 12 0Q0 0 0 12Q0 0 -12 0Q0 0 0 -12Z" fill="#FFE680"></path>'; root.appendChild(gl);
        win.requestAnimationFrame(() => win.requestAnimationFrame(() => { gl.style.opacity = '0'; gl.style.transform = 'scale(.4) rotate(45deg)'; }));
        win.setTimeout(() => { gl.remove(); res(); }, 380); };
    });
    // ── the sent star IS the transition: it rises to the centre, says what is happening, then opens into the script
    const perform = () => new Promise(res => {
      const AI_MS = ctx.aiDelay != null ? ctx.aiDelay : 2600, MIN_MS = 3000, FAST = false, T0 = Date.now();
      const ifr = win.frameElement, box = ifr && ifr.parentElement; if (!box) return res('plain');
      const P = ifr.ownerDocument, PW = P.defaultView, W = ifr.offsetWidth, H = ifr.offsetHeight, ox = ifr.offsetLeft, oy = ifr.offsetTop;
      if (PW.getComputedStyle(box).position === 'static') box.style.position = 'relative';
      const send = hero.querySelector('[data-send]'), sr = send.getBoundingClientRect(), sx = ox + sr.left + sr.width / 2, sy = oy + sr.top + sr.height / 2;
      const cx = ox + W / 2, cy = oy + H * 0.38;
      const ideaTxt = ((hero.querySelector('[contenteditable="true"]') || {}).textContent || '').trim() || 'Your idea';
      const plat = ((([...hero.querySelectorAll('*')].find(n => n.children.length === 0 && /^for /i.test((n.textContent || '').trim())) || {}).textContent || 'For TikTok').trim().replace(/^for\s+/i, '').replace(/\s*⌄.*/, ''));
      const steps = ['Finding your hook…', 'Lining up the stars', 'Making it sound like you', 'Saving room for your pause', 'Trimming the extra words', 'Warming up the prompter', 'Shaping it for ' + plat, 'Almost camera-ready'];
      const MONO = "ui-monospace,'SF Mono',Menlo,monospace";
      if (!P.__cstPerfCss) { P.__cstPerfCss = 1; const c = P.createElement('style'); c.textContent = '@keyframes cstBreath{0%,100%{transform:translate(-50%,-50%) scale(1.4);opacity:.85}50%{transform:translate(-50%,-50%) scale(1.65);opacity:1}}@keyframes cstHalo{0%,100%{transform:translate(-50%,-50%) scale(.92);opacity:.55}50%{transform:translate(-50%,-50%) scale(1.08);opacity:.9}}@keyframes cstIn{0%{transform:translate(var(--dx),var(--dy)) scale(1);opacity:0}20%{opacity:.85}100%{transform:translate(0,0) scale(.3);opacity:0}}@keyframes cstCaret{0%,49%{opacity:1}50%,100%{opacity:0}}@media (prefers-reduced-motion: reduce){.cstPerf *{animation:none!important}}'; P.head.appendChild(c); }
      const L = P.createElement('div'); L.className = 'cstPerf'; L.style.cssText = 'position:absolute;left:' + ox + 'px;top:' + oy + 'px;width:' + W + 'px;height:' + H + 'px;z-index:200;overflow:hidden;border-radius:inherit;pointer-events:auto';
      const lx = cx - ox, ly = cy - oy;
      L.innerHTML = '<div data-k="cover" style="position:absolute;inset:0;background:#07080E;opacity:0"></div>' +
        '<div data-k="halo" style="position:absolute;left:' + lx + 'px;top:' + ly + 'px;width:170px;height:170px;border-radius:50%;background:radial-gradient(closest-side,rgba(157,140,255,0.34),rgba(157,140,255,0.08) 60%,rgba(157,140,255,0));opacity:0;transform:translate(-50%,-50%);transition:opacity .5s"></div>' +
        '<div data-k="parts" style="position:absolute;left:' + lx + 'px;top:' + ly + 'px;width:0;height:0;opacity:0;transition:opacity .4s"></div>' +
        '<div data-k="txt" style="position:absolute;left:24px;right:24px;top:' + (ly + 104) + 'px;display:flex;flex-direction:column;align-items:center;gap:8px;text-align:center;opacity:0;transform:translateY(8px);transition:opacity .4s .1s,transform .4s .1s;color:#fff">' +
          '<div style="font-size:20px;font-weight:700;letter-spacing:-0.2px">Writing in your voice</div>' +
          '<div style="font-size:15px;line-height:1.35;color:rgba(235,235,245,0.86);max-width:300px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">“' + ideaTxt.replace(/</g, '&lt;') + '”</div>' +
          '<div data-k="step" role="status" aria-live="polite" style="height:22px;margin-top:4px;font-size:16px;font-weight:500;font-style:italic;color:#C4B8FF;transition:opacity .3s,transform .3s">' + steps[0] + '</div></div>' +
        '<div data-k="cancel" role="button" aria-label="Cancel" style="position:absolute;left:50%;bottom:118px;transform:translateX(-50%);height:44px;padding:0 18px;display:flex;align-items:center;font-size:15px;font-weight:600;color:rgba(235,235,245,0.8);cursor:pointer;opacity:0;transition:opacity .3s .3s">Cancel</div>' +
        '<div data-k="ring" style="position:absolute;left:' + lx + 'px;top:' + ly + 'px;width:0;height:0;border-radius:50%;box-shadow:0 0 0 2px rgba(255,230,128,0.9),0 0 18px 4px rgba(180,167,255,0.5);transform:translate(-50%,-50%);opacity:0;pointer-events:none"></div>' +
        '<div data-k="star" style="position:absolute;left:0;top:0;width:10px;height:10px;border-radius:50%;background:#fff;box-shadow:0 0 14px 4px rgba(255,214,10,.8),0 0 3px 1px #FFE680;transform:translate(-50%,-50%);pointer-events:none"></div>';
      box.appendChild(L);
      const q = k => L.querySelector('[data-k="' + k + '"]'), star = q('star'), cover = q('cover');
      const prevT = ifr.style.transition, prevTf = ifr.style.transform, prevF = ifr.style.filter;
      ifr.style.transformOrigin = '50% 40%'; ifr.style.transition = reduce ? 'filter .3s' : 'transform .6s cubic-bezier(.2,.8,.2,1),filter .6s';
      PW.requestAnimationFrame(() => { if (!reduce) ifr.style.transform = 'scale(.94)'; ifr.style.filter = 'brightness(.35) saturate(.7) blur(10px)'; });
      const setStar = (x, y, s) => { star.style.left = (x - ox) + 'px'; star.style.top = (y - oy) + 'px'; star.style.transform = 'translate(-50%,-50%) scale(' + s + ')'; };
      setStar(sx, sy, 0.7);
      // particles gathering toward the star
      const parts = q('parts'); for (let i = 0; i < 12; i++) { const a = Math.PI * (1.05 + Math.random() * 0.9), r = 64 + Math.random() * 70, d = P.createElement('div'); d.style.cssText = 'position:absolute;left:-1.5px;top:-1.5px;width:3px;height:3px;border-radius:50%;background:' + (i % 3 ? '#E4DEFF' : '#FFE680') + ';--dx:' + Math.round(Math.cos(a) * r) + 'px;--dy:' + Math.round(Math.sin(a) * r) + 'px;animation:cstIn ' + (1.6 + Math.random() * 0.9).toFixed(2) + 's ease-in ' + (-Math.random() * 2).toFixed(2) + 's infinite'; parts.appendChild(d); }
      let stepI = 0, stepT = 0, over = false;
      const showWait = () => { if (over) return; cover.style.transition = 'opacity .5s'; cover.style.opacity = '0.84'; q('halo').style.opacity = '1'; parts.style.opacity = '1'; const t = q('txt'); t.style.opacity = '1'; t.style.transform = 'none'; q('cancel').style.opacity = '1';
        if (!reduce) star.style.animation = 'cstBreath 1.6s ease-in-out infinite';
        stepT = PW.setInterval(() => { const el = q('step'); el.style.opacity = '0'; el.style.transform = 'translateY(-4px)'; PW.setTimeout(() => { stepI = (stepI + 1) % (steps.length - 1); el.textContent = steps[stepI]; el.style.transform = 'translateY(4px)'; PW.requestAnimationFrame(() => { el.style.opacity = '1'; el.style.transform = 'none'; }); }, 300); }, 1600); };
      const fly = () => new Promise(r => { if (reduce) { setStar(cx, cy, 1.4); return r(); }
        const mx = (sx + cx) / 2 + 40, my = Math.min(sy, cy) - 60, fr = []; for (let i = 0; i <= 16; i++) { const t = i / 16, u = 1 - t, x = u * u * sx + 2 * u * t * mx + t * t * cx, y = u * u * sy + 2 * u * t * my + t * t * cy; fr.push({ left: (x - ox) + 'px', top: (y - oy) + 'px', transform: 'translate(-50%,-50%) scale(' + (0.7 + t * 0.7) + ')' }); }
        star.animate(fr, { duration: FAST ? 420 : 720, easing: 'cubic-bezier(.3,.1,.25,1)', fill: 'forwards' }).onfinish = () => { setStar(cx, cy, 1.4); star.getAnimations().forEach(a => a.cancel()); r(); }; });
      const restore = () => { ifr.style.transition = 'none'; ifr.style.transform = prevTf; ifr.style.filter = prevF; PW.requestAnimationFrame(() => { ifr.style.transition = prevT; }); };
      const finish = () => { if (over) return; over = true; PW.clearInterval(stepT); PW.clearTimeout(tm);
        const se = q('step'); se.textContent = steps[steps.length - 1]; ['txt', 'cancel', 'parts'].forEach(k => q(k).style.opacity = '0');
        cover.style.transition = 'opacity .22s'; cover.style.opacity = '1'; star.style.animation = 'none';
        if (!reduce) star.animate([{ transform: 'translate(-50%,-50%) scale(1.4)', filter: 'brightness(1)' }, { transform: 'translate(-50%,-50%) scale(2.6)', filter: 'brightness(1.8)' }], { duration: 220, easing: 'ease-out', fill: 'forwards' });
        PW.setTimeout(() => {
          restore(); let loaded = false;
          const onLoad = () => { if (loaded) return; loaded = true; ifr.removeEventListener('load', onLoad); PW.setTimeout(() => { holdWriting(); reveal(); }, 220); };
          ifr.addEventListener('load', onLoad); res('go'); PW.setTimeout(onLoad, 2500);
        }, 240); };
      let held = [];
      const holdWriting = () => { try { held = ifr.contentDocument.getAnimations().filter(a => /^(sc\d+|shimx)$/.test(a.animationName || '')); held.forEach(a => { a.pause(); a.currentTime = 0; }); } catch (e) { held = []; } };
      const playWriting = () => { held.forEach(a => { try { a.currentTime = 0; a.play(); } catch (e) {} }); held = []; };
      const reveal = () => {
        const nd = ifr.contentDocument; let tx = ox + 32, ty = oy + 200;
        try { const tgt = [...nd.querySelectorAll('[contenteditable="true"],h1,h2')].find(n => n.getBoundingClientRect().height > 10 && n.getBoundingClientRect().top > 80); if (tgt) { const r = tgt.getBoundingClientRect(); tx = ox + r.left + 2; ty = oy + r.top + Math.min(r.height, 28) / 2; } } catch (e) {}
        const ring = q('ring'), diag = Math.hypot(W, H);
        if (reduce) { cover.style.transition = 'opacity .3s'; cover.style.opacity = '0'; star.style.opacity = '0'; q('halo').style.opacity = '0'; return PW.setTimeout(() => { playWriting(); L.remove(); }, 320); }
        const t0 = PW.performance.now(), D = 560;
        const step = now => { const t = Math.min(1, (now - t0) / D), e = 1 - Math.pow(1 - t, 3), R = e * diag;
          const m = 'radial-gradient(circle at ' + lx + 'px ' + ly + 'px, transparent ' + R + 'px, #000 ' + (R + 1) + 'px)'; cover.style.webkitMaskImage = m; cover.style.maskImage = m;
          ring.style.width = ring.style.height = (2 * R) + 'px'; ring.style.opacity = (t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85).toFixed(2); q('halo').style.opacity = (1 - t).toFixed(2);
          if (t < 1) PW.requestAnimationFrame(step); };
        PW.requestAnimationFrame(step);
        star.getAnimations().forEach(a => a.cancel());
        star.animate([{ left: lx + 'px', top: ly + 'px', transform: 'translate(-50%,-50%) scale(2)' }, { left: (tx - ox) + 'px', top: (ty - oy) + 'px', transform: 'translate(-50%,-50%) scale(.6)' }], { duration: 420, delay: 120, easing: 'cubic-bezier(.4,0,.2,1)', fill: 'forwards' }).onfinish = () => {
          star.style.opacity = '0'; playWriting(); const c = P.createElement('div'); c.style.cssText = 'position:absolute;left:' + (tx - ox) + 'px;top:' + (ty - oy - 11) + 'px;width:2px;height:22px;border-radius:1px;background:#FFD60A;box-shadow:0 0 6px rgba(255,214,10,.7);animation:cstCaret 1s steps(1) infinite'; L.appendChild(c);
          L.style.pointerEvents = 'none'; PW.setTimeout(() => { c.style.transition = 'opacity .3s'; c.style.opacity = '0'; PW.setTimeout(() => L.remove(), 320); }, 900); };
      };
      const tm = PW.setTimeout(finish, Math.max(AI_MS, MIN_MS) - (Date.now() - T0));
      q('cancel').addEventListener('click', ev => { ev.stopPropagation(); if (over) return; over = true; PW.clearInterval(stepT); PW.clearTimeout(tm);
        ['txt', 'cancel', 'parts', 'halo', 'cover'].forEach(k => q(k).style.opacity = '0'); star.style.animation = 'none';
        star.animate([{ left: lx + 'px', top: ly + 'px', opacity: 1 }, { left: (sx - ox) + 'px', top: (sy - oy) + 'px', opacity: 0 }], { duration: 420, easing: 'cubic-bezier(.4,0,.2,1)', fill: 'forwards' });
        ifr.style.transition = 'transform .4s,filter .4s'; ifr.style.transform = prevTf; ifr.style.filter = prevF; PW.setTimeout(() => { ifr.style.transition = prevT; L.remove(); }, 440);
        ctx.props.onAction && ctx.props.onAction(ctx.props.id, ['__toast'], { x: 0, y: 0, msg: 'Cancelled · idea kept' }); res('cancel'); }, true);
      fly().then(() => { if (!FAST) showWait(); });
    });
    const go = ev => { if (going || doc.__cstPass) return; { const id0 = hero.querySelector('[data-idea]'); if (id0 && !id0.textContent.trim()) { id0.textContent = hero.dataset.suggest || 'a weekday budget tip, under a minute'; id0.dispatchEvent(new Event('input', { bubbles: true })); } } ev.preventDefault(); ev.stopImmediatePropagation(); going = true;
      const rr = root.getBoundingClientRect(); let x1 = 24 + Math.random() * (rr.width - 48), y1 = 14 + Math.random() * 28; SKY.push([Math.round(x1), Math.round(y1)]);
      perform().then(r => { if (r === 'go' || r === 'plain') { if (r === 'go') ctx.__quietSend = true; doc.__cstPass = 1; const b = hero.querySelector('[data-send]'); if (b) b.click(); doc.__cstPass = 0; } going = false; }); };
    const idea = hero.querySelector('[data-idea]') || hero.querySelector('[contenteditable="true"]');
    win.addEventListener('click', ev => { if (ev.target.closest && ev.target.closest('[data-send]') && hero.contains(ev.target)) go(ev); }, true);
    win.addEventListener('keydown', ev => { if (ev.key === 'Enter' && idea && ev.target === idea) go(ev); }, true);
  };
})();
