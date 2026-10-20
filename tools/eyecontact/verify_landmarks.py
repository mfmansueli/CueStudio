"""Checks FaceMeshV2.mlpackage against MediaPipe's own Face Landmarker on a video: the crop is built from MediaPipe's landmarks the way
Cue builds it (turned by the eye line, the points' extent x scale), and the eyes' outline and irises are compared in eye widths.

  python3 verify_landmarks.py face_landmarker.task FaceMeshV2.mlpackage take.mov 10 same 1.4 rot image

On two Cue takes the difference was 1.6-2.2% of the eye's width whatever the crop (the mesh's own sensitivity to its crop, not the
conversion: fp16 vs PyTorch on one image is 0.2 px at most).
"""
import sys, numpy as np, cv2, coremltools as ct, mediapipe as mp
from mediapipe.tasks.python import vision, BaseOptions
from PIL import Image
task, pkg, video, every = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
same = sys.argv[5] == 'same'; scale = float(sys.argv[6]); bbox_mode = sys.argv[7]
EYES = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246, 263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466]
IRIS = list(range(468, 478))
lm = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(base_options=BaseOptions(model_asset_path=task), running_mode=(vision.RunningMode.IMAGE if 'image' in sys.argv else vision.RunningMode.VIDEO), num_faces=1))
model = ct.models.MLModel(pkg)
cap = cv2.VideoCapture(video); fps = cap.get(cv2.CAP_PROP_FPS) or 30; prev = None; k = 0; eye_err, iris_err, widths = [], [], []
while True:
    ok, f = cap.read()
    if not ok: break
    h, w = f.shape[:2]
    im_ = mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(f, cv2.COLOR_BGR2RGB)); r = lm.detect(im_) if 'image' in sys.argv else lm.detect_for_video(im_, int(k * 1000 / fps))
    cur = None if not r.face_landmarks else np.array([[p.x * w, p.y * h] for p in r.face_landmarks[0]])
    if prev is not None and cur is not None and k % every == 0:
        src = cur if same else prev
        a, b = src[33], src[263]; angle = np.arctan2(b[1] - a[1], b[0] - a[0])
        c, s_ = np.cos(-angle), np.sin(-angle); R = np.array([[c, -s_], [s_, c]])
        if bbox_mode == 'rot':
            centre0 = (src.min(0) + src.max(0)) / 2
            rot = (src - centre0) @ R.T; lo, hi = rot.min(0), rot.max(0)
            centre = centre0 + ((lo + hi) / 2) @ R; size = max(hi - lo) * scale
        else:   # axis-aligned box in the image, then rotated (MediaPipe's DetectionsToRects)
            lo, hi = src.min(0), src.max(0); centre = (lo + hi) / 2; size = max(hi - lo) * scale
        # crop pixel (u, v) in 0..256 -> image: centre + R^-1 * ((u,v)/256 - 0.5) * size
        Rin = R.T
        M = np.zeros((2, 3)); M[:, :2] = Rin * (size / 256); M[:, 2] = centre - Rin @ np.array([128, 128]) * (size / 256)
        crop = cv2.warpAffine(f, cv2.invertAffineTransform(M), (256, 256), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
        out = model.predict({'face': Image.fromarray(cv2.cvtColor(crop, cv2.COLOR_BGR2RGB))})['landmarks'][0][:, :2]
        img = out @ M[:, :2].T + M[:, 2]
        ew = np.linalg.norm(cur[33] - cur[133])
        eye_err.append(np.linalg.norm(img[EYES] - cur[EYES], axis=1).mean() / ew)
        iris_err.append(np.linalg.norm(img[IRIS] - cur[IRIS], axis=1).mean() / ew); widths.append(ew)
    prev = cur; k += 1
e, i = np.array(eye_err) * 100, np.array(iris_err) * 100
print(f'{len(e)} frames · eye width ~{np.median(widths):.0f} px · eye contour vs MediaPipe: mean {e.mean():.2f}% (p95 {np.percentile(e, 95):.2f}%) of eye width · iris: mean {i.mean():.2f}% (p95 {np.percentile(i, 95):.2f}%)')
