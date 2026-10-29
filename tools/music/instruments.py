"""The recorded instruments the tracks play, built from the sample libraries in `CUE_AUDIO_SOURCES` (README.md lists them with their
licences). Each builder reads the library's own file names (note, dynamic layer, round robin) and maps them to keys and velocities.
"""
from __future__ import annotations

import glob
import os
import re
from typing import Dict, List, Tuple

import sfz
from sampler import Instrument, Zone, midi, spread

SOURCES = os.environ.get("CUE_AUDIO_SOURCES", os.path.expanduser("~/Desktop/Projects/CueStudio-Audio/sources"))
VSCO = os.path.join(SOURCES, "VSCO-2-CE")

NOTE = re.compile(r"(?<![A-Za-z])([A-G][#b]?)(-?\d)(?![0-9])")
LAYER = re.compile(r"_(?:vl|dl|v|dyn)(\d+)", re.IGNORECASE)
DYNAMIC = re.compile(r"_(ppp|pp|p|mp|mf|f|ff|fff)(?=[_.])")
DYNAMICS = ["ppp", "pp", "p", "mp", "mf", "f", "ff", "fff"]
ROUND = re.compile(r"_rr(\d+)", re.IGNORECASE)


def layers(count: int) -> List[Tuple[int, int]]:
    """`count` velocity ranges splitting 1–127, the loud ones narrower (a soft layer covers most of what's played softly)."""
    edges = [round(1 + 126 * (i / count) ** 0.8) for i in range(count + 1)]
    return [(edges[i] if i == 0 else edges[i] + 1, edges[i + 1]) for i in range(count)]


# Recordings left out: a digital click in the attack (measured; the round robin next to it is clean).
EXCLUDED = {"BKCtbss_Pizz_E1_v3_rr1.wav"}


def multisample(folder: str, pattern: str = "*.wav", gain: float = 1.0, transpose: int = 0) -> List[Zone]:
    """Zones from files named with their note (`A#3`), dynamic layer (`_v2`, `_dyn2`) and round robin (`_rr2`), as most libraries name them.
    `transpose` is from the name to the note the file sounds: 12 for the folders that call middle C `C3` (measured, see README.md)."""
    found: Dict[int, Dict[int, List[str]]] = {}
    for path in sorted(glob.glob(os.path.join(folder, pattern))):
        name = os.path.basename(path)
        note = NOTE.search(name)
        if name in EXCLUDED:
            continue
        if not note:
            continue
        key = midi(note.group(1) + note.group(2)) + transpose
        found.setdefault(key, {}).setdefault(_layer(name), []).append(path)
    if not found:
        raise FileNotFoundError(f"No samples in {folder}/{pattern}")
    zones = []
    for root, low, high in spread(list(found)):
        by_layer = found[root]
        ranges = layers(len(by_layer))
        for (lovel, hivel), layer in zip(ranges, sorted(by_layer)):
            for rr, path in enumerate(sorted(by_layer[layer], key=_round)):
                zones.append(Zone(path, root, low, high, lovel, hivel, rr, gain))
    return zones


def _layer(name: str) -> int:
    """The dynamic layer a file name says: `_v2` / `_dyn2`, or a marking (`_mf_`), louder is higher; 1 when it says none."""
    numbered = LAYER.search(name)
    if numbered:
        return int(numbered.group(1))
    marked = DYNAMIC.search(name)
    return DYNAMICS.index(marked.group(1)) + 1 if marked else 1


def _round(path: str) -> int:
    found = ROUND.search(os.path.basename(path))
    return int(found.group(1)) if found else 0


def strings(section: str, articulation: str, release: float = 0.45, one_shot: bool = False, gain: float = 1.0) -> Instrument:
    """A VSCO 2 CE string section or solo, e.g. `strings("Violin Section", "susVib")`."""
    return Instrument(f"{section} {articulation}", multisample(os.path.join(VSCO, "Strings", section, articulation), gain=gain, transpose=12),
                      release=release, one_shot=one_shot, veltrack=0.5)


def harp() -> Instrument:
    return Instrument("harp", multisample(os.path.join(VSCO, "Strings", "Harp")), release=1.2, veltrack=0.8)


