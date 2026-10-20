# Eye Contact bench on MediaPipe geometry (frame k = geometry k):
#   python bench.py <renderer module> <video> <mesh.json> <start s> <seconds> <out prefix> [key=value ...]
# tremor  mean |flow(corrected t-1→t) - flow(original t-1→t)| px in the eye boxes: motion the correction adds
# outside mean |corrected - original| outside the eye opening (lids, lashes, skin): how much it changes around the eye
# change  mean |corrected - original| inside the opening
# Writes <out>-side.mp4 (original | corrected, eyes enlarged).
import sys, json, importlib, numpy as np, cv2
sys.path.insert(0, __import__('os').path.dirname(__file__))
name, video, geo_path, start, seconds, out = sys.argv[1:7]
opts = dict(a.split('=', 1) for a in sys.argv[7:])
geo = json.load(open(geo_path))['frames']
# sharp=1: measure each frame's eye sharpness first (variance of the Laplacian in the eye boxes), for the renderer's blur hold.
if opts.pop('sharp', None) == '1':
    sc = cv2.VideoCapture(video); vals = []
    for g in geo:
        ok, f = sc.read()
        if not ok: break
        if not g['eyes']: vals.append(0); continue
        gray = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY); v = []
        for e in g['eyes']:
            p = np.array(e['contour']); x0, y0 = np.maximum(p.min(0).astype(int), 0); x1, y1 = p.max(0).astype(int) + 1
            box = gray[y0:y1, x0:x1]
            if box.size > 16: v.append(cv2.Laplacian(box, cv2.CV_32F).var())
        vals.append(float(np.mean(v)) if v else 0)
        continue
    vals += [0] * (len(geo) - len(vals)); opts['sharpness'] = vals
renderer = importlib.import_module(name).Renderer(geo, **opts)
cap = cv2.VideoCapture(video); fps = cap.get(cv2.CAP_PROP_FPS) or 30
first = int(round(float(start) * fps))
for _ in range(first): cap.grab()
prev = None; tremor, outside, change, side = [], [], [], None
for k in range(int(float(seconds) * fps)):
    ok, frame = cap.read()
    if not ok: break
    i = first + k; g = geo[i]
    corrected = renderer.correct(frame, i)
    if not g['eyes']: prev = None; continue
    boxes, masks = [], []
    for e in g['eyes']:
        p = np.array(e['contour']); x0, y0 = p.min(0); x1, y1 = p.max(0); w = x1 - x0
        b = (int(x0 - .25 * w), int(y0 - .6 * w), int(x1 + .25 * w), int(y1 + .4 * w)); boxes.append(b)
        m = np.zeros((b[3] - b[1], b[2] - b[0]), np.uint8); cv2.fillPoly(m, [np.round(p - [b[0], b[1]]).astype(np.int32)], 1); masks.append(m.astype(bool))
    g0, g1 = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), cv2.cvtColor(corrected, cv2.COLOR_BGR2GRAY)
    if prev is not None:
        for (x0, y0, x1, y1) in boxes:
            fo = cv2.calcOpticalFlowFarneback(prev[0][y0:y1, x0:x1], g0[y0:y1, x0:x1], None, .5, 3, 15, 3, 5, 1.2, 0)
            fc = cv2.calcOpticalFlowFarneback(prev[1][y0:y1, x0:x1], g1[y0:y1, x0:x1], None, .5, 3, 15, 3, 5, 1.2, 0)
            tremor.append(np.linalg.norm(fc - fo, axis=2).mean())
    diff = np.abs(corrected.astype(np.int16) - frame.astype(np.int16)).mean(2)
    for (x0, y0, x1, y1), m in zip(boxes, masks):
        d = diff[y0:y1, x0:x1]; outside.append(d[~m].mean()); change.append(d[m].mean() if m.any() else 0)
    prev = (g0, g1)
    x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes); x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
    cell = lambda im: cv2.resize(im[y0:y1, x0:x1], (720, 300), interpolation=cv2.INTER_CUBIC)
    pair = np.concatenate([cell(frame), cell(corrected)], 1)
    if side is None: side = cv2.VideoWriter(out + '-side.mp4', cv2.VideoWriter_fourcc(*'avc1'), fps, (pair.shape[1], pair.shape[0]))
    side.write(pair)
if side: side.release()
f = lambda v: f'{np.mean(v):.2f} (p95 {np.percentile(v, 95):.2f})'
print(f'{name} { {k: v for k, v in opts.items() if k != "sharpness"} } · tremor {f(tremor)} px · outside {f(outside)} · change {f(change)} · frames {len(change)}')
if hasattr(renderer, 'amount'):
    a = renderer.amount[first:first + int(float(seconds) * fps)]
    print(f'amount mean {a.mean():.2f} · held (<0.05) {np.mean(a < 0.05) * 100:.0f}% · angle {getattr(renderer, "last_deg", float("nan")):.1f}°')
