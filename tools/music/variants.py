"""Second takes on the effects the owner sent back (29/10), two or three directions each, to pick from by ear:
`venv/bin/python variants.py [effect ...]` writes `renders/effects/variants/<effect>-<option>.wav` and `variants.json`.
Every take is leveled like the app's effects (`effects.leveled`)."""
from __future__ import annotations

import json
import os
import sys
from typing import Callable, Dict, List, Tuple

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import effects as E  # noqa: E402
import instruments as I  # noqa: E402
from sampler import RATE, Note  # noqa: E402
from sounds import RENDERS, bodied, kenney, played, vcsl, vsco  # noqa: E402

FOLDER = os.path.join(RENDERS, "variants")
STRUCK = "Idiophones/Struck Idiophones/"


def sprung(x: np.ndarray, rise: float, wobble: float, rate: float, settle: float) -> np.ndarray:
    """Read as a spring would sing it: the pitch rises by `rise` semitones while wobbling `wobble` semitones at `rate` Hz, the wobble
    dying away over `settle` seconds."""
    t = np.arange(len(x)) / RATE
    semitones = rise * (1 - np.exp(-t / 0.05)) + wobble * np.exp(-t / settle) * np.sin(2 * np.pi * rate * t)
    position = np.cumsum(2 ** (semitones / 12))
    position = position[position < len(x) - 1]
    return np.interp(position, np.arange(len(x)), x)


def beep(hz: float, seconds: float) -> np.ndarray:
    """A start-light beep: a piezo tone (a fundamental and a soft odd harmonic), its edges rounded."""
    t = np.arange(int(seconds * RATE)) / RATE
    tone = np.sin(2 * np.pi * hz * t) + 0.18 * np.sin(2 * np.pi * 3 * hz * t)
    return E.faded(tone, 0.004, 0.012, curve=2.0)


# MARK: - Bloop and pop

def bloop_drop() -> np.ndarray:
    return E.trimmed(kenney("interface/Audio/drop_002.ogg"))


def bloop_slit() -> np.ndarray:
    log = E.trimmed(vcsl(STRUCK + "Slit Drum/LogDrumHi_MedM_v2_rr1_Sum.wav"))
    return E.decay(E.eq(E.gliding(log, -2, 5, curve=0.6), ("highpass", 150)), 0.15, 0.25)


def bloop_kalimba() -> np.ndarray:
    tine = E.trimmed(vcsl("Idiophones/Plucked Idiophones/Kalimba, Kenya/Mbira6_Normal_MainSpirit_F#4_k14_vl3_rr2.wav"))
    return E.decay(E.gliding(tine, -3, 4, curve=0.4), 0.18, 0.3)


def pop_drop() -> np.ndarray:
    return E.trimmed(kenney("interface/Audio/drop_003.ogg"))


def pop_bongo() -> np.ndarray:
    """A mouth-pop shape on a muted high bongo: struck a little high and dropping fast."""
    bongo = E.trimmed(vcsl("Membranophones/Struck Membranophones/Bongos/BongoH_HitMuted1_v2_rr1_Mid.wav"))
    return E.decay(E.eq(E.gliding(bongo, 7, -2, curve=0.5), ("highpass", 250)), 0.06, 0.12)


def pop_cork() -> np.ndarray:
    """A cork pulled: a short wooden knock pitched up into a hollow pop, a breath of air after it."""
    clave = E.trimmed(vcsl(STRUCK + "Claves/Claves2_Hit_v2_rr1_Mid.wav"))
    hollow = E.eq(E.gliding(clave, 2, -9, curve=0.4), ("lowpass", 3500), ("peak", 900, 1.2, 6.0))
    return E.decay(hollow, 0.05, 0.1)


# MARK: - Boing

def boing_kalimba() -> np.ndarray:
    tine = E.trimmed(vcsl("Idiophones/Plucked Idiophones/Kalimba, Kenya/Mbira6_Normal_MainSpirit_B2_k8_vl3_rr2.wav"))
    return E.decay(sprung(tine, 7, 1.6, 15, 0.35), 0.45, 0.35)


def boing_bass() -> np.ndarray:
    """A plucked upright bass string, bent like a jaw harp: the cartoon spring's doyoyoing."""
    pluck = E.trimmed(played(I.strings("Solo Contrabass", "Pizz", release=0.3), [Note(0, 40, 120, 1.0)], 1.4))
    bent = sprung(pluck, 12, 2.0, 13, 0.4)
    return E.decay(E.swept(bent, 300, 2400, 0.3), 0.5, 0.35)