def flute(articulation: str = "susNV") -> Instrument:
    return Instrument(f"flute {articulation}", multisample(os.path.join(VSCO, "Woodwinds", "Flute", articulation), transpose=12), release=0.25, veltrack=0.5)


def woodwind(folder: str, articulation: str, release: float = 0.2, gain: float = 1.0) -> Instrument:
    """A VSCO 2 CE woodwind (`Bassoon`, `Clarinet`, `Piccolo`), by articulation (`stac`, `susLong`, `Sus`, `Stac`). Named with C3 as
    middle C, like the strings."""
    return Instrument(f"{folder} {articulation}", multisample(os.path.join(VSCO, "Woodwinds", folder, articulation), gain=gain, transpose=12),
                      release=release, veltrack=0.5)


def glockenspiel() -> Instrument:
    return Instrument("glockenspiel", multisample(os.path.join(VSCO, "Percussion", "Glock"), transpose=12), one_shot=True, max_length=3.0, veltrack=0.9)


def marimba() -> Instrument:
    return Instrument("marimba", multisample(os.path.join(VSCO, "Percussion", "Marimba"), transpose=12), one_shot=True, max_length=2.5, veltrack=0.9)


def hits(name: str, files: Dict[int, List[str]], **options) -> Instrument:
    """Unpitched hits: each key plays its own recordings (layers by `_v`, round robins by `_rr`), never pitched."""
    zones = []
    for key, paths in files.items():
        by_layer: Dict[int, List[str]] = {}
        for path in paths:
            by_layer.setdefault(_layer(os.path.basename(path)), []).append(path)
        for (lovel, hivel), layer in zip(layers(len(by_layer)), sorted(by_layer)):
            for rr, path in enumerate(sorted(by_layer[layer], key=_round)):
                zones.append(Zone(path, key, key, key, lovel, hivel, rr))
    options.setdefault("one_shot", True)
    options.setdefault("veltrack", 0.6)
    return Instrument(name, zones, **options)


def orchestral_percussion() -> Instrument:
    """VSCO 2 CE's hand percussion on General MIDI keys: shaker 70, tambourine 54, claves 75, cowbell 56, congas 62–64, triangle 81,
    suspended cymbal 49, crash 57."""
    perc = os.path.join(VSCO, "Percussion")
    files = {
        70: sorted(glob.glob(os.path.join(VSCO, "VSCO 1 Percussion", "varWood", "Camo's Shaker", "*.wav"))),
        54: sorted(glob.glob(os.path.join(perc, "Tamb1-Hit_*.wav"))),
        75: sorted(glob.glob(os.path.join(perc, "Claves1_Hit_*.wav"))),
        56: sorted(glob.glob(os.path.join(perc, "Cowbell1_Hit_*.wav"))),
        62: sorted(glob.glob(os.path.join(perc, "Quinto-HitN_*.wav"))),
        63: sorted(glob.glob(os.path.join(perc, "Conga-HitN_*.wav"))),
        64: sorted(glob.glob(os.path.join(perc, "Tumba-HitN_*.wav"))),
        81: sorted(glob.glob(os.path.join(perc, "Triangle6-HitM_*.wav"))),
        49: sorted(glob.glob(os.path.join(perc, "susCymb1-hitstick_*_rr*.wav"))),
        57: sorted(glob.glob(os.path.join(perc, "cymbal-crash1_*_rr*.wav"))),
    }
    return hits("hand percussion", {key: paths for key, paths in files.items() if paths}, max_length=4.0)


# Seconds from the start of each suspended-cymbal swell to its loudest point (measured), to land it on a downbeat.
SWELL_PEAKS = {52: 7.2, 53: 3.83, 54: 1.63}


