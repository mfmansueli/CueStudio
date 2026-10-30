# Prints a film's frame rate and every gap between frames longer than a threshold (a stutter while something moves).
import json, subprocess, sys
film = sys.argv[1]
limit = float(sys.argv[2]) if len(sys.argv) > 2 else 0.034
out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "frame=pts_time", "-of", "json", film],
                     capture_output=True, text=True).stdout
times = sorted(float(f["pts_time"]) for f in json.loads(out)["frames"] if "pts_time" in f)
print(f"{len(times)} frames over {times[-1]-times[0]:.1f} s, mean {len(times)/(times[-1]-times[0]):.1f} fps")
gaps = [(a, b - a) for a, b in zip(times, times[1:]) if b - a > limit]
for at, gap in gaps:
    print(f"  {at:7.2f} s  gap {gap*1000:5.0f} ms")