def boing_flexatone() -> np.ndarray:
    shaken = E.trimmed(vcsl(STRUCK + "Flexatone/flexatone_fast.wav"))
    return E.decay(E.cut(shaken, 0, 0.9, release=0.15), 0.5, 0.35)


# MARK: - Hit

def hit_cinematic() -> np.ndarray:
    """A trailer impact: concert bass drum, low timpani and a low tom together, in a large hall."""
    drum = E.normalized(E.trimmed(vsco("BDrumNewhit_v7_rr1_Sum.wav")))
    timpani = E.normalized(E.pitched(E.trimmed(vsco("Timpani/Timpani1_Hit_v3_rr1_Sum.wav")), -3))
    tom = E.normalized(E.pitched(E.trimmed(vcsl("Membranophones/Struck Membranophones/Tom 1/Mallet/TomH_HitM_v4_rr1_Mid.wav")), -7))
    out = E.layer([(0, drum), (0.003, E.gain(timpani, -3)), (0, E.gain(tom, -5))])
    return E.decay(E.room(E.eq(out, ("highpass", 30), ("lowshelf", 90, 0.7, 4.0)), 0.25, 2.2, 0.35), 0.8, 1.0)


def hit_punch() -> np.ndarray:
    """A punch: a muffled low tom for the body, a slapstick for the smack and a cloth swing just before it."""
    tom = E.normalized(E.pitched(E.trimmed(vcsl("Membranophones/Struck Membranophones/Tom 1/Stick/TomH_HitS_v4_rr1_Mid.wav")), -9))
    smack = E.normalized(E.trimmed(vcsl(STRUCK + "Slapstick/slapstick_rr1.wav")))
    cloth = E.normalized(E.trimmed(kenney("rpg/OGG/cloth2.ogg")))
    out = E.layer([(0, E.gain(cloth, -12)), (0.07, E.eq(tom, ("lowpass", 2500))), (0.07, E.gain(smack, -8))])
    return E.decay(E.room(out, 0.08, 0.5, 0.4), 0.35, 0.35)


def hit_stab() -> np.ndarray:
    """An orchestra's stab: low brass and timpani on one short chord, a bass drum under it."""
    brass = played(I.brass("Tenor Trombone", "stac"), [Note(0, k, 120, 0.25) for k in (45, 52, 57)], 1.8)
    brass += played(I.brass("Tuba", "stac"), [Note(0, 33, 120, 0.25)], 1.8)
    brass += played(I.brass("Trumpet", "stac"), [Note(0, k, 115, 0.2) for k in (64, 69)], 1.8)
    drum = E.normalized(E.trimmed(vsco("BDrumNewhit_v7_rr1_Sum.wav")))
    timpani = E.normalized(E.trimmed(vsco("Timpani/Timpani1_Hit_v3_rr1_Sum.wav")))
    out = E.layer([(0, E.normalized(brass)), (0, E.gain(drum, -4)), (0, E.gain(timpani, -6))])
    return E.decay(E.room(out, 0.2, 1.6, 0.45), 0.6, 0.8)


# MARK: - Sparkle

def sparkle_chimes() -> np.ndarray:
    """Mark tree chimes brushed upwards, ending on a high glockenspiel note."""
    chimes = E.trimmed(vcsl(STRUCK + "Mark Trees/Legacy/windchimes_fastAsc1.wav"))
    glock = played(I.glockenspiel(), [Note(0, 96, 100, 1)], 2.0)
    out = E.layer([(0, E.normalized(chimes)), (max(0.0, E.seconds(chimes) - 0.2), E.gain(E.normalized(glock), -9))])
    return E.decay(E.room(E.eq(out, ("highpass", 1200)), 0.2, 1.5, 0.6), 1.3, 0.8)


def sparkle_magic() -> np.ndarray:
    """Magic: a quick glockenspiel run up a major pentatonic over mark tree chimes falling."""
    run = played(I.glockenspiel(), [Note(i * 0.055, k, 95 + 4 * i, 0.4) for i, k in enumerate((84, 86, 88, 91, 93, 96))], 2.2)
    chimes = E.trimmed(vcsl(STRUCK + "Mark Trees/Legacy/windchimes_slowDesc1.wav"))
    out = E.layer([(0, E.normalized(run)), (0.2, E.gain(E.normalized(chimes), -8))])
    return E.decay(E.room(E.eq(out, ("highpass", 900)), 0.25, 1.8, 0.6), 1.2, 0.9)


