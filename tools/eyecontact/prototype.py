"""Eye Contact's drawing as it was designed and judged on real takes before it was written in Swift (`EyeRedraw`): read with
`bench.py`. Geometry from `mesh.py` (MediaPipe on every frame of a video):

  python3 mesh.py face_landmarker.task take.mov mesh.json
  python3 bench.py prototype take.mov mesh.json 0 20 out sharp=1      (writes out-side.mp4: filmed | corrected)
  python3 bench.py prototype take.mov mesh.json 0 20 old sharp=1 columns=0 soft=0   (as before the dim-light fixes)
"""
import numpy as np, cv2

UPPER = [8, 9, 10, 11, 12, 13, 14, 15, 0]   # inner corner -> upper lid -> outer corner (contour indices)
LOWER = [0, 1, 2, 3, 4, 5, 6, 7, 8]


def smooth_series(values, valid, sigma):
    """Gaussian smoothing over time within stretches where `valid` (frames x n)."""
    out = values.copy()
    if sigma <= 0: return out
    k = np.arange(-int(3 * sigma), int(3 * sigma) + 1); kernel = np.exp(-0.5 * (k / sigma) ** 2)
    i = 0
    while i < len(valid):
        if not valid[i]: i += 1; continue
        j = i
        while j < len(valid) and valid[j]: j += 1
        seg = values[i:j]; pad = len(kernel) // 2
        padded = np.pad(seg, ((pad, pad), (0, 0)), mode='edge')
        out[i:j] = np.stack([np.convolve(padded[:, c], kernel / kernel.sum(), 'valid') for c in range(seg.shape[1])], 1)
        i = j
    return out


def one_euro(values, valid, fps=30.0, min_cutoff=1.5, beta=0.4, d_cutoff=1.0):
    """One-Euro filter (still when still, quick when the eye really moves), run forward and backward and averaged: no lag."""
    def run(v):
        out = v.copy(); prev = v[0].copy(); dprev = np.zeros_like(v[0])
        alpha = lambda cutoff: 1 / (1 + fps / (2 * np.pi * cutoff))
        for i in range(1, len(v)):
            d = (v[i] - prev) * fps; dprev = dprev + alpha(d_cutoff) * (d - dprev)
            cutoff = min_cutoff + beta * np.abs(dprev); prev = prev + alpha(cutoff) * (v[i] - prev); out[i] = prev
        return out
    out = values.copy(); i = 0
    while i < len(valid):
        if not valid[i]: i += 1; continue
        j = i
        while j < len(valid) and valid[j]: j += 1
        seg = values[i:j]; out[i:j] = 0.5 * (run(seg) + run(seg[::-1])[::-1]); i = j
    return out


def smootherstep(x, a, b):
    t = np.clip((np.abs(x) - a) / (b - a), 0, 1); return t * t * t * (10 + t * (-15 + 6 * t))


def curve(points, xs):
    """y of a lid polyline at xs (points sorted by x), linear between points."""
    p = np.array(sorted(points, key=lambda q: q[0])); return np.interp(xs, p[:, 0], p[:, 1])


