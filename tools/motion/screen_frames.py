# Reads the tables screen_frames.sh exported: the frames the screen showed (their spacing, in ticks of a 120 Hz screen) and the app's
# busy stretches on its main thread (Time Profiler samples 1 ms apart; a gap over 1.6 ms ends a stretch).
import collections, sys
import xml.etree.ElementTree as ET

folder = sys.argv[1]


def rows(table):
    root = ET.parse(f"{folder}/{table}.xml").getroot()
    ids = {element.get("id"): element for element in root.iter() if element.get("id") is not None}
    resolve = lambda element: ids[element.get("ref")] if element.get("ref") is not None else element
    return [[resolve(cell) for cell in row] for row in root.iter("row")]


shown = sorted(int(row[0].text) / 1e6 for row in rows("displayed-surfaces-interval"))
gaps = [b - a for a, b in zip(shown, shown[1:])]
span = (shown[-1] - shown[0]) / 1000
ticks = collections.Counter(round(gap / 8.333) for gap in gaps)
held = sum(count for tick, count in ticks.items() if tick >= 3)
print(f"screen: {len(shown)} frames in {span:.1f} s = {len(shown) / span:.1f} a second; spacing in 120 Hz ticks {sorted(ticks.items())}")
print(f"held past 16.7 ms: {held} ({100 * held / len(gaps):.1f}%), the longest {max(gaps):.0f} ms")

samples = sorted(
    int(row[0].text) / 1e6 for row in rows("time-profile")
    if "Main Thread" in row[1].get("fmt", "") and "Cue Studio," in row[1].get("fmt", "")
)
if samples:
    stretches, start, last = [], samples[0], samples[0]
    for sample in samples[1:]:
        if sample - last > 1.6:
            stretches.append(last - start + 1)
            start = sample
        last = sample
    stretches.append(last - start + 1)
    stretches.sort()
    n = len(stretches)
    print(f"app main thread: {100 * len(samples) / (samples[-1] - samples[0]):.0f}% busy; stretches median {stretches[n // 2]:.0f} ms, "
          f"9 in 10 under {stretches[int(n * 0.9)]:.0f}, the longest {stretches[-1]:.0f}")