def sparkle_glass() -> np.ndarray:
    """Crystal: finger cymbals and a struck glass shimmering together."""
    cymbals = E.normalized(E.trimmed(vcsl(STRUCK + "Finger Cymbals/Fing_Cymb.wav")))
    glass = E.normalized(E.trimmed(kenney("interface/Audio/glass_004.ogg")))
    chimes = E.normalized(E.trimmed(vcsl(STRUCK + "Mark Trees/Legacy/windchimes_fastAsc1.wav")))
    out = E.layer([(0, E.gain(chimes, -10)), (0.25, cymbals), (0.25, E.gain(glass, -6))])
    return E.decay(E.room(E.eq(out, ("highpass", 1000)), 0.2, 1.4, 0.6), 1.2, 0.8)


# MARK: - Shutter

def shutter_slr() -> np.ndarray:
    """A reflex camera: the mirror flipping up, the curtain, the mirror landing (three metal clicks inside a small body)."""
    mirror = E.normalized(E.trimmed(kenney("rpg/OGG/metalClick.ogg")))
    curtain = E.normalized(E.trimmed(kenney("ui/switch2.wav")))
    out = E.layer([(0, mirror), (0.028, E.gain(curtain, -2)), (0.085, E.gain(E.pitched(mirror, -3), -5))])
    return E.room(E.eq(out, ("highpass", 400), ("peak", 2500, 1.0, 2.0)), 0.06, 0.15, 0.6)


def shutter_film() -> np.ndarray:
    """A film camera: the shutter's click, then the thumb winding the film on (a ratchet's teeth)."""
    click = E.normalized(E.trimmed(kenney("rpg/OGG/metalClick.ogg")))
    wind = E.cut(E.trimmed(vcsl(STRUCK + "Ratchet/Ratchet2_Fast_rr1_Mid.wav")), 0, 0.32, release=0.06)
    wind = E.eq(E.pitched(wind, 7), ("highpass", 1500))
    return E.layer([(0, click), (0.035, E.gain(click, -6)), (0.32, E.gain(E.normalized(wind), -9))])


def shutter_phone() -> np.ndarray:
    """The phone's shutter sound (a recorded camera's two clicks), crisp and close."""
    first = E.normalized(E.trimmed(kenney("ui/click1.wav")))
    second = E.normalized(E.trimmed(kenney("ui/switch3.wav")))
    return E.eq(E.layer([(0, first), (0.07, E.gain(second, -2))]), ("highpass", 600))


# MARK: - Countdown and clock

def countdown_beeps() -> np.ndarray:
    """Race start: three short beeps and a long higher one (start lights beep electronically in real life too)."""
    low, high = beep(880, 0.16), beep(1760, 0.6)
    return E.layer([(0, low), (0.6, low), (1.2, low), (1.8, high)])


def countdown_drums() -> np.ndarray:
    """Three tom hits rising, then the kick and a crash for go."""
    kit = I.drum_kit("mid")
    notes = [Note(0, 41, 100, 0.3), Note(0.5, 41, 105, 0.3), Note(1.0, 48, 110, 0.3), Note(1.5, 36, 120, 1), Note(1.5, 49, 110, 2),
             Note(1.5, 38, 110, 0.3)]
    return E.decay(played(kit, notes, 3.6), 2.4, 0.9)


def countdown_sticks() -> np.ndarray:
    """A drummer's count-in on claves, then a bright bell for go."""
    clave = E.normalized(E.trimmed(vcsl(STRUCK + "Claves/Claves1_Hit_v2_rr1_Mid.wav")))
    clave2 = E.normalized(E.trimmed(vcsl(STRUCK + "Claves/Claves1_Hit_v3_rr1_Mid.wav")))
    bell = E.normalized(E.trimmed(vcsl(STRUCK + "Hand Chimes/sus_C6_r01_main.wav")))
    triangle = E.normalized(E.trimmed(vsco("Triangle6-Hit_v2_rr1_Sum.wav")))
    go = E.layer([(0, bell), (0, E.gain(triangle, -6))])
    out = E.layer([(0, E.gain(clave, -2)), (0.5, E.gain(clave2, -2)), (1.0, clave), (1.5, E.decay(go, 0.6, 0.8))])
    return E.room(out, 0.1, 0.6, 0.5)


def tick_tock_clock() -> np.ndarray:
    """A mechanical clock: a small metal tick and a lower tock, ringing a little in a wooden case."""
    tick = E.normalized(E.eq(E.trimmed(kenney("rpg/OGG/metalClick.ogg")), ("highpass", 800)))
    tock = E.gain(E.normalized(E.eq(E.pitched(E.trimmed(kenney("rpg/OGG/metalClick.ogg")), -5), ("highpass", 400))), -2)
    out = E.layer([(0, tick), (0.5, tock), (1.0, tick), (1.5, tock)])
    return E.room(E.eq(out, ("peak", 1200, 1.2, 3.0)), 0.18, 0.35, 0.4)