def cinematic_percussion() -> Instrument:
    """VSCO 2 CE's orchestral hits (CC0): concert bass drum 35 (7 layers), crash cymbals 49, a suspended cymbal swelling up 52 (long),
    53 (medium) and 54 (short) — see `SWELL_PEAKS` — and a gong 58 (4 layers). Each rings out on its own."""
    perc = os.path.join(VSCO, "Percussion")
    files = {
        35: sorted(glob.glob(os.path.join(perc, "BDrumNewhit_v*_rr*_Sum.wav"))),
        49: sorted(glob.glob(os.path.join(perc, "cymbal-crash1_*_rr*.wav"))),
        52: [os.path.join(perc, "susCymb1-cresc-Long_v1.wav")],
        53: [os.path.join(perc, "susCymb1-cresc-Median_v1.wav")],
        54: [os.path.join(perc, "susCymb1-cresc-Short_v1.wav")],
        58: [os.path.join(perc, f"gongHit_{level}.wav") for level in ("p", "mf", "f", "fff")],
    }
    return hits("cinematic percussion", {key: paths for key, paths in files.items() if paths}, max_length=12.0, veltrack=0.5)


def timpani() -> Instrument:
    """VSCO 2 CE's low timpani (CC0), struck in 2 layers with 2 round robins, retuned from its measured 89.5 Hz (F2 + 43 cents) to any
    key from A1 to D3."""
    folder = os.path.join(VSCO, "Percussion", "Timpani")
    zones = []
    for (lovel, hivel), layer in zip(layers(2), (1, 3)):
        for rr in (1, 2):
            zones.append(Zone(os.path.join(folder, f"Timpani1_Hit_v{layer}_rr{rr}_Sum.wav"), 41, 33, 50, lovel, hivel, rr - 1, tune=-43))
    return Instrument("timpani", zones, one_shot=True, max_length=6.0, veltrack=0.6)


PIANOS = os.path.join(SOURCES, "VCSL", "Chordophones", "Zithers")


def _piano_release(key: int) -> float:
    """How long a key rings once let go: the top keys have no dampers, the bass strings take longer to stop."""
    return 3.0 if key >= 89 else 0.45 + max(0, 60 - key) * 0.012


# The Steinway's layers are recorded louder than the tracks play it, so it sounds brighter than a soft touch would: this tone, on top of a
# track's own EQ, brings it to a soft grand's (matched band by band to a softly recorded grand under the same score, within 3 dB up to 8 kHz).
SOFT_GRAND = (("highshelf", 1000, 0.7, -7.0), ("lowpass", 3000, 0.707), ("lowpass", 3000, 0.707), ("lowshelf", 110, 0.7, 3.5))


def steinway_grand() -> Instrument:
    """VCSL's Steinway Model B (CC0; Versilian Studios), close microphones, sustain pedal down: 3 layers every whole tone, named with
    C4 as middle C (measured). Its layers are normalized, so velocity sets the level (veltrack high)."""
    zones = multisample(os.path.join(PIANOS, "Grand Piano, Steinway B", "Sus"), "JHPiano_Sus_Close_*.wav")
    # A spaced pair close to the strings: aligned, or the two channels cancel on a phone's single speaker. Play it with `SOFT_GRAND`.
    return Instrument("steinway grand", zones, veltrack=0.75, align=True, release_for_key=_piano_release)


def knight_upright() -> Instrument:
    """VCSL's Knight upright (CC0; Simon Dalzell, Ivy Audio, for Versilian), player's position: 2 layers every whole tone, named with
    C3 as middle C. A small, warm, slightly woody piano."""
    zones = multisample(os.path.join(PIANOS, "Upright Piano, Knight", "Sustains"), "Player_vl*_rr1_*.wav", transpose=12)
    return Instrument("knight upright", zones, veltrack=0.55, release_for_key=lambda key: 0.4 + max(0, 60 - key) * 0.01)


FREEPATS = os.path.join(SOURCES, "freepats")
VCSL = os.path.join(SOURCES, "VCSL")


def nylon_guitar() -> Instrument:
    """FreePats Spanish Classical Guitar (CC0): every key recorded once, so velocity sets the level only."""
    return Instrument("nylon guitar", sfz.zones(os.path.join(FREEPATS, "SpanishClassicalGuitar-SFZ+FLAC-20190618", "SpanishClassicalGuitar-20190618.sfz")),
                      release=0.5, veltrack=0.75)


def vibraphone() -> Instrument:
    return Instrument("vibraphone", multisample(os.path.join(VCSL, "Idiophones", "Struck Idiophones", "Vibraphone", "Soft Mallets"), transpose=12), one_shot=True, max_length=4.0,
                      veltrack=0.7)


