/* Ultra AI's scenes, drawn from the app code (Cue Studio/Screens/Scripts/Transition/UltraWaitScene.swift, UltraWaitTimeline.swift,
   UltraSceneMoment.swift, UltraPassOrbit.swift; Screens/Shared/Ultra/UltraConsentHero.swift). Same numbers, same names.
   Two things live here:
     UltraWait  the galaxy round the star while Ultra AI writes (two layers: back under the star, front over it), the ring of passes,
                the moons, the sky, the finish (everything falls into the star, flash, wave).
     UltraHero  the ✦ igniting in its galaxy at the top of the "Meet Ultra AI" sheet.
   Every constant that changes the pace is at the top, so the prototype can be slowed down or sped up for a take. */
(function (g) {
  'use strict';
  var TAU = Math.PI * 2;
  var unit = function (v) { var r = Math.sin(v * 12.9898) * 43758.5453; return r - Math.floor(r); };
  var ease = function (v) { v = Math.min(1, Math.max(0, v)); return v * v * (3 - 2 * v); };
  var smooth = function (lo, hi, v) { return ease((v - lo) / (hi - lo)); };
  var wrapped = function (a) { var t = (a + Math.PI) % TAU; return (t < 0 ? t + TAU : t) - Math.PI; };
  var hex = function (h) { return [(h >> 16) & 255, (h >> 8) & 255, h & 255]; };
  var rgba = function (c, a) { return 'rgba(' + Math.round(c[0]) + ',' + Math.round(c[1]) + ',' + Math.round(c[2]) + ',' + Math.max(0, Math.min(1, a)).toFixed(3) + ')'; };
  var mix = function (a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; };
  var WHITE = [255, 255, 255], BLACK = [0, 0, 0];

  /* Palette (Palette.swift, Palette+Scripts.swift, Palette+World.swift, Palette+Universe.swift) */
  var C = {
    ai: hex(0xB4A7FF), aiStrong: hex(0xE4DEFF), skyStarYou: hex(0xFFE680), starCream: hex(0xFFF6C2), starWarm: hex(0xFFF0A8), starGold: hex(0xFFE680),
    ultraStarGlow: hex(0xA493FF), ultraBeam: hex(0xEDEAFF), halo: hex(0x9D8CFF),
    dust: [hex(0x9D8CFF), hex(0xE4DEFF), hex(0x7B6CFF), hex(0xB4A7FF)],
    moons: [hex(0x9D8CFF), hex(0xF4F2FF), hex(0xFFD60A)],
    comets: [hex(0xFFE680), hex(0xCFC6FF), hex(0x8FD3FF)],
    glow: [hex(0x9D8CFF), hex(0xE4DEFF), hex(0xFFD60A), hex(0xB4A7FF), hex(0x7B6CFF), hex(0x9D8CFF)]
  };

  /* ---------- shared drawing ---------- */
  function disc(ctx, x, y, r) { ctx.beginPath(); ctx.arc(x, y, Math.max(0.01, r), 0, TAU); }
  function glowDot(ctx, x, y, r, stops) {
    var gr = ctx.createRadialGradient(x, y, 0, x, y, r);
    stops.forEach(function (s) { gr.addColorStop(s[0], s[1]); });
    ctx.fillStyle = gr; disc(ctx, x, y, r); ctx.fill();
  }
  /* SparkShape.path: eight points, the even ones at the radius, the odd ones at the waist */
  function spark(ctx, x, y, r, turn, waist) {
    waist = waist == null ? 0.28 : waist; turn = turn || 0;
    ctx.beginPath();
    for (var i = 0; i < 8; i++) {
      var a = turn + i * Math.PI / 4 - Math.PI / 2, reach = i % 2 === 0 ? r : r * waist;
      var px = x + reach * Math.cos(a), py = y + reach * Math.sin(a);
      if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    }
    ctx.closePath();
  }
  function setup(canvas, w, h) {
    var dpr = Math.min(2, g.devicePixelRatio || 1);
    canvas.width = w * dpr; canvas.height = h * dpr; canvas.style.width = w + 'px'; canvas.style.height = h + 'px';
    var ctx = canvas.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); return ctx;
  }
  var stillPref = function () { try { return matchMedia('(prefers-reduced-motion: reduce)').matches; } catch (e) { return false; } };

  /* =====================================================================================================================
     UltraWait
     ===================================================================================================================== */
  var T = {
    hold: 1.2, entry: 1.0, cometEvery: 20, cometFlight: 2.4, shootingStarFlight: 0.9, showerFlight: 1.8, passingCometFlight: 3.4,
    flashTime: 0.8, waveTime: 0.7, sweep: 2.6, ringShare: 0.62, wordsGap: 34
  };
  function moments(first, until, every, spread, seed) {
    var out = [], next = first;
    while (next <= until) { out.push(next); next += every + spread * unit(out.length * seed); }
    return out;
  }

  /* Timeline + moment (UltraWaitTimeline, UltraSceneMoment) */
  function Moment(time, run) {
    var starts = [];
    run.passStarts.slice(0, run.count).forEach(function (s) { starts.push(Math.max(s, (starts.length ? starts[starts.length - 1] : -Infinity) + T.hold)); });
    var m = { time: time, starts: starts, count: Math.max(1, run.count), arrivals: run.arrivals };
    m.entryOf = function (i, t) { return starts[i] == null ? 0 : Math.min(1, Math.max(0, (t - starts[i]) / T.entry)); };
    m.chapter = -1; starts.forEach(function (s, i) { if (s <= time) m.chapter = i; });
    m.draftArrivals = run.arrivals.filter(function (a) { return a.pass === 0; }).map(function (a) { return a.time; });
    var finish = run.finish;
    if (finish != null) {
      m.fall = Math.min(1, Math.max(0, (time - finish) / T.flashTime));
      var after = (time - finish - T.flashTime) / T.waveTime;
      m.wave = after >= 0 && after < 1 ? after : null;
    } else { m.fall = 0; m.wave = null; }
    var check = 1;
    if (m.count > 1 && starts[check] != null) {
      var over = m.count > 2 ? m.entryOf(check + 1, time) : m.fall;
      m.beam = m.entryOf(check, time) * (1 - over);
      m.beamAngle = (time - starts[check]) * TAU / T.sweep;
    } else { m.beam = 0; m.beamAngle = 0; }
    var voice = m.count - 1;
    var polish = voice > 0 && run.pass === voice ? run.passShown * m.entryOf(voice, time) : 0;
    m.warmth = Math.max(polish, m.fall);
    var handed = 0; if (m.chapter > 0) handed = 1 - m.entryOf(m.chapter, time);
    m.charge = Math.max(run.passShown, handed, m.fall);
    m.comets = []; m.flare = 0;
    if (m.chapter >= 0) {
      var end = Math.min(time, starts[m.chapter + 1] != null ? starts[m.chapter + 1] : time), c = [];
      for (var s = starts[m.chapter] + T.cometEvery; s <= end; s += T.cometEvery) c.push(s);
      m.comets = c.filter(function (s) { return time - s < T.cometFlight; });
      var crossing = T.cometFlight / 2;
      m.flare = m.comets.reduce(function (mx, s) { return Math.max(mx, Math.max(0, 1 - Math.abs(time - s - crossing) / 0.7)); }, 0);
    }
    return m;
  }

  /**
   * opts: { back, front, ring: <canvas>, width, height, centre:[x,y], radius, passSeconds:[draft, polish], ideaStart, still }
   * The run is scripted (the app's meter is real): the draft writes for passSeconds[0] with a step of words about every 1.3 s, the polish for
   * passSeconds[1]. Call run.start(), then run.finish() when the script is there.
   */
  function UltraWait(opts) {
    var W = opts.width || 390, H = opts.height || 844;
    var cx = opts.centre ? opts.centre[0] : W / 2, cy = opts.centre ? opts.centre[1] : H * 0.38;
    var radius = opts.radius || Math.min(160, W * 0.36, H * 0.17);
    var still = opts.still != null ? opts.still : stillPref();
    var back = setup(opts.back, W, H), front = setup(opts.front, W, H), rings = opts.ring ? setup(opts.ring, W, H) : null;
    var sec = opts.passSeconds || [12, 10];
    var run = { passStarts: [0.5, 0.5 + sec[0]], count: sec.length, arrivals: [], pass: 0, passShown: 0, finish: null };
    var began = 0, t0 = 0, raf = 0, running = false, doneAt = null, listeners = {};
    // the steps of words: about one every 1.3 s in the draft, a little quicker in the polish
    var steps = [];
    (function () {
      var t = 1.2;
      while (t < 0.5 + sec[0] - 0.4) { steps.push({ pass: 0, time: t }); t += 1.15 + 0.35 * unit(steps.length * 1.7); }
      t = 0.5 + sec[0] + 0.9;
      while (t < 0.5 + sec[0] + sec[1] - 0.3) { steps.push({ pass: 1, time: t }); t += 1.0 + 0.3 * unit(steps.length * 2.3); }
    })();
    var slant = 0.36, lean = -0.14, armStart = 0.14, armEnd = 0.58, armTurn = 1.3 * Math.PI, armSeg = 32, spin = 0.24, starCount = 26, firstStars = 10,
        sparkFlight = 0.9, bloomTime = 0.6;
    var moonReach = [0.8, 0.92, 1.04], moonSlant = [0.34, 0.5, 0.26], moonLean = [-0.24, 0.35, 0.07], moonSpeed = [0.55, 0.95, 0.4], moonPhase = [0.3, 2.4, 4.4];
    var fieldCount = 70, ideaMoonDelay = 0.8;

    function now() { return (performance.now() - t0) / 1000; }
    function armPt(a, along, m) {
      var dist = radius * armStart * Math.pow(armEnd / armStart, along) * (1 - ease(m.fall));
      return { d: dist, a: a * Math.PI + along * armTurn + turned(m) };
    }
    function turned(m) { return (still ? 0 : spin * (m.time - began)) + 5 * m.fall * m.fall; }
    function plane(d, a) {
      var x = d * Math.cos(a), y = d * slant * Math.sin(a);
      return [cx + x * Math.cos(lean) - y * Math.sin(lean), cy + x * Math.sin(lean) + y * Math.cos(lean)];
    }
    function tint(base, along, m) { var warm = smooth(0, 1, (m.warmth * 1.3 - along) / 0.3); return warm > 0 ? mix(base, C.skyStarYou, warm) : base; }
    function swept(a, m) { return m.beam * Math.exp(-Math.pow(wrapped(a - m.beamAngle) / 0.25, 2)); }
    function place(i) { return { arm: i % 2, along: 0.12 + 0.82 * unit(i * 1.31), off: (unit(i * 2.71) - 0.5) * 0.45 }; }
    function lighting(i, m) {
      if (i < firstStars) return began + 0.9 + 0.08 * i;
      var s = i - firstStars; if (m.draftArrivals[s] == null) return null;
      return m.draftArrivals[s] + (still ? 0 : sparkFlight);
    }
    function orbitOf(i, count) { return i === count - 1 ? 2 : Math.min(i, 1); }
    function moonPt(o, a, scale) {
      var r = radius * moonReach[o] * scale, x = r * Math.cos(a), y = r * moonSlant[o] * Math.sin(a), l = moonLean[o];
      return [cx + x * Math.cos(l) - y * Math.sin(l), cy + x * Math.sin(l) + y * Math.cos(l)];
    }
    function node(i, count) { var turn = TAU * (i + 1) / count, r = radius * T.ringShare; return [cx + r * Math.sin(turn), cy - r * Math.cos(turn)]; }
    function flights(m) {
      var out = [], count = m.count;
      if (count === 2) out.push({ orbit: 1, colour: C.moons[1], birth: began + ideaMoonDelay, len: T.hold, from: [cx, cy] });
      for (var i = 0; i < count; i++) {
        var b = null;
        if (i === count - 1) { if (run.finish != null) b = { t: run.finish, len: 0.45 }; }
        else if (m.starts[i + 1] != null) b = { t: m.starts[i + 1], len: T.hold };
        if (!b) continue;
        out.push({ orbit: orbitOf(i, count), colour: C.moons[orbitOf(i, count)], birth: b.t, len: b.len, from: node(i, count) });
      }
      return out;
    }

    /* ---- one layer ---- */
    function drawLayer(ctx, layer, m) {
      ctx.clearRect(0, 0, W, H);
      if (layer === 'back') drawHalo(ctx, m.time);
      var belongs = function (depth) { return (depth >= 0) === (layer === 'front'); };
      if (layer === 'back') { drawSky(ctx, m); }
      drawArms(ctx, m, belongs);
      if (layer === 'back') drawBeam(ctx, m);
      drawStars(ctx, m, belongs);
      drawSparks(ctx, m, belongs);
      drawOrbits(ctx, m, belongs, layer);
      drawMoons(ctx, m, belongs, layer);
      if (layer === 'front') drawWave(ctx, m);
    }

    function drawArms(ctx, m, belongs) {
      var unfurl = still ? 1 : ease(Math.min(1, (m.time - began) / 1.6));
      var glow = (0.6 + 0.4 * m.charge) * (1 + 0.6 * m.flare) * (1 - smooth(0.8, 1, m.fall));
      ctx.lineCap = 'butt';
      for (var arm = 0; arm < 2; arm++) {
        for (var s = 0; s < armSeg; s++) {
          var from = s / armSeg; if (from >= unfurl) break;
          var to = Math.min(unfurl, (s + 1) / armSeg), a = armPt(arm, from, m), b = armPt(arm, to, m), mid = (from + to) / 2;
          var depth = Math.sin((a.a + b.a) / 2); if (!belongs(depth)) continue;
          var lit = swept((a.a + b.a) / 2, m);
          var shape = Math.sin(Math.PI * Math.pow(mid, 0.75)) * (unfurl < 1 ? Math.min(1, (unfurl - mid) * 6) : 1);
          var strength = shape * glow * (0.55 + 0.45 * (depth + 1) / 2) * (1 + 1.2 * lit);
          var p = plane(a.d, a.a), q = plane(b.d, b.a);
          ctx.beginPath(); ctx.moveTo(p[0], p[1]); ctx.lineTo(q[0], q[1]);
          ctx.strokeStyle = rgba(tint(C.dust[0], mid, m), Math.min(1, 0.11 * strength)); ctx.lineWidth = 7; ctx.stroke();
          ctx.strokeStyle = rgba(mix(tint(C.dust[1], mid, m), WHITE, lit * 0.6), Math.min(1, 0.38 * strength)); ctx.lineWidth = 1; ctx.stroke();
        }
      }
    }
    function drawStars(ctx, m, belongs) {
      var fade = 1 - smooth(0.8, 1, m.fall);
      for (var i = 0; i < starCount; i++) {
        var lit = lighting(i, m); if (lit == null || m.time < lit) continue;
        var since = m.time - lit, pl = place(i), on = armPt(pl.arm, pl.along, m), angle = on.a + pl.off, depth = Math.sin(angle);
        if (!belongs(depth)) continue;
        var seed = i, pt = plane(on.d * (1 + (unit(seed * 5.3) - 0.5) * 0.2), angle);
        var twinkle = still ? 1 : 0.7 + 0.3 * Math.sin(m.time * (0.7 + 1.3 * unit(seed * 4.1)) + seed);
        var shown = Math.min(1, since / (i < firstStars ? 0.5 : 0.25)), bloom = still ? 0 : Math.max(0, 1 - since / bloomTime);
        var lift = Math.max(bloom, swept(angle, m), m.flare * 0.6);
        var op = shown * twinkle * (0.6 + 0.4 * (depth + 1) / 2) * fade;
        var base = i % 5 === 2 ? C.skyStarYou : (i % 2 === 0 ? C.dust[1] : WHITE), col = tint(base, pl.along, m);
        var size = (0.6 + 0.7 * unit(seed * 3.7)) * (1 + 0.6 * lift);
        if (unit(seed * 4.9) > 0.6 || lift > 0.1) { var halo = size * (4 + 4 * lift); glowDot(ctx, pt[0], pt[1], halo, [[0, rgba(col, Math.min(1, 0.3 + 0.5 * lift) * op)], [1, rgba(col, 0)]]); }
        ctx.fillStyle = rgba(col, op); disc(ctx, pt[0], pt[1], size); ctx.fill();
      }
    }
    function drawBeam(ctx, m) {
      if (still || m.beam <= 0.01) return;
      var reach = radius * armEnd * 1.08;
      for (var slice = 0; slice < 5; slice++) {
        var lead = m.beamAngle - slice * 0.08;
        ctx.beginPath(); ctx.moveTo(cx, cy);
        for (var s = 0; s <= 4; s++) { var p = plane(reach, lead - 0.08 * s / 4); ctx.lineTo(p[0], p[1]); }
        ctx.closePath();
        var strength = 0.16 * m.beam * (1 - slice / 5), gr = ctx.createRadialGradient(cx, cy, 0, cx, cy, reach);
        gr.addColorStop(0, rgba(C.ultraBeam, strength)); gr.addColorStop(1, rgba(C.ultraBeam, 0)); ctx.fillStyle = gr; ctx.fill();
      }
    }
    function drawSparks(ctx, m, belongs) {
      if (still || m.fall !== 0) return;
      m.draftArrivals.slice(0, starCount - firstStars).forEach(function (arrived, sp) {
        var flight = (m.time - arrived) / sparkFlight; if (flight < 0 || flight >= 1) return;
        var pl = place(firstStars + sp), travel = 1 - Math.pow(1 - flight, 2.4), on = armPt(pl.arm, pl.along * travel, m), angle = on.a + pl.off * travel;
        if (!belongs(Math.sin(angle))) return;
        var pt = plane(on.d, angle), op = flight < 0.12 ? flight / 0.12 : 1;
        glowDot(ctx, pt[0], pt[1], 5, [[0, rgba(WHITE, 0.4 * op)], [1, rgba(WHITE, 0)]]);
        spark(ctx, pt[0], pt[1], 2.6, flight * 1.5); ctx.fillStyle = rgba(WHITE, op); ctx.fill();
      });
    }
    function drawOrbits(ctx, m, belongs, layer) {
      var scale = 1 - ease(m.fall);
      flights(m).forEach(function (f) {
        if (m.time < f.birth) return;
        var shown = (still ? 1 : ease(Math.min(1, (m.time - f.birth) / f.len))) * (1 - m.fall);
        ctx.beginPath(); var joined = false;
        for (var s = 0; s < 96; s++) {
          var a0 = TAU * s / 96, a1 = TAU * (s + 1) / 96;
          if (!belongs(Math.sin((a0 + a1) / 2))) { joined = false; continue; }
          if (!joined) { var p = moonPt(f.orbit, a0, scale); ctx.moveTo(p[0], p[1]); }
          var q = moonPt(f.orbit, a1, scale); ctx.lineTo(q[0], q[1]); joined = true;
        }
        ctx.strokeStyle = rgba(f.colour, (layer === 'front' ? 0.32 : 0.17) * shown); ctx.lineWidth = 0.9; ctx.stroke();
      });
    }
    function drawMoons(ctx, m, belongs, layer) {
      var scale = 1 - ease(m.fall);
      flights(m).forEach(function (f) {
        if (m.time < f.birth) return;
        var age = m.time - f.birth, born = still ? 1 : Math.min(1, age / f.len), o = f.orbit;
        var angle = moonPhase[o] + (still ? 0 : moonSpeed[o] * age) + 7 * m.fall * m.fall, depth = Math.sin(angle);
        if (born < 1 ? layer !== 'front' : !belongs(depth)) return;
        var col = f.colour, nd = f.from, on = moonPt(o, angle, scale), travel = ease(born);
        var pt = [nd[0] + (on[0] - nd[0]) * travel, nd[1] + (on[1] - nd[1]) * travel];
        var near = born < 1 ? 1 : (depth + 1) / 2;
        var swell = still ? 1 : (0.4 + 0.6 * Math.min(1, born / 0.25)) * (1 + 0.4 * Math.sin(Math.PI * born));
        var size = (0.8 + 0.2 * near) * swell;
        var op = (0.7 + 0.3 * near) * (still ? Math.min(1, age / 0.3) : 1) * (1 - smooth(0.85, 1, m.fall));
        if (!still && born < 1) { var ring = 4 + 32 * ease(born); ctx.strokeStyle = rgba(col, 0.85 * (1 - born)); ctx.lineWidth = 1.3; disc(ctx, nd[0], nd[1], ring); ctx.stroke(); }
        if (!still && born >= 1) {
          for (var s = 0; s < 8; s++) {
            var p = moonPt(o, angle - 0.1 * s, scale), q = moonPt(o, angle - 0.1 * (s + 1), scale);
            ctx.beginPath(); ctx.moveTo(p[0], p[1]); ctx.lineTo(q[0], q[1]); ctx.strokeStyle = rgba(col, 0.5 * op * (1 - s / 8)); ctx.lineWidth = 2 * size; ctx.lineCap = 'butt'; ctx.stroke();
          }
        }
        var halo = 18 * size; glowDot(ctx, pt[0], pt[1], halo, [[0, rgba(col, 0.42 * op)], [1, rgba(col, 0)]]);
        // a small world, lit on the side that faces the star
        var body = 5.4 * size, tx = cx - pt[0], ty = cy - pt[1], d = Math.max(0.001, Math.hypot(tx, ty));
        var lx = pt[0] + tx / d * body * 0.45, ly = pt[1] + ty / d * body * 0.45;
        var gr = ctx.createRadialGradient(lx, ly, 0, lx, ly, body * 1.5);
        gr.addColorStop(0, rgba(WHITE, op)); gr.addColorStop(0.5, rgba(mix(col, WHITE, 0.25), op)); gr.addColorStop(1, rgba(mix(col, BLACK, 0.45), op));
        ctx.fillStyle = gr; disc(ctx, pt[0], pt[1], body); ctx.fill();
      });
    }
    function drawWave(ctx, m) {
      if (still || m.wave == null) return;
      var wave = m.wave, grow = 1 - Math.pow(1 - wave, 2.2), flash = radius * (0.35 + 0.5 * grow);
      glowDot(ctx, cx, cy, flash, [[0, rgba(WHITE, 0.9 * Math.pow(1 - wave, 1.5))], [0.5, rgba(C.ultraStarGlow, 0.4 * (1 - wave))], [1, rgba(C.ultraStarGlow, 0)]]);
      var reach = radius * (0.15 + 1.75 * grow);
      ctx.beginPath();
      for (var s = 0; s <= 72; s++) { var p = plane(reach, TAU * s / 72); if (s === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1]); }
      ctx.strokeStyle = rgba(C.skyStarYou, 0.75 * (1 - wave)); ctx.lineWidth = 0.6 + 2.6 * (1 - wave); ctx.stroke();
    }

    /* ---- the sky ---- */
    function drawSky(ctx, m) {
      ctx.save();
      var ringR = radius * T.ringShare + 10;
      ctx.beginPath(); ctx.rect(0, 0, W, cy + radius * T.ringShare + T.wordsGap - 6); ctx.moveTo(cx + ringR, cy); ctx.arc(cx, cy, ringR, 0, TAU);
      ctx.clip('evenodd'); ctx.globalAlpha = 1 - m.fall;
      drawField(ctx, m);
      if (!still) {
        moments(began + 4, m.time, 6, 4, 1.7).forEach(function (st, n) { var p = (m.time - st) / T.shootingStarFlight; if (p < 1) shootingStar(ctx, n, p); });
        moments(began + 7, m.time, 11, 5, 2.9).forEach(function (st, n) { var s = m.time - st; if (s < T.showerFlight) shower(ctx, n, s); });
        moments(began + 10, m.time, 13, 6, 4.3).forEach(function (st, n) { var p = (m.time - st) / T.passingCometFlight; if (p < 1) passingComet(ctx, n, p); });
        m.comets.forEach(function (st) { longComet(ctx, st, (m.time - st) / T.cometFlight); });
      }
      ctx.restore();
    }
    function drawField(ctx, m) {
      var reach = Math.hypot(Math.max(cx, W - cx), Math.max(cy, H - cy)), inner = radius * T.ringShare + 14;
      var turn = still ? 0 : 0.012 * (m.time - began), shown = still ? 1 : Math.min(1, Math.max(0, (m.time - began) / 1.5));
      for (var i = 0; i < fieldCount; i++) {
        var seed = i + 100, dist = inner + (reach - inner) * Math.sqrt(unit(seed * 1.9)), ang = TAU * unit(seed * 2.3) + turn;
        var x = cx + dist * Math.cos(ang), y = cy + dist * Math.sin(ang);
        var tw = still ? 1 : 0.55 + 0.45 * Math.sin(m.time * (0.5 + 1.5 * unit(seed * 3.1)) + seed);
        var op = (0.35 + 0.5 * unit(seed * 5.7)) * tw * shown;
        var col = i % 6 === 0 ? C.skyStarYou : (i % 3 === 0 ? C.dust[1] : WHITE), dot = 0.55 + 0.8 * unit(seed * 4.4);
        if (unit(seed * 6.3) > 0.88) { spark(ctx, x, y, dot * 3.4, 0, 0.18); ctx.fillStyle = rgba(col, 0.55 * op); ctx.fill(); }
        ctx.fillStyle = rgba(col, op); disc(ctx, x, y, dot); ctx.fill();
      }
    }
    function meteor(ctx, sx, sy, dx, dy, travel, length, p, col) {
      var along = travel * (1 - Math.pow(1 - p, 1.6)), hx = sx + dx * along, hy = sy + dy * along, tl = length * Math.min(1, p / 0.2);
      var tx = hx - dx * tl, ty = hy - dy * tl, op = p < 0.12 ? p / 0.12 : Math.pow(1 - (p - 0.12) / 0.88, 1.3);
      var gr = ctx.createLinearGradient(tx, ty, hx, hy); gr.addColorStop(0, rgba(col, 0)); gr.addColorStop(1, rgba(col, 0.85 * op));
      ctx.beginPath(); ctx.moveTo(tx, ty); ctx.lineTo(hx, hy); ctx.strokeStyle = gr; ctx.lineWidth = 1.3; ctx.lineCap = 'round'; ctx.stroke();
      glowDot(ctx, hx, hy, 4, [[0, rgba(col, 0.45 * op)], [1, rgba(col, 0)]]);
      ctx.fillStyle = rgba(WHITE, op); disc(ctx, hx, hy, 1.3); ctx.fill();
    }
    function shootingStar(ctx, seed, p) {
      var right = unit(seed * 3.3) > 0.5, top = H * 0.06, bottom = Math.max(top + 20, cy);
      var sx = W * (right ? 0.02 + 0.4 * unit(seed * 2.2) : 0.98 - 0.4 * unit(seed * 2.2)), sy = top + unit(seed * 5.1) * (bottom - top) * 0.6;
      var slope = 0.3 + 0.25 * unit(seed * 6.7);
      meteor(ctx, sx, sy, (right ? 1 : -1) * Math.cos(slope), Math.sin(slope), W * 0.42, 70, p, WHITE);
    }
    function shower(ctx, seed, since) {
      var right = unit(seed * 3.7) > 0.5, slope = 0.45 + 0.15 * unit(seed * 1.3), dx = (right ? 1 : -1) * Math.cos(slope), dy = Math.sin(slope), top = H * 0.04;
      for (var k = 0; k < 5; k++) {
        var key = seed * 7 + k, delay = 0.22 * k + 0.1 * unit(key * 2.1), flight = 0.75 + 0.25 * unit(key * 3.3), p = (since - delay) / flight;
        if (p <= 0 || p >= 1) continue;
        var across = W * (0.1 + 0.8 * unit(key * 4.7)), sx = right ? across * 0.6 : W - across * 0.6, sy = top + unit(key * 5.9) * (cy - top) * 0.55;
        meteor(ctx, sx, sy, dx, dy, W * (0.3 + 0.12 * unit(key * 6.1)), 45 + 45 * unit(key * 7.3), p, k % 2 === 0 ? WHITE : C.dust[1]);
      }
    }
    function passingComet(ctx, n, p) {
      var col = C.comets[n % C.comets.length], right = unit(n * 5.9) > 0.5, top = H * 0.06, low = Math.max(top + 30, cy - radius * T.ringShare - 40), height = top + unit(n * 6.1) * (low - top) * 0.8;
      var at = function (a) { var e = Math.min(1, Math.max(0, a)), x = -80 + (W + 160) * e; return [right ? x : W - x, height + 40 * e + 16 * Math.sin(Math.PI * e)]; };
      var head = at(p), op = Math.min(1, p / 0.08, (1 - p) / 0.08);
      var end = at(p - 0.24);
      [[7, 0.16], [1.6, 0.7]].forEach(function (w) {
        ctx.beginPath(); ctx.moveTo(head[0], head[1]); for (var s = 1; s <= 8; s++) { var q = at(p - 0.03 * s); ctx.lineTo(q[0], q[1]); }
        var gr = ctx.createLinearGradient(head[0], head[1], end[0], end[1]); gr.addColorStop(0, rgba(col, w[1] * op)); gr.addColorStop(1, rgba(col, 0));
        ctx.strokeStyle = gr; ctx.lineWidth = w[0]; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.stroke();
      });
      var ax = head[0] - cx, ay = head[1] - cy, d = Math.max(1, Math.hypot(ax, ay)), ex = head[0] + ax / d * 64, ey = head[1] + ay / d * 64;
      var gi = ctx.createLinearGradient(head[0], head[1], ex, ey); gi.addColorStop(0, rgba(C.comets[2], 0.35 * op)); gi.addColorStop(1, rgba(C.comets[2], 0));
      ctx.beginPath(); ctx.moveTo(head[0], head[1]); ctx.lineTo(ex, ey); ctx.strokeStyle = gi; ctx.lineWidth = 0.8; ctx.stroke();
      glowDot(ctx, head[0], head[1], 10, [[0, rgba(WHITE, op)], [0.5, rgba(col, 0.5 * op)], [1, rgba(col, 0)]]);
    }
    function longComet(ctx, start, p) {
      var right = unit(start) > 0.5, gold = C.skyStarYou;
      var at = function (a) { var e = ease(Math.min(1, Math.max(0, a))), x = -60 + (W + 120) * e; return [right ? x : W - x, cy - radius * 0.98 + 22 * Math.sin(Math.PI * e)]; };
      var head = at(p), end = at(p - 0.21), op = Math.min(1, p / 0.1, (1 - p) / 0.1);
      [[6, 0.2], [1.8, 0.75]].forEach(function (w) {
        ctx.beginPath(); ctx.moveTo(head[0], head[1]); for (var s = 1; s <= 6; s++) { var q = at(p - 0.035 * s); ctx.lineTo(q[0], q[1]); }
        var gr = ctx.createLinearGradient(head[0], head[1], end[0], end[1]); gr.addColorStop(0, rgba(gold, w[1] * op)); gr.addColorStop(1, rgba(gold, 0));
        ctx.strokeStyle = gr; ctx.lineWidth = w[0]; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.stroke();
      });
      glowDot(ctx, head[0], head[1], 9, [[0, rgba(WHITE, op)], [0.5, rgba(gold, 0.5 * op)], [1, rgba(gold, 0)]]);
    }

    /* ---- the star's halo (StarTransitionOverlay.haloLayer), under the scene ---- */
    var haloOpacity = 0;
    function drawHalo(ctx, t) {
      var width = radius * 2.4, phase = still ? 0.5 : 0.5 - 0.5 * Math.cos(t * TAU / 2.6);
      var sc = 0.92 + 0.16 * phase, r = width / 2 * sc;
      glowDot(ctx, cx, cy, r, [[0, rgba(C.halo, 0.34 * haloOpacity * (0.55 + 0.35 * phase))], [0.24, rgba(C.halo, 0.0816 * haloOpacity * (0.55 + 0.35 * phase))], [1, rgba(C.halo, 0)]]);
    }

    /* ---- the ring of passes (UltraPassOrbit) ---- */
    var ringOpacity = 0;
    function drawRing(m) {
      if (!rings) return;
      rings.clearRect(0, 0, W, H);
      if (ringOpacity <= 0.001) return;
      var count = m.count, r = radius * T.ringShare, weight = Math.max(1, Math.min(1.4, (r * 2) / 66 * 0.6));
      var done = run.finish != null ? count : run.pass, current = run.finish != null ? 1 : run.passShown, gathered = m.fall;
      rings.save(); rings.globalAlpha = ringOpacity;
      var gap = 0.045;
      for (var arc = 0; arc < count; arc++) {
        var st = arc / count + gap / 2, en = (arc + 1) / count - gap / 2, filled = arc < done ? 1 : (arc === done ? current : 0);
        rings.globalAlpha = ringOpacity * (1 - gathered);
        rings.beginPath(); rings.arc(cx, cy, r, -Math.PI / 2 + st * TAU, -Math.PI / 2 + en * TAU); rings.strokeStyle = 'rgba(235,235,245,.1)'; rings.lineWidth = 1.5 * weight; rings.lineCap = 'butt'; rings.stroke();
        if (filled > 0) {
          var gr = rings.createConicGradient ? rings.createConicGradient(-Math.PI / 2, cx, cy) : null;
          if (gr) { C.glow.forEach(function (c, i) { gr.addColorStop(i / (C.glow.length - 1), rgba(c, 1)); }); rings.strokeStyle = gr; } else rings.strokeStyle = rgba(C.ai, 1);
          rings.beginPath(); rings.arc(cx, cy, r, -Math.PI / 2 + st * TAU, -Math.PI / 2 + (st + (en - st) * filled) * TAU); rings.lineWidth = 2.2 * weight; rings.lineCap = 'round'; rings.stroke();
        }
      }
      rings.globalAlpha = ringOpacity * (1 - gathered * gathered);
      for (var a = 0; a < count; a++) {
        var turn = TAU * (a + 1) / count, rr = r * (still ? 1 : 1 - gathered), nx = cx + rr * Math.sin(turn), ny = cy - rr * Math.cos(turn);
        var lit = a < done, forming = a === done ? current : 0, colr = C.moons[orbitOf(a, count)];
        if (!lit && forming > 0) glowDot(rings, nx, ny, 11 * (0.5 + 0.6 * forming), [[0, rgba(colr, 0.7 * (0.2 + 0.6 * forming))], [1, rgba(colr, 0)]]);
        if (lit) glowDot(rings, nx, ny, 8, [[0, rgba(C.skyStarYou, 0.8)], [0.5, rgba(C.ultraStarGlow, 0.35)], [1, rgba(C.ultraStarGlow, 0)]]);
        rings.fillStyle = lit ? '#fff' : 'rgba(235,235,245,.1)'; disc(rings, nx, ny, lit ? 2.5 : 2); rings.fill();
      }
      rings.restore();
    }

    /* ---- the loop ---- */
    function pulse(r, t) {
      if (!r.arrivals.length) return 0;
      var since = t - r.arrivals[r.arrivals.length - 1].time;
      return since >= 0 && since < 0.4 ? Math.pow(1 - since / 0.4, 2) : 0;
    }
    function frame() {
      if (!running) return;
      var t = now(), r = run;
      r.arrivals = steps.filter(function (s) { return s.time <= t; });
      var s0 = r.passStarts[0], s1 = r.passStarts[1];
      if (r.finish != null) { r.pass = r.count - 1; r.passShown = 1; }
      else if (t >= s1) { r.pass = 1; r.passShown = Math.min(0.97, (t - s1) / sec[1]); }
      else { r.pass = 0; r.passShown = Math.max(0, Math.min(0.97, (t - s0) / sec[0])); }
      var m = Moment(t, r);
      drawLayer(back, 'back', m); drawLayer(front, 'front', m); drawRing(m);
      if (listeners.frame) listeners.frame({
        time: t, pass: r.pass, count: r.count, passShown: r.passShown, fall: m.fall, wave: m.wave,
        percent: r.finish != null ? 100 : Math.round(100 * Math.min(0.99, r.pass === 0 ? r.passShown * 0.55 : 0.55 + r.passShown * 0.45)),
        pulse: pulse(r, t), chapter: m.chapter
      });
      if (r.finish != null && doneAt == null && t - r.finish > T.flashTime + T.waveTime) { doneAt = t; if (listeners.done) listeners.done(); }
      raf = requestAnimationFrame(frame);
    }

    return {
      centre: [cx, cy], radius: radius, ringShare: T.ringShare, wordsGap: T.wordsGap, flashTime: T.flashTime, waveTime: T.waveTime,
      on: function (name, f) { listeners[name] = f; return this; },
      start: function () { t0 = performance.now(); began = 0; running = true; haloOpacity = 1; ringOpacity = 1; cancelAnimationFrame(raf); raf = requestAnimationFrame(frame); return this; },
      /* the script is there: the moons and the galaxy fall into the star (UltraWaitScene finish) */
      finish: function () { if (run.finish == null) run.finish = now(); return this; },
      stop: function () { running = false; cancelAnimationFrame(raf); },
      setRing: function (v) { ringOpacity = v; },
      setHalo: function (v) { haloOpacity = v; },
      isDone: function () { return doneAt != null; }
    };
  }

  /* =====================================================================================================================
     UltraHero  (UltraConsentHero): the ✦ igniting in its galaxy
     ===================================================================================================================== */
  function UltraHero(opts) {
    var W = opts.width || 390, H = opts.height || 232, ctx = setup(opts.canvas, W, H), star = opts.star, still = opts.still != null ? opts.still : stillPref();
    var ignition = 0.55, settled = 2.0, t0 = 0, raf = 0, onIgnite = opts.onIgnite, ignited = false;
    var orbits = [
      { tilt: 5, w: 0.47, h: 0.4, speed: 0, phase: 0, moon: null, from: 0.35 },
      { tilt: -18, w: 0.4, h: 0.21, speed: 0.08, phase: 2.6, moon: [WHITE, C.aiStrong, C.ai, C.ultraStarGlow], from: 0.1 },
      { tilt: 24, w: 0.3, h: 0.15, speed: -0.11, phase: 5.2, moon: [WHITE, C.starCream, C.starWarm, C.starGold], from: 0.22 }
    ];
    var sparkles = [[0.14, 0.2, 0, 0], [0.84, 0.16, 1.3, 1], [0.24, 0.84, 2.1, 0], [0.76, 0.88, 0.7, 0], [0.93, 0.5, 2.8, 0], [0.06, 0.56, 1.9, 1], [0.36, 0.08, 3.4, 0], [0.62, 0.94, 4.1, 1], [0.55, 0.1, 0.4, 0], [0.42, 0.9, 5.0, 0]];
    var spring = function (s) { return s > 0 ? 1 - Math.exp(-6 * s) * Math.cos(9 * s) : 0; };
    function pt(o, a, c) { var x = W * o.w * Math.cos(a), y = H * o.h * Math.sin(a), tl = o.tilt * Math.PI / 180; return [c[0] + x * Math.cos(tl) - y * Math.sin(tl), c[1] + x * Math.sin(tl) + y * Math.cos(tl)]; }
    function draw(t) {
      var c = [W / 2, H / 2], opening = smooth(0, 1, t / 0.8), reach = Math.min(W, H) / 2;
      ctx.clearRect(0, 0, W, H);
      glowDot(ctx, c[0], c[1], reach, [[0, rgba(C.ai, 0.34 * opening)], [0.5, rgba(C.ai, 0.1 * opening)], [1, rgba(C.ai, 0)]]);
      var wx = c[0] + reach * 0.35 * Math.cos(t * 0.25), wy = c[1] + reach * 0.18 * Math.sin(t * 0.25);
      glowDot(ctx, wx, wy, reach * 0.55, [[0, rgba(C.starGold, 0.1 * opening)], [1, rgba(C.starGold, 0)]]);
      sparkles.forEach(function (s) {
        var tw = (Math.sin(t * 2.2 + s[2]) + 1) / 2; ctx.fillStyle = rgba(s[3] ? C.starGold : C.aiStrong, (0.3 + 0.5 * tw) * opening); disc(ctx, W * s[0], H * s[1], 0.9 + 0.8 * tw); ctx.fill();
      });
      var after = t - ignition;
      if (after > 0) { // a slow cross of light behind the ✦
        var op = 0.32 * smooth(0, 1, after / 0.6), size = 110;
        ctx.save(); ctx.translate(c[0], c[1]); ctx.rotate(t * 6 * Math.PI / 180);
        [[size, 1.2, 0], [size * 0.75, 1.2, 1]].forEach(function (b) {
          var gr = b[2] ? ctx.createLinearGradient(0, -b[0] / 2, 0, b[0] / 2) : ctx.createLinearGradient(-b[0] / 2, 0, b[0] / 2, 0);
          [[0, 0], [0.3, 0.45], [0.5, 1], [0.7, 0.45], [1, 0]].forEach(function (s) { gr.addColorStop(s[0], rgba(C.aiStrong, op * s[1])); });
          ctx.fillStyle = gr; if (b[2]) ctx.fillRect(-b[1] / 2, -b[0] / 2, b[1], b[0]); else ctx.fillRect(-b[0] / 2, -b[1] / 2, b[0], b[1]);
        });
        ctx.restore();
      }
      orbits.forEach(function (o) { drawOrbit(o, c, t); });
      drawIgnition(c, t);
    }
    function drawOrbit(o, c, t) {
      var drawn = smooth(0, 1, (t - o.from) / 0.75); if (drawn < 0.001) return;
      var steps = Math.max(2, Math.floor(120 * drawn)), faint = o.moon ? 0.55 : 0.28;
      var gr = ctx.createConicGradient ? ctx.createConicGradient(t * 0.35, c[0], c[1]) : null;
      if (gr) { C.glow.forEach(function (col, i) { gr.addColorStop(i / (C.glow.length - 1), rgba(col, faint)); }); ctx.strokeStyle = gr; } else ctx.strokeStyle = rgba(C.ai, faint);
      ctx.beginPath(); for (var s = 0; s <= steps; s++) { var p = pt(o, TAU * drawn * s / steps, c); if (s === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1]); }
      ctx.lineWidth = o.moon ? 1.2 : 0.8; ctx.lineCap = 'butt'; ctx.stroke();
      if (drawn < 0.999) { var tip = pt(o, TAU * drawn, c); ctx.fillStyle = rgba(C.aiStrong, 0.9); disc(ctx, tip[0], tip[1], 2.2); ctx.fill(); glowDot(ctx, tip[0], tip[1], 9, [[0, rgba(C.ai, 0.5)], [1, rgba(C.ai, 0)]]); }
      if (!o.moon) return;
      var shows = smooth(0, 1, (t - o.from - 0.75) / 0.4); if (shows < 0.01) return;
      var ang = function (s) { return o.phase + TAU * o.speed * s; };
      // the first flight's short tail
      for (var k = 36; k > 0; k--) {
        var a = pt(o, ang(t - 0.9 * k / 36), c), b = pt(o, ang(t - 0.9 * (k - 1) / 36), c), f = 1 - k / 36;
        var col = o.moon[Math.min(3, Math.floor((1 - f) * 4))];
        ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.strokeStyle = rgba(col, 0.7 * f * shows); ctx.lineWidth = 2.4 * f; ctx.lineCap = 'round'; ctx.stroke();
      }
      var near = (Math.sin(ang(t)) + 1) / 2, m = pt(o, ang(t), c), rad = 2.6 + 1.2 * near;
      glowDot(ctx, m[0], m[1], rad * 3.4, [[0, rgba(o.moon[1], 0.4 * shows)], [1, rgba(o.moon[1], 0)]]);
      ctx.fillStyle = rgba(WHITE, (0.7 + 0.3 * near) * shows); disc(ctx, m[0], m[1], rad); ctx.fill();
    }
    function drawIgnition(c, t) {
      var p = (t - ignition) / 1.0; if (p <= 0 || p >= 1) return;
      var fade = (1 - p) * (1 - p), flash = 14 + 60 * smooth(0, 1, p * 2);
      glowDot(ctx, c[0], c[1], flash, [[0, rgba(WHITE, 0.7 * fade)], [0.5, rgba(C.ai, 0.35 * fade)], [1, rgba(C.ai, 0)]]);
      var e = 1 - Math.pow(1 - p, 3), reach = Math.min(W, H) / 2 - 4;
      ctx.strokeStyle = rgba(C.aiStrong, 0.75 * fade); ctx.lineWidth = 0.6 + 1.2 * (1 - p); disc(ctx, c[0], c[1], 18 + (reach - 18) * e); ctx.stroke();
      for (var i = 0; i < 6; i++) {
        var dir = (30 + 60 * i) * Math.PI / 180, dist = 22 + 64 * e, len = 9 * (1 - p);
        var tx = c[0] + dist * Math.cos(dir), ty = c[1] + dist * Math.sin(dir);
        ctx.beginPath(); ctx.moveTo(tx - len * Math.cos(dir), ty - len * Math.sin(dir)); ctx.lineTo(tx, ty);
        ctx.strokeStyle = rgba(i % 2 === 0 ? C.aiStrong : C.starGold, 0.9 * fade); ctx.lineWidth = 1.6; ctx.lineCap = 'round'; ctx.stroke();
      }
    }
    function starStyle(t) {
      if (!star) return;
      var lit = spring(t - ignition), breath = t > settled ? (Math.sin((t - settled) * 1.6 - Math.PI / 2) + 1) / 2 : 0;
      star.style.opacity = Math.min(1, Math.max(0, (t - ignition) / 0.12));
      star.style.transform = 'translate(-50%,-50%) scale(' + (0.2 + 0.8 * lit).toFixed(3) + ') rotate(' + (-70 * (1 - lit)).toFixed(1) + 'deg)';
      star.style.textShadow = '0 0 ' + (16 + 10 * breath).toFixed(1) + 'px rgba(180,167,255,' + (0.6 + 0.25 * breath).toFixed(2) + '),0 0 30px rgba(255,230,128,' + (0.18 * breath).toFixed(2) + ')';
    }
    function frame() {
      var t = still ? settled : (performance.now() - t0) / 1000;
      draw(t); starStyle(t);
      if (!ignited && t >= ignition) { ignited = true; if (onIgnite) onIgnite(); }
      raf = requestAnimationFrame(frame);
    }
    return {
      start: function () { t0 = performance.now(); ignited = false; cancelAnimationFrame(raf); raf = requestAnimationFrame(frame); return this; },
      stop: function () { cancelAnimationFrame(raf); }
    };
  }

  g.UltraWait = UltraWait;
  g.UltraHero = UltraHero;
  g.UltraMath = { unit: unit, ease: ease, smooth: smooth, rgba: rgba, spark: spark, C: C };
})(window);