def tick_tock_claves() -> np.ndarray:
    high = E.normalized(E.trimmed(vcsl(STRUCK + "Claves/Claves2_Hit_v1_rr1_Mid.wav")))
    low = E.gain(E.normalized(E.pitched(E.trimmed(vcsl(STRUCK + "Claves/Claves2_Hit_v1_rr1_Mid.wav")), -5)), -1)
    return E.room(E.layer([(0, high), (0.5, low), (1.0, high), (1.5, low)]), 0.08, 0.4, 0.5)


def tick_tock_wood() -> np.ndarray:
    """A woodblock's two sides, a little slower, like a grandfather clock."""
    high = E.normalized(E.trimmed(vcsl(STRUCK + "Woodblock/wood_click3_vl2.wav")))
    low = E.gain(E.normalized(E.pitched(E.trimmed(vcsl(STRUCK + "Woodblock/wood_click3_vl1.wav")), -4)), -1)
    return E.room(E.layer([(0, high), (0.62, low), (1.24, high), (1.86, low)]), 0.15, 0.7, 0.4)


# MARK: - Footsteps

def _steps(files: List[int], gap: float, jitter: float, seed: int) -> List[Tuple[float, np.ndarray]]:
    random = np.random.default_rng(seed)
    parts, at = [], 0.0
    for index, number in enumerate(files):
        step = E.normalized(E.trimmed(kenney(f"rpg/OGG/footstep0{number}.ogg")))
        parts.append((at, E.gain(step, float(random.uniform(-2.5, 0)) - (1.0 if index % 2 else 0.0))))
        at += gap + float(random.uniform(-jitter, jitter))
    return parts


def footsteps_indoor() -> np.ndarray:
    """Shoes on a hard floor: the heavier takes, an easy walk."""
    return E.room(E.eq(E.layer(_steps([4, 6, 9, 5], 0.48, 0.03, 3)), ("highpass", 70)), 0.1, 0.5, 0.45)


def footsteps_hallway() -> np.ndarray:
    """Someone coming down a corridor: slow steps, getting closer, in a long reverb."""
    parts = _steps([6, 4, 9, 6, 4], 0.62, 0.02, 5)
    closer = [(at, E.gain(x, -9 + 2.2 * i)) for i, (at, x) in enumerate(parts)]
    walk = E.layer(closer)
    return E.decay(E.room(np.concatenate([walk, np.zeros(int(1.4 * RATE))]), 0.3, 1.6, 0.4), E.seconds(walk) + 0.4, 0.7)


def footsteps_running() -> np.ndarray:
    return E.layer(_steps([0, 7, 2, 8, 1, 3, 0, 7], 0.27, 0.015, 7))


# MARK: - Ba-dum-tss and the till

def rimshot_classic() -> np.ndarray:
    """Ba-dum-tss as a drummer plays it: snare, the low tom with the kick, then a crash with the kick, caught short."""
    kit = I.drum_kit("mid")
    notes = [Note(0, 38, 105, 0.2), Note(0.16, 41, 112, 0.2), Note(0.16, 36, 105, 0.2), Note(0.45, 49, 105, 0.8), Note(0.45, 36, 110, 0.2)]
    return E.decay(played(kit, notes, 2.0), 1.0, 0.45)


def rimshot_hihat() -> np.ndarray:
    """Ba-dum and an open hi-hat for the tss, closed by the foot."""
    kit = I.drum_kit("mid")
    notes = [Note(0, 38, 105, 0.2), Note(0.16, 41, 112, 0.2), Note(0.16, 36, 105, 0.2), Note(0.45, 46, 112, 0.5), Note(0.45, 36, 110, 0.2),
             Note(0.95, 44, 90, 0.2)]
    return played(kit, notes, 1.4)


def rimshot_brushes() -> np.ndarray:
    """The jazz-club version, with brushes."""
    kit = I.brush_kit()
    notes = [Note(0, 38, 110, 0.2), Note(0.17, 40, 110, 0.2), Note(0.17, 36, 110, 0.2), Note(0.46, 51, 115, 1.2), Note(0.46, 36, 110, 0.2)]
    return E.decay(played(kit, notes, 2.2), 1.2, 0.6)