def groove_percussion() -> Instrument:
    """VCSL (CC0) on General MIDI keys: claps 39, small shaker 70 (forward) and 69 (back), tambourine 54, cabasa 82, bongos 60 (high) and
    61 (low)."""
    struck = os.path.join(VCSL, "Idiophones", "Struck Idiophones")
    drums = os.path.join(VCSL, "Membranophones", "Struck Membranophones", "Bongos")

    def files(folder: str, pattern: str) -> List[str]:
        return sorted(glob.glob(os.path.join(folder, pattern)))

    keyed = {
        39: files(os.path.join(struck, "Claps"), "Clap_rr*.wav"),
        70: files(os.path.join(struck, "Shaker, Small"), "Mid_ShakerHighFaster_Down_rr*.wav"),
        69: files(os.path.join(struck, "Shaker, Small"), "Mid_ShakerHighFaster_Up_rr*.wav"),
        54: files(os.path.join(struck, "Tambourine 1"), "Tamb1_Hit_v*.wav"),
        82: files(os.path.join(struck, "Cabasa"), "*.wav"),
        60: files(drums, "BongoH_Hit1_*.wav"),
        61: files(drums, "BongoL_Hit1_*.wav"),
    }
    return hits("groove percussion", {key: paths for key, paths in keyed.items() if paths}, max_length=2.0)


VIRTUOSITY = os.path.join(SOURCES, "VirtuosityDrums", "Programs")

# General MIDI drum keys and the Virtuosity Drums map each plays.
KIT = {36: "kick_snon", 38: "snare_center", 40: "snare_rimshot", 37: "snare_crossstick", 39: "snare_offcenter", 42: "hh_closed",
       44: "hh_pedal", 46: "hh_open", 47: "hh_half", 51: "ride_ride", 53: "ride_bell", 49: "crash_crash", 41: "ltom_center",
       48: "htom_center"}


def drum_kit(mic: str = "mid") -> Instrument:
    """Virtuosity Drums (CC0; Versilian and Karoryfer, played by Austin McMahon), one microphone position for the whole kit: `mid` (a
    stereo pair a few feet away, the kit as a listener hears it) or `lofi` (a dark, small-room microphone). Up to 36 layers on the
    drums, 4 round robins on the cymbals; the hi-hats cut each other."""
    zones = []
    for key, name in KIT.items():
        path = os.path.join(VIRTUOSITY, "mappings", mic, f"{name}_map.sfz")
        if os.path.exists(path):
            zones += sfz.zones(path, folder=VIRTUOSITY, key=key)
    return Instrument(f"drum kit ({mic})", zones, one_shot=True, max_length=3.5, veltrack=0.35, chokes={42: 1, 44: 1, 46: 1, 47: 1})


SWIRLY = os.path.join(SOURCES, "SwirlyDrums", "Samples")


def brush_kit() -> Instrument:
    """Swirly Drums (CC0, Karoryfer), played with brushes: a soft bass drum 36 (its resonant head's microphone), snare taps 38, edge 40,
    dig 39, hi-hat closed 42 and foot 44, ride 51; up to 22 layers and 4 round robins each."""

    def files(folder: str, pattern: str) -> List[str]:
        return sorted(glob.glob(os.path.join(SWIRLY, folder, pattern)))

    keyed = {
        36: files("marching_kick", "marching_kick_vl*_reso.wav"),
        38: files("snare_main", "snare_hit_vl*_top.wav"),
        40: files("snare_edge", "snare_edge_vl*_top.wav"),
        39: files("snare_dig", "snare_dig_vl*_top.wav"),
        42: files("hat_closed", "hh_closed_vl*.wav"),
        44: files("hat_foot", "hh_foot_vl*.wav"),
        51: files("ride", "ride_vl*.wav"),
    }
    return hits("brush kit", {key: paths for key, paths in keyed.items() if paths}, max_length=3.0, veltrack=0.3, chokes={42: 1, 44: 1})


