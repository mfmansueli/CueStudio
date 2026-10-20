"""Builds Eye Contact's face mesh (FaceMeshV2.mlpackage) from MediaPipe's Face Landmarker V2 (Apache 2.0).

Two steps, in two Python environments (TensorFlow and PyTorch deadlock when imported together on macOS):

  1. TFLite -> ONNX, with tensorflow==2.15.1, tf2onnx==1.16.1, onnx==1.16.2:
       curl -LO https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task
       (sha256 64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff, the file Cue's model was made from)
       unzip face_landmarker.task face_landmarks_detector.tflite
       python3 -m tf2onnx.convert --tflite face_landmarks_detector.tflite --output landmarks.onnx --opset 15
  2. ONNX -> PyTorch -> Core ML, with torch==2.8.0, coremltools==9.0, onnx==1.17.0, onnx2torch==1.5.15:
       python3 landmarks.py landmarks.onnx FaceMeshV2.mlpackage

The model takes a 256 x 256 RGB crop of the face (0..1) and gives 478 points (x, y, z in crop pixels; 468-477 the irises) and a face
score (a logit). The script checks the Core ML model (fp16) against the PyTorch one on the same image.
"""
import sys, numpy as np, torch, onnx, coremltools as ct
from onnx2torch import convert
onnx_path, out_path = sys.argv[1:3]
net = convert(onnx.load(onnx_path)).eval()

class Wrapped(torch.nn.Module):
    def __init__(self, net): super().__init__(); self.net = net
    def forward(self, image):                      # image: 1x3x256x256, 0..1
        out = self.net(image.permute(0, 2, 3, 1))  # the TFLite graph is NHWC
        return out[0].reshape(1, 478, 3), out[1].reshape(1, 1)

model = Wrapped(net).eval()
example = torch.rand(1, 3, 256, 256)
with torch.no_grad():
    ref = model(example)
traced = torch.jit.trace(model, example)
ml = ct.convert(traced, inputs=[ct.ImageType(name='face', shape=(1, 3, 256, 256), scale=1 / 255, color_layout=ct.colorlayout.RGB)],
                outputs=[ct.TensorType(name='landmarks'), ct.TensorType(name='faceScore')],
                minimum_deployment_target=ct.target.iOS17, compute_precision=ct.precision.FLOAT16, convert_to='mlprogram')
ml.short_description = 'MediaPipe Face Mesh V2 landmarks (478 points incl. iris), Apache-2.0, converted for Cue Studio Eye Contact'
ml.version = 'mediapipe-face-mesh-v2-1'
ml.save(out_path)
# Same input through Core ML (as an image) vs PyTorch.
from PIL import Image
img = Image.fromarray((example[0].permute(1, 2, 0).numpy() * 255).round().astype(np.uint8))
pred = ml.predict({'face': img})
q = torch.from_numpy(np.asarray(img, np.float32) / 255).permute(2, 0, 1)[None]
with torch.no_grad(): ref = model(q)
d = np.abs(pred['landmarks'] - ref[0].numpy())
print(f'Core ML vs PyTorch on the same image: landmarks max |diff| {d.max():.3f} px, mean {d.mean():.4f} px; score {pred["faceScore"].ravel()[0]:.3f} vs {ref[1].item():.3f}')