class Renderer:
    def __init__(self, geo, deg='auto', sharpness=None, sharp='0.45,0.7', lid='0.7', reach='0.5', shade='0.10', blink='0.65', lash='0.07',
                 columns='1', soft='1', fade='0.35',
                 offset_mm='35', hfov='65', away='10,18', fps='30'):
        self.columns, self.soft, self.fade = columns == '1', soft == '1', float(fade)   # 0: the earlier drawing, to compare
        self.lid, self.reach, self.shade, self.lash = float(lid), float(reach), float(shade), float(lash)
        n = len(geo); valid = np.array([g['eyes'] is not None for g in geo]); self.fps = float(fps)
        flat = np.zeros((n, 2 * (16 + 5) * 2))
        for k, g in enumerate(geo):
            if g['eyes']: flat[k] = np.concatenate([np.ravel(e['contour'] + e['iris']) for e in g['eyes']])
        flat = one_euro(flat, valid, self.fps)
        self.geo = [None if not valid[k] else [
            (flat[k, e * 42:e * 42 + 32].reshape(16, 2), flat[k, e * 42 + 32:e * 42 + 42].reshape(5, 2)) for e in range(2)] for k in range(n)]
        self.ratio = []
        for e in range(2):
            r = [np.mean(np.linalg.norm(g[e][1][1:] - g[e][1][0], axis=1)) / np.linalg.norm(g[e][0][0] - g[e][0][8]) for g in self.geo if g]
            self.ratio.append(float(np.median(r)))
        # The teleprompter's angle below the lens, from the face's distance: an iris is ~11.7 mm across in everyone.
        self.deg_arg, self.offset_mm, self.hfov = deg, float(offset_mm), float(hfov)
        # Where the eyes look, in degrees inside the head (iris centre against the eye's corners, eyeball ~0.42 eye widths):
        # the take's usual (reading) place, and how far each frame is from it.
        gaze = np.full((n, 2), np.nan)
        for k, g in enumerate(self.geo):
            if g: gaze[k] = np.mean([self.eye_gaze(c, i) for c, i in g], 0)
        usual = np.nanmedian(gaze[valid], 0)
        far = np.where(valid, np.linalg.norm(np.nan_to_num(gaze - usual), axis=1), 99)
        a0, a1 = (float(v) for v in away.split(','))
        looking = 1 - smootherstep(far, a0, a1)
        # Blinks: openness against the person's usual (Maxine-style 0.65 of the mean), eased.
        open_ = np.zeros(n)
        for k, g in enumerate(self.geo):
            if g: open_[k] = np.mean([self.openness(c) for c, _ in g])
        usual_open = np.median(open_[valid])
        opened = 1 - smootherstep(np.clip(float(blink) * usual_open - open_, 0, None) / usual_open, 0.0, 0.12)
        opened = np.where(open_ < float(blink) * usual_open, 0, opened)
        wanted = looking * opened * valid
        # Motion blur: the eyes' sharpness against the take's usual; a blurred frame has no detail to move (held).
        if sharpness is not None:
            sh = np.asarray(sharpness, float); usual_sharp = np.median(sh[valid & (sh > 0)])
            s0, s1 = (float(v) for v in sharp.split(','))
            wanted = wanted * np.clip((sh / usual_sharp - s0) / (s1 - s0), 0, 1)
        # Never faster than 0.1 a frame (both ways, then the lower: a blink is anticipated, not cut).
        def limit(v):
            o = v.copy()
            for i in range(1, len(o)): o[i] = o[i - 1] + np.clip(v[i] - o[i - 1], -0.1, 0.1)
            return o
        self.amount = np.minimum(limit(wanted), limit(wanted[::-1])[::-1])
        self.usual_gaze = usual

    @staticmethod
    def eye_gaze(contour, iris):
        a, b = contour[0], contour[8]; w = np.linalg.norm(b - a); ux = (b - a) / w; uy = np.array([-ux[1], ux[0]])
        rel = iris[0] - (a + b) / 2
        # degrees: vertical (down positive in the image) and horizontal, eyeball radius ~0.42 eye widths
        return np.degrees(np.arcsin(np.clip([rel @ uy / (0.42 * w), rel @ ux / (0.42 * w)], -1, 1)))

    def angle(self, iris_radius_px, frame_width):
        if self.deg_arg != 'auto': return float(self.deg_arg)
        f = (frame_width / 2) / np.tan(np.radians(self.hfov / 2))
        distance = f * 11.7 / (2 * iris_radius_px)                     # mm
        return float(np.degrees(np.arctan(self.offset_mm / distance)))

    @staticmethod
    def openness(contour):
        w = np.linalg.norm(contour[0] - contour[8]); xs = np.linspace(contour[0][0], contour[8][0], 9)[2:7]
        return np.mean(curve(contour[LOWER], xs) - curve(contour[UPPER], xs)) / w

    def correct(self, frame, k):
        g = self.geo[k]
        if not g or self.amount[k] <= 0.01: return frame
        out = frame.astype(np.float32)
        for e, (contour, iris) in enumerate(g):
            out = self.eye(frame, out, contour, iris, self.ratio[e], self.amount[k])
        return out.clip(0, 255).astype(np.uint8)

    def eye(self, frame, out, contour, iris, ratio, amount):
        w = np.linalg.norm(contour[0] - contour[8]); R = ratio * w
        self.last_deg = self.angle(R, frame.shape[1])
        dy = amount * 0.42 * w * np.sin(np.radians(self.last_deg))     # eyeball radius ~0.42 eye widths
        # A narrow eye can't show an iris it never showed: at most ~40% of the lid gap over the iris.
        gap = curve(contour[LOWER], [iris[0][0]])[0] - curve(contour[UPPER], [iris[0][0]])[0]
        dy = min(dy, 0.4 * max(gap, 0))
        lo = (contour.min(0) - [0.35 * w, 0.8 * w]).astype(int); hi = (contour.max(0) + [0.35 * w, 0.45 * w]).astype(int)
        lo = np.maximum(lo, 0); hi = np.minimum(hi, [frame.shape[1], frame.shape[0]])
        crop = frame[lo[1]:hi[1], lo[0]:hi[0]].astype(np.float32); h, wd = crop.shape[:2]
        con = contour - lo; c = iris[0] - lo
        yy, xx = np.mgrid[0:h, 0:wd].astype(np.float32); xs = np.arange(wd, dtype=np.float32)

        # 1. Upper lid lift: peak above the iris, 0 at the corners; the skin above follows and fades out `reach` higher.
        x_in, x_out = sorted([con[0][0], con[8][0]])
        u = np.clip((xs - x_in) / (x_out - x_in), 0, 1); peak = np.clip((c[0] - x_in) / (x_out - x_in), 0.2, 0.8)
        v = np.where(u < peak, u / peak, (1 - u) / (1 - peak))
        lift = self.lid * dy * (v * v * (3 - 2 * v))                      # smoothstep profile
        lid_y = curve(con[UPPER], xs); new_lid = lid_y - lift
        t = np.clip((new_lid[None, :] - yy) / (self.reach * w), 0, 1)       # 0 at the raised lid, 1 `reach` above
        shift = lift[None, :] * (1 - t * t * (3 - 2 * t))
        shift = np.where(yy <= new_lid[None, :] + 1, shift, lift[None, :]) # below the raised lid: lashes and margin follow
        lifted = cv2.remap(crop, xx, (yy + shift).astype(np.float32), cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)

        # Openings (anti-aliased): as filmed, and with the raised lid.
        def mask(poly):
            s = 4; big = np.zeros((h * s, wd * s), np.uint8)
            cv2.fillPoly(big, [np.round(poly * s).astype(np.int32)], 255, cv2.LINE_AA)
            return cv2.resize(big, (wd, h), interpolation=cv2.INTER_AREA).astype(np.float32) / 255
        raised = con.copy(); up = np.array(UPPER[1:-1])
        raised[up, 1] -= np.interp(raised[up, 0], xs, lift)
        src_open, new_open = mask(con), mask(raised)
        seen = cv2.erode((src_open > 0.95).astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)

        # 2. White of the eye: the brightest, least saturated half of what's visible outside the iris, interpolated along
        # each row into the iris's old place and the band the lid uncovers.
        hsv = cv2.cvtColor(crop.astype(np.uint8), cv2.COLOR_BGR2HSV).astype(np.float32)
        dist = np.sqrt((xx - c[0]) ** 2 + (yy - c[1]) ** 2)
        candidates = seen & (dist > 1.12 * R)
        sclera_px = np.zeros_like(candidates)
        if candidates.sum() > 20:
            score = hsv[..., 2] - 0.6 * hsv[..., 1]
            sclera_px = candidates & (score >= np.percentile(score[candidates], 20))
        replace = (new_open > 0) & ((dist < 1.12 * R) | (src_open < 0.95))
        white = crop.copy(); filled = np.zeros(h, bool)
        for y in np.where(replace.any(1))[0]:
            row = np.where(replace[y])[0]; ok = np.where(sclera_px[y])[0]
            left, right = ok[ok < row[0]], ok[ok > row[-1]]
            lc = crop[y, left[-4:]].mean(0) if len(left) >= 2 else None
            rc = crop[y, right[:4]].mean(0) if len(right) >= 2 else None
            if lc is None and rc is None: continue
            lc = rc if lc is None else lc; rc = lc if rc is None else rc
            f = ((row - row[0]) / max(1, row[-1] - row[0]))[:, None]; white[y, row] = lc * (1 - f) + rc * f; filled[y] = True
        rows = np.where(replace.any(1))[0]
        for y in rows[::-1]:   # rows with no white beside them (the uncovered top band): the nearest filled row below
            if filled[y]: continue
            below = [q for q in range(y + 1, h) if filled[q]]
            if below: white[y, replace[y]] = white[below[0], replace[y]]; filled[y] = True
        white = np.where(replace[..., None], cv2.GaussianBlur(white, (0, 0), 0.06 * w), white)

        # 3. Iris at its new place: its own pixels where they were seen, else mirrored, else completed around the ring.
        cn = c + [0, -dy]; vx, vy = xx - cn[0], yy - cn[1]; rr = np.sqrt(vx * vx + vy * vy)
        # Iris pixels for sure: seen, inside the ring, and (towards its edge, where the contour can overreach onto a lid) darker
        # than halfway between the iris's core and the white.
        lum = hsv[..., 2]
        core = seen & (dist < 0.6 * R)
        white_lum = np.median(lum[sclera_px]) if sclera_px.any() else 230
        core_lum = np.median(lum[core]) if core.any() else 80
        iris_ok = seen & (dist < 0.97 * R) & ((dist < 0.6 * R) | (lum < 0.5 * (white_lum + core_lum)))
        iris_ok = cv2.erode(iris_ok.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) | (seen & (dist < 0.6 * R))
        # Reflections on the cornea (windows, lights): much brighter than the iris. They stay where they are when the eye turns,
        # so the iris moves without them and they're laid back in their own place afterwards.
        # (Brighter than the white of the eye and well inside the iris: in dim light the white itself is darker than any
        # threshold between iris and white, and the iris's rim borders it.)
        # A reflection is on the cornea: well inside the opening (not the lid's bright skin at the contour's edge) and a bright
        # spot against its own surroundings (top-hat), not a bright band.
        deep = cv2.erode(seen.astype(np.uint8), np.ones((2 * max(1, int(0.05 * w)) + 1,) * 2, np.uint8)).astype(bool)
        k_ = 2 * max(2, int(0.25 * R)) + 1
        tophat = lum - cv2.morphologyEx(lum, cv2.MORPH_OPEN, np.ones((k_, k_), np.uint8))
        spec = deep & (dist < 0.9 * R) & (lum > max(core_lum + 0.6 * (white_lum - core_lum), 0.92 * white_lum)) \
            & (tophat > 0.3 * (white_lum - core_lum))
        spec = cv2.dilate(spec.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
        iris_ok &= ~spec
        # Not the thin bands along the lids (the tear line's shine on the lower one, the lashes' shadow on the upper one).
        upper_at = curve(con[UPPER], xs)[None, :]; lower_at = curve(con[LOWER], xs)[None, :]
        iris_ok &= (yy > upper_at + 0.03 * w) & (yy < lower_at - 0.05 * w)
        # How soft the filmed iris's edge is (dim light, focus): the white–iris step over the steepest slope at the sides.
        self.edge_px = 1.2
        if self.soft:
            gx = np.abs(cv2.Sobel(cv2.GaussianBlur(lum, (0, 0), 0.7), cv2.CV_32F, 1, 0, ksize=3)) / 8
            side = seen & ~spec & (dist > 0.6 * R) & (dist < 1.3 * R) & (np.abs(yy - c[1]) < 0.5 * R)
            if side.sum() > 10:
                rows_ = [gx[y][side[y]].max() for y in np.where(side.any(1))[0]]
                slope = float(np.median(rows_))
                if slope > 0: self.edge_px = float(np.clip((white_lum - core_lum) / slope, 1.2, 0.3 * R))
        def visible(ax, ay):
            ix = np.clip(np.round(ax).astype(int), 0, wd - 1); iy = np.clip(np.round(ay).astype(int), 0, h - 1)
            return iris_ok[iy, ix] & ((ax - c[0]) ** 2 + (ay - c[1]) ** 2 < (0.97 * R) ** 2)
        mx, my = c[0] + vx, c[1] + vy; got = visible(mx, my)
        for ax, ay in ((c[0] - vx, c[1] + vy),):
            use = ~got & visible(ax, ay); mx[use], my[use] = ax[use], ay[use]; got |= use
        # Hidden by a lid (the band the lower lid covered comes into view as the iris rises): each column of the iris reflected
        # about its last seen row, so its texture and its limbus at the sides carry on across the seam.
        if self.columns and iris_ok.any():
            # Only iris dark enough to be iris (the lid's wet line can sit inside the contour, near the centre).
            dark = iris_ok & (lum < 0.5 * (white_lum + core_lum))
            cols = np.where(dark.any(0))[0]
            top_seen = np.full(wd, np.nan); bot_seen = np.full(wd, np.nan)
            for x in cols:
                ys_ = np.where(dark[:, x])[0]; top_seen[x] = ys_[0] + 1.5; bot_seen[x] = ys_[-1] - 1.5
            ix = np.clip(np.round(mx).astype(int), 0, wd - 1)
            tb_, bb_ = top_seen[ix], bot_seen[ix]
            ry = np.where(my > bb_, 2 * bb_ - my, np.where(my < tb_, 2 * tb_ - my, my))
            ry = np.nan_to_num(ry, nan=-1e6)
            # Also the seen pixels just past those rows: a sample between rows would take in the lid's line below.
            beyond = (my > bb_) | (my < tb_)
            use = beyond & (rr < R + 1) & visible(mx, ry)
            # Further from the seam the reflection would repeat what's nearer the middle (the pupil, a window's reflection): it
            # fades into the iris's colour at that distance from its centre.
            fade = np.zeros_like(rr)
            if self.fade > 0: fade[use] = np.clip(np.abs(my - ry)[use] / 2 / (self.fade * R), 0, 1)
            my[use] = ry[use]; got |= use
        # What the filmed iris never showed: its own texture mirrored across the edge of the hidden arc, ring by ring (polar
        # coordinates), so the fibres, rim and shading carry on with no stretched streaks.
        miss = ~got & (rr < R + 1)
        if miss.any() and iris_ok.any():
            rings, bins = 12, 360
            sd = np.sqrt((xx - c[0]) ** 2 + (yy - c[1]) ** 2)
            s_ring = np.clip((sd / R * rings).astype(int), 0, rings - 1)
            s_bin = ((np.degrees(np.arctan2(yy - c[1], xx - c[0])) + 360) % 360).astype(int)
            vis = np.zeros((rings, bins), bool); vis[s_ring[iris_ok], s_bin[iris_ok]] = True
            mr = np.clip((rr[miss] / R * rings).astype(int), 0, rings - 1)
            theta = (np.degrees(np.arctan2(vy[miss], vx[miss])) + 360) % 360
            src_theta = theta.copy(); found = np.zeros(len(theta), bool)
            for ring in range(rings):
                have = np.where(vis[ring])[0]
                if len(have) < 20: continue
                sel = np.where(mr == ring)[0]
                if len(sel) == 0: continue
                t = theta[sel]; tb = t.astype(int) % bins
                # nearest seen bin going down (a1) and up (a2), circularly
                down = (tb[:, None] - have[None, :]) % bins; up = (have[None, :] - tb[:, None]) % bins
                a1 = t - down.min(1) - 0.5; a2 = t + up.min(1) + 0.5
                left = (t - a1) <= (a2 - t)
                st = np.where(left, a1 - (t - a1), a2 + (a2 - t))
                src_theta[sel] = st % 360; found[sel] = True
            rad = np.radians(src_theta)
            fx = np.where(found, c[0] + rr[miss] * np.cos(rad), mx[miss]); fy = np.where(found, c[1] + rr[miss] * np.sin(rad), my[miss])
            mx[miss], my[miss] = fx, fy
            unfound = np.zeros_like(miss); unfound[miss] = ~found
        else:
            unfound = miss
        if not (self.columns and iris_ok.any()): fade = np.zeros_like(rr)
        iris_img = cv2.remap(crop, mx.astype(np.float32), my.astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        # Rings with too little seen iris to mirror: the iris's colour at that distance from the centre.
        if (unfound.any() or fade.any()) and iris_ok.any():
            bins = 16; src_b = np.clip((dist / R * bins).astype(int), 0, bins - 1)
            prof = np.zeros((bins, 3), np.float32); have = np.zeros(bins, bool)
            for b_ in range(bins):
                sel = iris_ok & (src_b == b_)
                if sel.sum() >= 3: prof[b_] = np.median(crop[sel], 0); have[b_] = True
            if have.any():
                idx = np.arange(bins)
                for ch in range(3): prof[:, ch] = np.interp(idx, idx[have], prof[have, ch])
                pos = np.clip(rr / R * bins - 0.5, 0, bins - 1); lo_b = np.floor(pos).astype(int); hi_b = np.minimum(lo_b + 1, bins - 1)
                f_ = (pos - lo_b)[..., None]; radial = prof[lo_b] * (1 - f_) + prof[hi_b] * f_
                soft = np.maximum(cv2.GaussianBlur(unfound.astype(np.float32), (0, 0), 1.0), fade)[..., None]
                iris_img = iris_img * (1 - soft) + radial * soft
        alpha = np.clip((R - rr) / self.edge_px + 0.5, 0, 1)[..., None]
        ball = white * (1 - alpha) + iris_img * alpha
        # The reflections, back in place over the moved iris (soft edge), only where the new iris is.
        spec_alpha = (cv2.GaussianBlur(spec.astype(np.float32), (0, 0), 0.8) * (rr < R))[..., None]
        ball = ball * (1 - spec_alpha) + crop * spec_alpha
        # Where nothing changes (white seen in place, away from the iris), keep the filmed pixels exactly.
        keep = (~replace & (rr > R + 1.5))[..., None]
        ball = np.where(keep, crop, ball)

        # 4. The lid's shadow on the eyeball and its lashes on top: darker just under the raised lid, and a "darken" blend in
        # a thin band so lashes hanging over the eye stay.
        top = curve(raised[UPPER], xs)[None, :]
        depth = np.clip((yy - top) / (0.16 * w), 0, 1)
        ball = ball * (1 - self.shade * (1 - depth))[..., None]
        band = np.clip(1 - (yy - top) / (self.lash * w), 0, 1)[..., None]
        ball = ball * (1 - band) + np.minimum(ball, lifted) * band
        # The opening's edge as soft as the filmed one (the raised lid over the eyeball).
        inside = new_open
        if self.soft and self.edge_px > 1.5: inside = cv2.GaussianBlur(new_open, (0, 0), self.edge_px / 2.5)
        inside = inside[..., None]
        corrected = lifted * (1 - inside) + ball * inside
        union = np.maximum(src_open, new_open)
        grow = max(1, int(round(0.03 * w)))
        alpha = cv2.dilate(union, np.ones((2 * grow + 1, 2 * grow + 1), np.float32))
        alpha = np.maximum(cv2.GaussianBlur(alpha, (0, 0), 0.025 * w), union)[..., None]
        # Outside that, only the lid lift (skin above the lid) differs; it stays, as it's a smooth warp of the filmed skin.
        lift_region = (np.abs(shift) > 0.05)[..., None]
        base = np.where(lift_region, lifted, crop)
        out[lo[1]:hi[1], lo[0]:hi[0]] = base + (corrected - base) * alpha
        if getattr(self, 'debug', None) is not None:
            m = lambda b: np.repeat((b.astype(np.float32) * 255)[..., None], 3, 2)
            self.debug.append([crop, m(src_open), m(new_open), m(iris_ok), m(spec), m(sclera_px), m(replace), white, iris_img, ball, out[lo[1]:hi[1], lo[0]:hi[0]].copy()])
        return out