def brush_stir() -> Instrument:
    """A brush stirring circles on the snare (Swirly Drums, CC0): held as long as the note, its 4 takes in turn."""
    paths = sorted(glob.glob(os.path.join(SWIRLY, "snare_stir", "stir_dl1_rr*.wav")))
    return Instrument("brush stir", [Zone(path, 38, 38, 38, 1, 127, rr) for rr, path in enumerate(paths)], release=0.12, veltrack=0.6)


def brass(folder: str, articulation: str, release: float = 0.3, one_shot: bool = False, gain: float = 1.0) -> Instrument:
    """VSCO 2 CE brass (CC0): `Trumpet`, `F Horn`, `Tenor Trombone`, `Tuba` or `OldTrombone`, by articulation (`sus`, `stac`, `vib`;
    the old trombone's `Sustain`, `Vibrato`, `Fall`, `Buzz`). Named with C3 as middle C, like the strings."""
    return Instrument(f"{folder} {articulation}", multisample(os.path.join(VSCO, "Brass", folder, articulation), gain=gain, transpose=12),
                      release=release, one_shot=one_shot, veltrack=0.5)


def xylophone() -> Instrument:
    return Instrument("xylophone", multisample(os.path.join(VSCO, "Percussion", "Xylo"), transpose=12), one_shot=True, max_length=2.0,
                      veltrack=0.8)


STRUCK = os.path.join(VCSL, "Idiophones", "Struck Idiophones")


def kalimba() -> Instrument:
    """A Kenyan kalimba (VCSL, CC0): 15 tines, one layer, so velocity sets the level only. Each sounds an octave above its name (measured)."""
    return Instrument("kalimba", multisample(os.path.join(VCSL, "Idiophones", "Plucked Idiophones", "Kalimba, Kenya"), transpose=12), one_shot=True,
                      max_length=3.0, veltrack=0.8)


def hand_chimes() -> Instrument:
    """Hand chimes (VCSL, CC0): soft, pure bell tones held until released. Named an octave below how they sound, as handbells are written."""
    return Instrument("hand chimes", multisample(os.path.join(STRUCK, "Hand Chimes"), "sus_*_main.wav", transpose=12), release=1.5, veltrack=0.7)


def tubular_bells() -> Instrument:
    """Tubular bells (VCSL, CC0), 2 layers, ringing out. Their strike tone is the named note (the partials measure an octave up)."""
    return Instrument("tubular bells", multisample(os.path.join(STRUCK, "Tubular Bells 2"), "TB_hit_*.wav"), one_shot=True, max_length=8.0,
                      veltrack=0.6)


def folk_percussion() -> Instrument:
    """VCSL (CC0) for acoustic grooves, on General MIDI keys: cajon bass 36 and slap 38, a concert bass drum 35 (soft to loud), a tom with
    mallets 45 and sticks 47, sleigh bells 83 (single hits, never the shake), woodblock 76, large shaker 82."""
    membranes = os.path.join(VCSL, "Membranophones", "Struck Membranophones")

    def files(folder: str, pattern: str) -> List[str]:
        return sorted(glob.glob(os.path.join(folder, pattern)))

    drum = os.path.join(membranes, "Bass Drum 2")
    keyed = {
        36: files(os.path.join(STRUCK, "Cajon"), "Cajon_hit1_*.wav"),
        38: files(os.path.join(STRUCK, "Cajon"), "Cajon_hit2_*.wav"),
        35: [os.path.join(drum, f"bassdrum_hit_{level}.wav") for level in ("pp1", "mp1", "mf1", "f", "ff")],
        45: files(os.path.join(membranes, "Tom 1", "Mallet"), "TomH_HitM_*.wav"),
        47: files(os.path.join(membranes, "Tom 1", "Stick"), "TomH_HitS_*.wav"),
        83: files(os.path.join(STRUCK, "Sleigh Bells"), "Sleighbells_Hit_rr*_Mid.wav"),
        76: files(os.path.join(STRUCK, "Woodblock"), "wood_click_pp_rr*.wav"),
        82: files(os.path.join(STRUCK, "Shaker, Large"), "LShaker_Hit_rr*_Mid.wav"),
    }
    return hits("folk percussion", {key: [p for p in paths if os.path.exists(p)] for key, paths in keyed.items() if paths}, max_length=4.0)
