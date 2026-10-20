# MediaPipe Face Landmarker (VIDEO mode) on every frame: per eye 16 contour points + iris (centre + 4), in pixels.
#   python mesh.py <model.task> <video> <out.json>
import sys, json, numpy as np, cv2, mediapipe as mp
from mediapipe.tasks.python import vision, BaseOptions
model, video, out = sys.argv[1:4]
# Image-left eye first (the subject's right), as in our analysis.
CONTOUR = {'imageLeft': [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246],
           'imageRight': [263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466]}
IRIS = {'imageLeft': [468, 469, 470, 471, 472], 'imageRight': [473, 474, 475, 476, 477]}
lm = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=model), running_mode=vision.RunningMode.VIDEO, num_faces=1,
    output_face_blendshapes=True))
cap = cv2.VideoCapture(video); fps = cap.get(cv2.CAP_PROP_FPS) or 30; frames = []; k = 0
while True:
    ok, f = cap.read()
    if not ok: break
    h, w = f.shape[:2]
    r = lm.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(f, cv2.COLOR_BGR2RGB)), int(k * 1000 / fps))
    if r.face_landmarks:
        L = r.face_landmarks[0]; P = lambda i: [L[i].x * w, L[i].y * h]
        blink = {b.category_name: b.score for b in r.face_blendshapes[0] if 'eyeBlink' in b.category_name or 'eyeLook' in b.category_name}
        frames.append({'eyes': [{'contour': [P(i) for i in CONTOUR[s]], 'iris': [P(i) for i in IRIS[s]]} for s in ('imageLeft', 'imageRight')],
                       'shapes': blink})
    else:
        frames.append({'eyes': None})
    k += 1
json.dump({'width': w, 'height': h, 'fps': fps, 'frames': frames}, open(out, 'w')); print(k, 'frames', sum(f['eyes'] is not None for f in frames), 'with a face')
