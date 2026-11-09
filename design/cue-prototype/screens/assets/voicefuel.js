/* My Cue Voice's fuel tank and the ship's flight (9.3). Ported number by number from the app:
   VoiceFuelTank, VoiceFuelPainter, VoiceShipFlight, SpaceshipPainter (drawCraft, drawCraftFront), Palette.Fuel / Palette.Sky (read 9 Nov 2026; DESIGN_PROJECT §4).
   A tube of 18 pt with two layers of plasma, a lit front, a pulse of light every 2.8 s and quarter marks. When the page opens, or when Cue knows more,
   the sky's ship runs the tube in 1.25 s pouring the plasma, then flies in three acts (crouch 0.28 s, launch 0.45 s along a curve, 0.70 s turning to face
   the viewer and growing as 1/z up to 8x, with rings of force and a flash) and leaves by the top right corner.
   Use:  var t = VoiceFuel.tank(canvas, {level:0.59, overlay:overlayCanvas});  t.launch();   Reduce Motion: the full tube, no ship. */
(function (g) {
  'use strict';
  var FUEL = { tank: '#0D0B26', rim: 'rgba(110,116,150,.55)', fuel: '#FFD60A', fuelDeep: '#F5A300', fuelBack: '#B86E00', meniscus: '#FFF6C8', current: '#FFFBE6', forceRing: '#D8F4FF' };
  var SKY = { hull: '#E4E9FF', hullShade: '#8E97C9', wing: '#3F43B0', engine: '#5FD4FF', trailFar: '#7A6CE0', port: '#FF7A8A', starboard: '#7DFFC8' };
  var RUN = 1.25, TANK_H = 18, SHIP_LEN = 27, SHIP_LANE = 44, FLIGHT_H = 400, INSET = 40, TURN_H = 66, FRONT = 32;
  var ANTIC = 0.28, LAUNCH = 0.45, APPROACH = 0.70, DURATION = ANTIC + LAUNCH + APPROACH, NEAREST = 0.12, PASSING = { dx: 30, dy: -27 }, PITCH = 0.30;

  function hex(c) { return [parseInt(c.substr(1, 2), 16), parseInt(c.substr(3, 2), 16), parseInt(c.substr(5, 2), 16)]; }
  function mix(a, b, t) { var x = hex(a), y = hex(b); return 'rgb(' + Math.round(x[0] + (y[0] - x[0]) * t) + ',' + Math.round(x[1] + (y[1] - x[1]) * t) + ',' + Math.round(x[2] + (y[2] - x[2]) * t) + ')'; }
  function rgba(c, a) { var x = hex(c); return 'rgba(' + x[0] + ',' + x[1] + ',' + x[2] + ',' + Math.max(0, Math.min(1, a)) + ')'; }
  function easeInOut(v) { return v < 0.5 ? 4 * v * v * v : 1 - Math.pow(-2 * v + 2, 3) / 2; }
  function easeIn(v) { return v * v; }
  function easeOut(v) { return 1 - Math.pow(1 - v, 3); }
  function poly(ctx, pts, s) { ctx.beginPath(); pts.forEach(function (p, i) { if (i) ctx.lineTo(p[0] * s, p[1] * s); else ctx.moveTo(p[0] * s, p[1] * s); }); ctx.closePath(); }
  function ell(ctx, x, y, w, h) { ctx.beginPath(); ctx.ellipse(x + w / 2, y + h / 2, Math.abs(w / 2), Math.abs(h / 2), 0, 0, Math.PI * 2); }
  function radial(ctx, cx, cy, r0, r1, stops) { var gr = ctx.createRadialGradient(cx, cy, r0, cx, cy, r1); stops.forEach(function (s) { gr.addColorStop(s[0], s[1]); }); return gr; }

  /* ---------- the craft (SpaceshipPainter) ---------- */
  function drawCraft(ctx, x, y, heading, len, time, bank, thrust) {
    bank = bank || 0; thrust = thrust == null ? 1 : thrust;
    ctx.save(); ctx.translate(x, y); ctx.rotate(heading);
    [-1, 1].forEach(function (s) {
      var lowered = Math.max(0, -s * bank), raised = Math.max(0, s * bank);
      var col = SKY.wing; if (lowered) col = mix('#3F43B0', '#000000', .45 * lowered); if (raised) col = mix('#3F43B0', '#FFFFFF', .15 * raised);
      poly(ctx, [[.14, s * .07], [-.34, s * .38], [-.42, s * .36], [-.30, s * .17], [-.46, s * .06]], len); ctx.fillStyle = col; ctx.fill();
      ctx.beginPath(); ctx.moveTo(.14 * len, s * .07 * len); ctx.lineTo(-.34 * len, s * .38 * len);
      ctx.strokeStyle = rgba(SKY.engine, .85); ctx.lineWidth = Math.max(.4, len * .028); ctx.stroke();
    });
    var flick = .88 + .12 * Math.sin(time * 19), gx = -.5 * len, reach = len * .35 * thrust;
    ctx.fillStyle = radial(ctx, gx, 0, 0, reach, [[0, rgba(SKY.engine, Math.min(.85, .5 * thrust) * flick)], [1, rgba(SKY.engine, 0)]]);
    ctx.beginPath(); ctx.arc(gx, 0, reach, 0, Math.PI * 2); ctx.fill();
    poly(ctx, [[.5, 0], [.10, -.08], [-.5, -.06], [-.40, 0]], len); ctx.fillStyle = SKY.hull; ctx.fill();
    poly(ctx, [[.5, 0], [-.40, 0], [-.5, .06], [.10, .08]], len); ctx.fillStyle = SKY.hullShade; ctx.fill();
    [-1, 1].forEach(function (s) { poly(ctx, [[-.46, s * .049], [-.53, s * .049], [-.53, s * .021], [-.46, s * .021]], len); ctx.fillStyle = SKY.engine; ctx.fill(); });
    poly(ctx, [[.31, 0], [.20, -.028], [.14, 0], [.20, .028]], len); ctx.fillStyle = mix('#5FD4FF', '#FFFFFF', .6); ctx.fill();
    var ph = (time % 2.8) / 2.8;
    [[-1, SKY.port, ph < .05], [1, SKY.starboard, ph >= .5 && ph < .55]].forEach(function (l) {
      var cx = -.38 * len, cy = l[0] * .375 * len, st = l[2] ? 1 : .3;
      ctx.fillStyle = radial(ctx, cx, cy, 0, len * .11, [[0, rgba(l[1], .6 * st)], [1, rgba(l[1], 0)]]); ctx.beginPath(); ctx.arc(cx, cy, len * .11, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = rgba(l[1], st); ctx.beginPath(); ctx.arc(cx, cy, len * .035, 0, Math.PI * 2); ctx.fill();
    });
    ctx.restore();
  }

  function drawCraftFront(ctx, x, y, size, opening, thrust, time) {
    ctx.save(); ctx.translate(x, y); ctx.scale(1, Math.max(.04, opening));
    var flick = .88 + .12 * Math.sin(time * 19), halo = size * .34 * Math.min(1.6, thrust);
    ctx.fillStyle = radial(ctx, 0, 0, size * .08, halo, [[0, rgba(SKY.engine, .45 * flick)], [.5, rgba(SKY.engine, .12 * flick)], [1, rgba(SKY.engine, 0)]]);
    ell(ctx, -halo, -halo * .8, halo * 2, halo * 1.6); ctx.fill();
    [-1, 1].forEach(function (s) {
      poly(ctx, [[s * .12, -.06], [s * .50, .06], [s * .50, .12], [s * .13, .15]], size);
      var gr = ctx.createLinearGradient(0, -.06 * size, 0, .15 * size); gr.addColorStop(0, mix(SKY.wing, '#FFFFFF', .18)); gr.addColorStop(1, mix(SKY.wing, '#000000', .35)); ctx.fillStyle = gr; ctx.fill();
      ctx.beginPath(); ctx.moveTo(s * .12 * size, -.06 * size); ctx.lineTo(s * .50 * size, .06 * size);
      ctx.strokeStyle = rgba(SKY.engine, .95); ctx.lineWidth = Math.max(.6, size * .022); ctx.lineCap = 'round'; ctx.stroke();
      var tx = s * .50 * size, ty = .09 * size, lit = s < 0 ? SKY.port : SKY.starboard, pulse = .6 + .4 * Math.sin(time * 9 + s), gl = size * .05;
      ctx.fillStyle = radial(ctx, tx, ty, 0, gl, [[0, rgba(lit, .8 * pulse)], [1, rgba(lit, 0)]]); ctx.beginPath(); ctx.arc(tx, ty, gl, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = rgba(lit, pulse); ctx.beginPath(); ctx.arc(tx, ty, gl * .3, 0, Math.PI * 2); ctx.fill();
    });
    poly(ctx, [[-.025, -.13], [0, -.24], [.025, -.13]], size); ctx.fillStyle = SKY.hullShade; ctx.fill();
    var hy = -size * .14, gr2 = ctx.createLinearGradient(0, hy, 0, hy + size * .28);
    gr2.addColorStop(0, SKY.hull); gr2.addColorStop(.5, SKY.hullShade); gr2.addColorStop(1, mix(SKY.wing, SKY.hullShade, .5));
    ctx.fillStyle = gr2; ell(ctx, -size * .15, hy, size * .30, size * .28); ctx.fill();
    var vy = -size * .085, gr3 = ctx.createLinearGradient(0, vy, 0, vy + size * .085);
    gr3.addColorStop(0, mix(SKY.engine, '#FFFFFF', .65)); gr3.addColorStop(1, mix(SKY.engine, SKY.wing, .55));
    ctx.fillStyle = gr3; ell(ctx, -size * .09, vy, size * .18, size * .085); ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,.9)'; ell(ctx, -size * .06, -size * .078, size * .05, size * .022); ctx.fill();
    ctx.restore();
  }

  /* ---------- the tank (VoiceFuelPainter) ---------- */
  function surfaceOf(target, elapsed) {
    if (elapsed == null) return { fill: target, lean: 0, surge: 0, wave: .8 };
    var run = Math.min(1, elapsed / RUN), fill = target * (1 - Math.pow(1 - run, 3));
    var speed = target * 3 * Math.pow(1 - run, 2) / RUN, lean = elapsed < RUN ? Math.min(7, speed * .018) : 0, after = Math.max(0, elapsed - RUN);
    return { fill: fill, lean: lean, surge: elapsed < RUN ? 0 : 6 * Math.exp(-3.4 * after) * Math.sin(2 * Math.PI * 1.7 * after), wave: 1 + 1.6 * Math.exp(-2 * after) };
  }
  function front(sf, f, time, phase) {
    var ripple = sf.wave * Math.sin(f * Math.PI * 2 + time * 4.6 + phase) + sf.wave * .45 * Math.sin(f * Math.PI * 4.2 - time * 7.4 + phase);
    return sf.fill + ripple - sf.lean * (1 - f) + sf.surge * (1 - f * .6);
  }
  function plasmaPath(ctx, sf, time, phase, ahead) {
    ctx.beginPath(); ctx.moveTo(0, 0);
    for (var i = 0; i <= 12; i++) { var f = i / 12; ctx.lineTo(Math.max(0, front(sf, f, time, phase) + ahead), TANK_H * f); }
    ctx.lineTo(0, TANK_H); ctx.closePath();
  }
  function drawTank(ctx, w, level, elapsed, time) {
    var target = w * Math.max(0, Math.min(1, level)), sf = surfaceOf(target, elapsed), r = TANK_H / 2;
    function tube() { ctx.beginPath(); ctx.moveTo(r, 0); ctx.lineTo(w - r, 0); ctx.arc(w - r, r, r, -Math.PI / 2, Math.PI / 2); ctx.lineTo(r, TANK_H); ctx.arc(r, r, r, Math.PI / 2, Math.PI * 1.5); ctx.closePath(); }
    ctx.clearRect(0, 0, w, TANK_H);
    tube(); ctx.fillStyle = FUEL.tank; ctx.fill();
    ctx.save(); tube(); ctx.clip();
    if (sf.fill > .5) {
      plasmaPath(ctx, sf, time, 1.9, 2.2); ctx.fillStyle = FUEL.fuelBack; ctx.fill();
      plasmaPath(ctx, sf, time, 0, 0); var gr = ctx.createLinearGradient(0, 2, 0, TANK_H); gr.addColorStop(0, FUEL.fuel); gr.addColorStop(1, FUEL.fuelDeep); ctx.fillStyle = gr; ctx.fill();
      ctx.save(); plasmaPath(ctx, sf, time, 0, 0); ctx.clip();
      var centre = -24 + (sf.fill + 48) * ((time / 2.8) % 1), cg = ctx.createLinearGradient(centre - 22, 0, centre + 22, TANK_H);
      cg.addColorStop(0, rgba(FUEL.current, 0)); cg.addColorStop(.5, rgba(FUEL.current, .6)); cg.addColorStop(1, rgba(FUEL.current, 0));
      ctx.fillStyle = cg; ctx.fillRect(0, 0, w, TANK_H); ctx.restore();
      ctx.beginPath(); for (var i = 0; i <= 12; i++) { var f = i / 12, px = front(sf, f, time, 0), py = TANK_H * f; if (i) ctx.lineTo(px, py); else ctx.moveTo(px, py); }
      ctx.lineCap = 'round'; ctx.strokeStyle = rgba(FUEL.meniscus, .3); ctx.lineWidth = 4; ctx.stroke(); ctx.strokeStyle = FUEL.meniscus; ctx.lineWidth = 1.2; ctx.stroke();
    }
    var sh = ctx.createLinearGradient(0, 0, 0, 6); sh.addColorStop(0, 'rgba(0,0,0,.45)'); sh.addColorStop(1, 'rgba(0,0,0,0)'); ctx.fillStyle = sh; ctx.fillRect(0, 0, w, 6);
    [[2.6, 'rgba(255,255,255,.32)'], [TANK_H - 2.4, 'rgba(255,255,255,.096)']].forEach(function (l) { ctx.beginPath(); ctx.moveTo(r, l[0]); ctx.lineTo(w - r, l[0]); ctx.strokeStyle = l[1]; ctx.lineWidth = 1.1; ctx.lineCap = 'round'; ctx.stroke(); });
    for (var q = 1; q <= 3; q++) { var qx = w * q / 4; ctx.strokeStyle = FUEL.rim; ctx.lineWidth = 1; [[0, 4], [TANK_H - 4, TANK_H]].forEach(function (m) { ctx.beginPath(); ctx.moveTo(qx, m[0]); ctx.lineTo(qx, m[1]); ctx.stroke(); }); }
    ctx.restore();
    tube(); ctx.strokeStyle = FUEL.rim; ctx.lineWidth = 1; ctx.stroke();
  }
  function runPos(fill, w) { var half = SHIP_LEN * .5; return { x: Math.min(w - half, Math.max(half, fill + SHIP_LEN * .35)), y: TANK_H / 2 }; }

  /* ---------- the flight (VoiceShipFlight) ---------- */
  function bez(o, a) {
    var s = { x: o.x - 5, y: o.y }, rightmost = 2 * a.x;
    return { s: s, c1: { x: s.x + Math.min(85, Math.max(36, (rightmost - 20 - s.x) / .45)), y: s.y - 4 }, c2: { x: Math.max(a.x + 34, Math.min(s.x + 30, rightmost - 30)), y: a.y + 40 }, e: a };
  }
  function bpt(b, t) { var u = 1 - t, A = u * u * u, B = 3 * u * u * t, C = 3 * u * t * t, D = t * t * t; return { x: A * b.s.x + B * b.c1.x + C * b.c2.x + D * b.e.x, y: A * b.s.y + B * b.c1.y + C * b.c2.y + D * b.e.y }; }
  function btan(b, t) { var u = 1 - t, A = 3 * u * u, B = 6 * u * t, C = 3 * t * t; return { dx: A * (b.c1.x - b.s.x) + B * (b.c2.x - b.c1.x) + C * (b.e.x - b.c2.x), dy: A * (b.c1.y - b.s.y) + B * (b.c2.y - b.c1.y) + C * (b.e.y - b.c2.y) }; }
  function bhead(b, t) { var d = btan(b, t); return Math.atan2(d.dy, d.dx); }
  function angDiff(a, b) { var d = a - b; return Math.atan2(Math.sin(d), Math.cos(d)); }
  function timing(p) { return -1.4 * Math.pow(p, 3) + 2.4 * p * p; }
  function speedOf(p) { return (-4.2 * p * p + 4.8 * p) / 1.372; }
  function pose(t, o, a) {
    if (t < 0 || t >= DURATION) return null;
    if (t < ANTIC) { var e = easeInOut(t / ANTIC); return { view: 'top', x: o.x - 5 * e, y: o.y, heading: 0, along: 1 - .12 * e, across: 1 + .06 * e, bank: 0, thrust: 1 + 1.4 * e, opacity: 1, glow: 0, flash: 0 }; }
    var l = t - ANTIC, path = bez(o, a);
    if (l < LAUNCH) {
      var p = l / LAUNCH, al = timing(p), heading = bhead(path, Math.min(1, al + .04)), turn = angDiff(bhead(path, Math.min(1, al + .07)), bhead(path, Math.max(0, al - .07)));
      var ps = 1 - PITCH, pitch = p > ps ? easeIn((p - ps) / PITCH) : 0, bank = Math.max(-1, Math.min(1, -turn * 1.5)) * (1 - pitch), sp = speedOf(p), pos = bpt(path, al);
      return { view: 'top', x: pos.x, y: pos.y, heading: heading, along: (1 + .18 * sp) * (1 - .95 * pitch), across: Math.cos(bank * Math.PI / 3), bank: bank, thrust: 2.4 - .5 * p, opacity: 1, glow: 0, flash: 0 };
    }
    var pr = (l - LAUNCH) / APPROACH, dist = 1 - (1 - NEAREST) * Math.pow(pr, 1.15), scale = 1 / dist, reach = scale - 1;
    var came = btan(path, 1), cl = Math.max(1, Math.hypot(came.dx, came.dy)), carry = 16 * (1 - Math.exp(-6 * pr));
    var ax = -PASSING.dy, ay = PASSING.dx, al2 = Math.hypot(ax, ay), curve = 10 * Math.sin(Math.PI * pr), near = Math.max(0, (pr - .82) / .18);
    return { view: 'front', x: a.x + PASSING.dx * reach + came.dx / cl * carry + ax / al2 * curve, y: a.y + PASSING.dy * reach + came.dy / cl * carry + ay / al2 * curve,
      scale: scale, opening: easeOut(Math.min(1, pr / .12)), roll: .28 * (1 - easeOut(Math.min(1, pr * 3))) - .16 * Math.sin(Math.PI * pr),
      thrust: 1.8 + .6 * pr, opacity: 1 - near * near, glow: Math.min(1, reach / 6), flash: near > 0 ? Math.sin(Math.PI * near) : 0 };
  }
  function ring(ctx, cx, cy, radius, squash, width, op) {
    ctx.beginPath(); ctx.ellipse(cx, cy, radius, radius * squash, 0, 0, Math.PI * 2);
    ctx.strokeStyle = rgba(SKY.engine, .22 * op); ctx.lineWidth = width * 4; ctx.stroke();
    ctx.strokeStyle = rgba(FUEL.forceRing, op); ctx.lineWidth = width; ctx.stroke();
  }
  /* draws in the flight canvas' own coordinates: the tank's bottom edge at y = FLIGHT_H, its left at x = INSET */
  function drawFlight(ctx, tankW, level, elapsed, time) {
    var tankX = INSET, tankY = FLIGHT_H - TANK_H, lvl = Math.max(0, Math.min(1, level));
    var rp = runPos(tankW * lvl, tankW), o = { x: tankX + rp.x, y: tankY + rp.y }, a = { x: tankX + tankW / 2, y: tankY - TURN_H };
    var m = elapsed - RUN, ps = pose(m, o, a); if (!ps) return;
    if (ps.view === 'top') {
      if (m > ANTIC) {
        var prev = null;
        for (var s = 0; s <= 14; s++) {
          var fr = s / 14, at = Math.max(ANTIC, m - .2 * fr), pp = pose(at, o, a); if (!pp || pp.view !== 'top') continue;
          var tail = { x: pp.x - Math.cos(pp.heading) * SHIP_LEN * .5 * pp.along, y: pp.y - Math.sin(pp.heading) * SHIP_LEN * .5 * pp.along };
          if (prev) { var col = mix(SKY.engine, SKY.trailFar, fr), fade = Math.pow(1 - fr, 1.4);
            ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(prev.x, prev.y); ctx.lineTo(tail.x, tail.y);
            ctx.strokeStyle = col.replace('rgb', 'rgba').replace(')', ',' + .18 * fade + ')'); ctx.lineWidth = 5 * (1 - fr * .7); ctx.stroke();
            ctx.strokeStyle = col.replace('rgb', 'rgba').replace(')', ',' + .9 * fade + ')'); ctx.lineWidth = 1.4 * (1 - fr * .8); ctx.stroke(); }
          prev = tail;
        }
      }
      ctx.save(); ctx.globalAlpha = ps.opacity; ctx.translate(ps.x, ps.y); ctx.rotate(ps.heading); ctx.scale(Math.max(.02, ps.along), ps.across);
      drawCraft(ctx, 0, 0, 0, SHIP_LEN, time, ps.bank, ps.thrust); ctx.restore();
    } else {
      if (ps.glow > 0) { var rad = FRONT * ps.scale * 1.6 + 40; ctx.fillStyle = radial(ctx, ps.x, ps.y, 0, rad, [[0, rgba(SKY.engine, .16 * ps.glow * ps.opacity)], [1, rgba(SKY.engine, 0)]]); ctx.beginPath(); ctx.arc(ps.x, ps.y, rad, 0, Math.PI * 2); ctx.fill(); }
      var boost = ANTIC + LAUNCH, since = m - boost;
      if (since >= 0) {
        if (since < .42) {
          var sp = since / .42, rr = 12 + 105 * easeOut(sp); ring(ctx, a.x, a.y, rr, .78, 2.2 * (1 - sp) + .5, Math.pow(1 - sp, 1.8));
          if (since < .14) { var fl = 1 - since / .14, gl = 44; ctx.fillStyle = radial(ctx, a.x, a.y, 0, gl, [[0, 'rgba(255,255,255,' + .7 * fl + ')'], [.5, rgba(SKY.engine, .3 * fl)], [1, 'rgba(0,0,0,0)']]); ctx.beginPath(); ctx.arc(a.x, a.y, gl, 0, Math.PI * 2); ctx.fill(); }
        }
        for (var em = boost + .06; em < m; em += .08) {
          var age = m - em, th = age < .4 ? pose(em, o, a) : null;
          if (th && th.view === 'front') { var sz = FRONT * th.scale, fd = Math.pow(1 - age / .4, 1.6) * ps.opacity; ring(ctx, th.x, th.y, sz * (.34 + 1.7 * age), .74, Math.max(.6, sz * .05 * (1 - age / .4)), .8 * fd); }
        }
      }
      [.05, .025].forEach(function (lag) { if (ps.scale > 3) { var e = pose(m - lag, o, a); if (e && e.view === 'front') { ctx.save(); ctx.globalAlpha = .22 * ps.opacity; ctx.translate(e.x, e.y); ctx.rotate(e.roll); drawCraftFront(ctx, 0, 0, FRONT * e.scale, e.opening, e.thrust, time); ctx.restore(); } } });
      ctx.save(); ctx.globalAlpha = ps.opacity; ctx.translate(ps.x, ps.y); ctx.rotate(ps.roll); drawCraftFront(ctx, 0, 0, FRONT * ps.scale, ps.opening, ps.thrust, time); ctx.restore();
      if (ps.flash > 0) { var fr2 = FRONT * ps.scale * .9; ctx.fillStyle = radial(ctx, ps.x, ps.y, 0, fr2, [[0, 'rgba(255,255,255,' + .6 * ps.flash + ')'], [.5, rgba(SKY.engine, .25 * ps.flash)], [1, 'rgba(0,0,0,0)']]); ctx.beginPath(); ctx.arc(ps.x, ps.y, fr2, 0, Math.PI * 2); ctx.fill(); }
    }
  }

  /* ---------- the view (VoiceFuelTank) ---------- */
  g.VoiceFuel = {
    DURATION: RUN + DURATION,
    /* tank: the canvas the tube is drawn in (its CSS width is the tube's); opts.level 0…1; opts.overlay a canvas over the whole phone for the ship. */
    tank: function (canvas, opts) {
      var level = opts.level, overlay = opts.overlay, w = canvas.clientWidth || canvas.width, dpr = Math.min(2, g.devicePixelRatio || 1);
      var rm = g.matchMedia && g.matchMedia('(prefers-reduced-motion: reduce)').matches, start = null, raf = 0;
      canvas.width = w * dpr; canvas.height = TANK_H * dpr; canvas.style.height = TANK_H + 'px';
      var ctx = canvas.getContext('2d'), octx = overlay ? overlay.getContext('2d') : null;
      if (octx) { overlay.width = overlay.clientWidth * dpr; overlay.height = overlay.clientHeight * dpr; }
      function frame(now) {
        var time = now / 1000, el = rm ? null : (start == null ? 0 : (now - start) / 1000);
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0); drawTank(ctx, w, level, el, time);
        if (octx) {
          octx.setTransform(dpr, 0, 0, dpr, 0, 0); octx.clearRect(0, 0, overlay.clientWidth, overlay.clientHeight);
          if (el != null && start != null && el < RUN + DURATION) {
            var r = canvas.getBoundingClientRect(), or = overlay.getBoundingClientRect();
            var k = or.width / overlay.clientWidth || 1, left = (r.left - or.left) / k, bottom = (r.bottom - or.top) / k, top = (r.top - or.top) / k;
            if (el <= RUN) { octx.save(); octx.translate(left, top + TANK_H / 2 - SHIP_LANE / 2); var sf = surfaceOf(w * Math.max(0, Math.min(1, level)), el), rp = runPos(sf.fill, w);
              drawCraft(octx, rp.x, SHIP_LANE / 2, 0, SHIP_LEN, time, 0, 1.3); octx.restore(); }
            else { octx.save(); octx.translate(left - INSET, bottom - FLIGHT_H); drawFlight(octx, w, level, el, time); octx.restore(); }
          }
        }
        if (rm) return;
        raf = requestAnimationFrame(frame);
      }
      return {
        launch: function (newLevel) { if (newLevel != null) level = newLevel; start = performance.now(); cancelAnimationFrame(raf); raf = requestAnimationFrame(frame); },
        set: function (v) { level = v; },
        stop: function () { cancelAnimationFrame(raf); }
      };
    }
  };
})(window);
