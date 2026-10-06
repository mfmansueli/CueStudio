#!/usr/bin/env python3
"""htmlframe.py <screen.html> <T seconds> <out.png> [scale]

Renders a screen of `design/cue-v30/handoff-telas/screens` frozen at T seconds (every CSS animation and SMIL timeline is paused at T) with
headless Chrome, 390 × 844 at `scale`. The picture to set beside the app's (`frames.sh`, `HandoffCaptureTests`)."""
import html, os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCREENS = os.path.join(ROOT, "design/cue-v30/handoff-telas/screens") + "/"
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")

name, seconds, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
scale = sys.argv[4] if len(sys.argv) > 4 else "1"
source = open(SCREENS + name, encoding="utf-8").read().replace("<head>", f'<head><base href="file://{SCREENS}">', 1)
host = f"""<!doctype html><html><body style="margin:0;background:#000">
<iframe id="f" srcdoc="{html.escape(source, quote=True)}" width="390" height="844" style="border:0;display:block"></iframe>
<script>
const T={seconds}*1000;
function freeze(){{
  const d=document.getElementById('f').contentDocument; if(!d) return;
  d.getAnimations().forEach(a=>{{a.pause(); a.currentTime=T;}});
  d.querySelectorAll('svg').forEach(s=>{{try{{s.pauseAnimations();s.setCurrentTime({seconds});}}catch(e){{}}}});
}}
setInterval(freeze,60);
</script></body></html>"""
path = os.path.join(tempfile.gettempdir(), f"cue-frame_{seconds}_{name}")
open(path, "w", encoding="utf-8").write(host)
subprocess.run(
    [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--window-size=390,844", f"--force-device-scale-factor={scale}",
     "--virtual-time-budget=2500", f"--screenshot={out}", "file://" + path],
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
)