def cash_mechanical() -> np.ndarray:
    """Ka-ching: the crank (a ratchet's teeth), the bell (finger cymbals) and the drawer of coins."""
    crank = E.cut(E.trimmed(vcsl(STRUCK + "Ratchet/Ratchet1_Crank_rr1_Mid.wav")), 0, 0.18, release=0.04)
    bell = E.normalized(E.trimmed(vcsl(STRUCK + "Finger Cymbals/Fing_Cymb.wav")))
    coins = E.normalized(E.trimmed(kenney("rpg/OGG/handleCoins2.ogg")))
    drawer = E.normalized(E.eq(E.trimmed(kenney("rpg/OGG/doorClose_1.ogg")), ("lowpass", 1800)))
    out = E.layer([(0, E.gain(E.normalized(crank), -5)), (0.17, bell), (0.25, E.gain(drawer, -12)), (0.3, E.gain(coins, -9))])
    return E.decay(out, 1.0, 0.5)


def cash_bell() -> np.ndarray:
    """Ching: a bright bell struck twice and a handful of coins."""
    bell = E.normalized(E.trimmed(vcsl(STRUCK + "Finger Cymbals/Fing_Cymb.wav")))
    triangle = E.normalized(E.trimmed(vsco("Triangle6-Hit_v2_rr1_Sum.wav")))
    coins = E.normalized(E.trimmed(kenney("rpg/OGG/handleCoins.ogg")))
    out = E.layer([(0, E.gain(bell, -4)), (0.09, bell), (0.09, E.gain(triangle, -8)), (0.2, E.gain(coins, -8))])
    return E.decay(out, 0.9, 0.5)


def cash_chips() -> np.ndarray:
    """A win: coins poured onto a pile (casino chips and coins), a bell over it."""
    chips = E.normalized(E.trimmed(kenney("casino/Audio/chips-stack-3.ogg")))
    coins = E.normalized(E.trimmed(kenney("rpg/OGG/handleCoins2.ogg")))
    bell = E.normalized(E.trimmed(vcsl(STRUCK + "Hand Chimes/sus_C6_r01_main.wav")))
    out = E.layer([(0, E.gain(bell, -3)), (0.05, E.gain(chips, -6)), (0.12, E.gain(coins, -6))])
    return E.decay(out, 0.9, 0.5)


VARIANTS: Dict[str, List[Tuple[str, Callable[[], np.ndarray], float]]] = {
    # effect: [(option, recipe, body dB)] — body as in `sounds.BODY` for dry transients, 0 for none.
    "bloop": [("a", bloop_drop, 0), ("b", bloop_slit, 0), ("c", bloop_kalimba, 0)],
    "pop": [("a", pop_drop, 0), ("b", pop_bongo, 6), ("c", pop_cork, 3)],
    "boing": [("a", boing_kalimba, 4), ("b", boing_bass, 0), ("c", boing_flexatone, 0)],
    "hit": [("a", hit_cinematic, 0), ("b", hit_punch, 3), ("c", hit_stab, 0)],
    "sparkle": [("a", sparkle_chimes, 0), ("b", sparkle_magic, 0), ("c", sparkle_glass, 0)],
    "shutter": [("a", shutter_slr, 3), ("b", shutter_film, 3), ("c", shutter_phone, 3)],
    "countdown": [("a", countdown_beeps, 0), ("b", countdown_drums, 0), ("c", countdown_sticks, 0)],
    "tickTock": [("a", tick_tock_clock, 3), ("b", tick_tock_claves, 3), ("c", tick_tock_wood, 3)],
    "footsteps": [("a", footsteps_indoor, 6), ("b", footsteps_hallway, 4), ("c", footsteps_running, 3)],
    "rimshot": [("a", rimshot_classic, 0), ("b", rimshot_hihat, 0), ("c", rimshot_brushes, 0)],
    "cashRegister": [("a", cash_mechanical, 0), ("b", cash_bell, 0), ("c", cash_chips, 0)],
}


def main() -> None:
    names = sys.argv[1:] or list(VARIANTS)
    facts_path = os.path.join(FOLDER, "variants.json")
    facts = json.load(open(facts_path)) if os.path.exists(facts_path) else {}
    for name in names:
        for option, recipe, body in VARIANTS[name]:
            made = recipe()
            sound = E.leveled(bodied(made, body) if body else made)
            key = f"{name}-{option}"
            facts[key] = E.write(key, sound, FOLDER)
            print(key, facts[key])
    os.makedirs(FOLDER, exist_ok=True)
    with open(facts_path, "w") as file:
        json.dump(facts, file, indent=1)


if __name__ == "__main__":
    main()
