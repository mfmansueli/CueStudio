(function () {
  // LET'S CUE! card: an always-on, quiet sky (drifting dust, a slow violet nebula, twinkles with cross glints, a shooting star every 12 s).
  // Sending an idea launches a star from the arrow into the sky above; it stays there as one of “your stars”.
  window.CueConstellation = function (doc, ctx) {
    if (doc.__cst) return; const hero = [...doc.querySelectorAll('.hero')].find(h => /LET.S CUE/i.test(h.textContent)); if (!hero) return; doc.__cst = 1;
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
    hero.insertBefore(neb, hero.children[0] || null); hero.insertBefore(dust, neb.nextSibling); hero.insertBefore(svg, dust.nextSibling);
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
    const go = ev => { if (going || doc.__cstPass) return; ev.preventDefault(); ev.stopImmediatePropagation(); going = true;
      launch().then(() => { doc.__cstPass = 1; const b = hero.querySelector('[data-send]'); if (b) b.click(); doc.__cstPass = 0; going = false; }); };
    const idea = hero.querySelector('[contenteditable="true"]');
    win.addEventListener('click', ev => { if (ev.target.closest && ev.target.closest('[data-send]') && hero.contains(ev.target)) go(ev); }, true);
    win.addEventListener('keydown', ev => { if (ev.key === 'Enter' && idea && ev.target === idea) go(ev); }, true);
  };
})();
