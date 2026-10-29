#!/usr/bin/env python3
"""Cue's sound effects made from recordings of real instruments and objects (README.md has every source and its licence), leveled as
the app levels its effects.

    venv/bin/python tools/music/sounds.py [<effect id>…]

Writes `<renders>/effects/<id>.wav` (mono, 48 kHz, 24-bit) and `effects.json` (length, loudness, peak, when the sound starts, clicks).
"""
from __future__ import annotations

import glob
import json
import os
import sys
from typing import Callable, Dict, List

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import dsp  # noqa: E402
import effects as E  # noqa: E402
import instruments as I  # noqa: E402
from sampler import Note, render  # noqa: E402

RENDERS = os.path.join(os.environ.get("CUE_AUDIO_RENDERS", os.path.expanduser("~/Desktop/Projects/CueStudio-Audio/renders")), "effects")
PERCUSSION = os.path.join(I.VSCO, "Percussion")
WOOD = os.path.join(I.VSCO, "VSCO 1 Percussion", "varWood")


def vsco(name: str) -> np.ndarray:
    return E.take(E.first(sorted(glob.glob(os.path.join(PERCUSSION, name)))))


def wood(name: str) -> np.ndarray:
    return E.take(E.first(sorted(glob.glob(os.path.join(WOOD, name)))))


def played(instrument, notes: List[Note], seconds: float) -> np.ndarray:
    """Notes on one of the music's instruments, as mono."""
    return render(instrument, notes, seconds).mean(axis=1).astype(np.float64)


# MARK: - Big moments

def boom() -> np.ndarray:
    """A concert bass drum struck hard, a low timpani under it and a gong blooming behind, in a hall."""
    drum = E.trimmed(vsco("BDrumNewhit_v7_rr1_Sum.wav"))
    timpani = E.pitched(E.trimmed(vsco("Timpani/Timpani1_Hit_v3_rr1_Sum.wav")), -2)
    gong = E.trimmed(vsco("gongHit_f.wav"))
    out = E.layer([(0, E.normalized(drum)), (0.004, E.gain(E.normalized(timpani), -4)), (0.02, E.gain(E.normalized(gong), -14))])
    out = E.eq(out, ("highpass", 28), ("lowshelf", 80, 0.7, 3.0), ("peak", 400, 0.9, -3.0))
    return E.decay(E.room(out, 0.18, 1.8, 0.35), 1.2, 1.4)


def hit() -> np.ndarray:
    """A punch for a key point: kick and snare together, a slapstick's crack on top, a short room."""
    kit = I.drum_kit("mid")
    drums = played(kit, [Note(0, 36, 120, 1), Note(0.002, 40, 118, 1)], 1.2)
    crack = E.trimmed(wood("slapstick1.wav"))
    out = E.layer([(0, E.normalized(drums)), (0.001, E.gain(E.normalized(crack), -7))])
    out = E.eq(out, ("highpass", 35), ("peak", 3500, 1.0, 2.0))
    return E.decay(E.room(out, 0.12, 0.7, 0.5), 0.35, 0.5)


def sparkle() -> np.ndarray:
    """A bell tree run downwards, ending on a triangle."""
    tree = E.trimmed(vsco("BellTree_Stroke1_v1_Sum.wav"))
    triangle = E.trimmed(vsco("Triangle6-Hit_v1_rr1_Sum.wav"))
    out = E.layer([(0, E.normalized(tree)), (max(0.0, E.seconds(tree) * 0.55), E.gain(E.normalized(triangle), -10))])
    return E.decay(E.room(E.eq(out, ("highpass", 900)), 0.2, 1.4, 0.6), 1.1, 0.9)


def drum_roll() -> np.ndarray:
    """A snare roll swelling for two seconds, then a cymbal crash and a bass drum."""
    roll = E.trimmed(vsco("Snare2-rollSN_v5_rr1_Sum.wav"))[: int(2.0 * 48000)]
    swell = np.linspace(0.35, 1.0, len(roll)) ** 1.6
    roll = E.faded(roll * swell, 0.01, 0.02)
    crash = E.trimmed(vsco("cymbal-crash1_ff_rr1.wav"))
    drum = E.trimmed(vsco("BDrumNewhit_v6_rr1_Sum.wav"))
    out = E.layer([(0, E.normalized(roll)), (2.0, E.gain(E.normalized(crash), -2)), (2.0, E.gain(E.normalized(drum), -4))])
    return E.decay(E.room(out, 0.15, 1.2, 0.5), 2.9, 1.0)


def heartbeat() -> np.ndarray:
    """Two heartbeats played on a soft bass drum, lub-dub, muffled as if heard from inside."""
    lub = E.normalized(E.trimmed(vsco("BDrumNewhit_v3_rr1_Sum.wav")))
    dub = E.gain(E.normalized(E.trimmed(vsco("BDrumNewhit_v2_rr2_Sum.wav"))), -4)
    beat = lambda x: E.decay(E.pitched(x, -3), 0.12, 0.25)  # noqa: E731
    out = E.layer([(0, beat(lub)), (0.26, beat(dub)), (0.82, beat(lub)), (1.08, beat(dub))])
    return E.eq(out, ("lowpass", 260, 0.7), ("lowshelf", 70, 0.7, 4.0))


# MARK: - Alerts and time

def tick_tock() -> np.ndarray:
    """A wooden clock: a high click and a lower knock, twice."""
    tick = E.normalized(E.trimmed(wood("wood_click_f.wav")))
    tock = E.gain(E.normalized(E.pitched(E.trimmed(wood("wood_click_f2.wav")), -4)), -1)
    out = E.layer([(0, tick), (0.5, tock), (1.0, tick), (1.5, tock)])
    return E.room(out, 0.08, 0.4, 0.5)


def tick() -> np.ndarray:
    """One small wooden click."""
    return E.room(E.normalized(E.trimmed(wood("wood_click_mp.wav"))), 0.06, 0.3, 0.5)


def countdown() -> np.ndarray:
    """Three wooden knocks half a second apart, then a bell for go."""
    knock = E.normalized(E.trimmed(vsco("LogDrumHi_MedM_v2_rr1_Sum.wav")))
    knock2 = E.normalized(E.trimmed(vsco("LogDrumHi_MedM_v2_rr2_Sum.wav")))
    bell = E.normalized(E.trimmed(vsco("Triangle6-Hit_v2_rr1_Sum.wav")))
    glock = played(I.glockenspiel(), [Note(0, 88, 110, 1)], 2.0)
    go = E.layer([(0, bell), (0, E.gain(E.normalized(glock), -3))])
    out = E.layer([(0, knock), (0.5, knock2), (1.0, knock), (1.5, E.decay(go, 0.5, 0.8))])
    return E.room(out, 0.1, 0.6, 0.5)


def ping() -> np.ndarray:
    """A soft vibraphone note with a glockenspiel touch on top: a notification that doesn't startle."""
    vibes = played(I.vibraphone(), [Note(0, 81, 90, 0.6)], 1.6)
    glock = played(I.glockenspiel(), [Note(0, 93, 50, 0.5)], 1.6)
    out = E.layer([(0, E.normalized(vibes)), (0, E.gain(E.normalized(glock), -12))])
    return E.decay(out, 0.45, 0.4)


# MARK: - Reactions

def ding() -> np.ndarray:
    """Right answer: a triangle and a glockenspiel on the same high note."""
    triangle = E.normalized(E.trimmed(vsco("Triangle6-Hit_v2_rr2_Sum.wav")))
    glock = E.normalized(played(I.glockenspiel(), [Note(0, 91, 115, 1)], 2.0))
    out = E.layer([(0, E.gain(triangle, -2)), (0, glock)])
    return E.decay(E.room(out, 0.12, 0.9, 0.6), 0.8, 0.8)


def coin() -> np.ndarray:
    """A reward: two quick glockenspiel notes a fourth apart and a shake of sleigh bells."""
    glock = played(I.glockenspiel(), [Note(0, 88, 110, 0.2), Note(0.075, 93, 120, 0.8)], 1.5)
    bells = E.trimmed(vsco("Sleighbells_Hit_v1_rr1_Mid.wav"))
    out = E.layer([(0, E.normalized(glock)), (0.07, E.gain(E.normalized(bells), -12))])
    return E.decay(out, 0.55, 0.45)


def bloop() -> np.ndarray:
    """A marimba bar struck low and bent upwards as it sounds: round and wet."""
    bar = E.trimmed(played(I.marimba(), [Note(0, 55, 110, 0.4)], 1.0))
    bent = E.gliding(bar, 0, 9, curve=0.5)
    return E.decay(E.eq(bent, ("highpass", 120)), 0.12, 0.2)


# MARK: - Transitions

def riser() -> np.ndarray:
    """A suspended cymbal swelling with mallets over a timpani roll: the classic orchestral build, cut on its peak."""
    cymbal = E.trimmed(vsco("susCymb1-cresc-Median_v1.wav"))
    rolls = sorted(glob.glob(os.path.join(PERCUSSION, "Timpani", "Rolls", "*.wav")))
    roll = E.trimmed(E.take(rolls[len(rolls) // 2])) if rolls else np.zeros(1)
    peak = int(np.argmax(np.abs(cymbal)))
    cymbal = cymbal[max(0, peak - int(2.4 * 48000)): peak + int(0.06 * 48000)]
    roll = roll[: len(cymbal)] * np.linspace(0.2, 1.0, min(len(roll), len(cymbal))) ** 2
    out = E.layer([(0, E.normalized(cymbal)), (0, E.gain(E.normalized(roll), -8))])
    return E.faded(out, attack=0.3, release=0.04)


def drop() -> np.ndarray:
    """The floor falling away: a timpani struck and its pitch let down an octave, under a bass drum and a gong's swell."""
    timpani = E.trimmed(vsco("Timpani/Timpani2_Hit_v4_rr1_Sum.wav"))
    falling = E.gliding(timpani, 0, -12, curve=0.6)
    drum = E.trimmed(vsco("BDrumNewhit_v7_rr2_Sum.wav"))
    gong = E.trimmed(vsco("gongHit_mf.wav"))
    out = E.layer([(0, E.normalized(falling)), (0, E.gain(E.normalized(drum), -3)), (0.01, E.gain(E.normalized(gong), -16))])
    return E.decay(E.eq(out, ("highpass", 25), ("lowshelf", 90, 0.7, 3.0)), 1.0, 0.8)


KENNEY = os.path.join(I.SOURCES, "Kenney")
VCSL_STRUCK = os.path.join(I.VCSL, "Idiophones", "Struck Idiophones")


def kenney(name: str) -> np.ndarray:
    return E.take(E.first(sorted(glob.glob(os.path.join(KENNEY, name)))))


def vcsl(name: str) -> np.ndarray:
    return E.take(E.first(sorted(glob.glob(os.path.join(I.VCSL, name)))))


# MARK: - Brass

def tada() -> np.ndarray:
    """Ta-daa: a short and a long B-flat major chord from trumpets, horns, trombone and tuba, a cymbal on the long one."""
    short, long_ = 0.0, 0.17
    trumpets = played(I.brass("Trumpet", "stac"), [Note(short, k, 100, 0.12) for k in (65, 70, 74)], 2.0)
    trumpets += played(I.brass("Trumpet", "sus", release=0.35), [Note(long_, k, 112, 0.95) for k in (70, 74, 77)], 2.0)
    horns = played(I.brass("F Horn", "sus", release=0.35), [Note(short, 58, 90, 0.12), Note(long_, 58, 105, 0.95), Note(long_, 65, 100, 0.95)], 2.0)
    low = played(I.brass("Tenor Trombone", "stac"), [Note(short, 46, 100, 0.12), Note(long_, 46, 110, 0.4), Note(long_, 50, 105, 0.4)], 2.0)
    low += played(I.brass("Tuba", "stac"), [Note(short, 34, 100, 0.12), Note(long_, 34, 110, 0.4)], 2.0)
    crash = E.trimmed(vsco("cymbal-crash1_mf_rr1.wav"))
    band = E.layer([(0, E.normalized(trumpets)), (0, E.gain(E.normalized(horns), -5)), (0, E.gain(E.normalized(low), -6)),
                    (long_, E.gain(E.normalized(crash), -11))])
    return E.decay(E.room(band, 0.18, 1.4, 0.55), 1.15, 0.6)


def sad_trombone() -> np.ndarray:
    """Wah, wah, wah, waaah: a trombone sliding down by semitones with a plunger, the last note held with vibrato."""
    notes = [(0.0, 55, 0.42), (0.46, 54, 0.42), (0.92, 53, 0.42)]
    steps = played(I.brass("OldTrombone", "Sustain", release=0.12), [Note(t, k, 100, n) for t, k, n in notes], 3.2)
    last = played(I.brass("OldTrombone", "Vibrato", release=0.3), [Note(1.4, 52, 105, 1.25)], 3.2)
    horn = E.layer([(0, E.normalized(steps)), (0, E.normalized(last))])
    out = E.wah(horn, [(t, n) for t, _, n in notes] + [(1.4, 1.25)], closed_hz=420)
    return E.decay(E.room(out, 0.12, 0.9, 0.5), 2.55, 0.4)


def wrong() -> np.ndarray:
    """Wrong: two low brass blats, a clash of a semitone each, the second lower (a game show's raspberry played by a band)."""
    tuba = I.brass("Tuba", "stac")
    trombone = I.brass("Tenor Trombone", "stac")
    blats = played(tuba, [Note(0, 36, 120, 0.2), Note(0.26, 35, 120, 0.35)], 1.2)
    blats += played(trombone, [Note(0, 42, 118, 0.2), Note(0, 43, 110, 0.2), Note(0.26, 41, 118, 0.35), Note(0.26, 42, 110, 0.35)], 1.2)
    return E.decay(E.room(E.eq(blats, ("highpass", 40)), 0.1, 0.6, 0.5), 0.7, 0.25)


def sting() -> np.ndarray:
    """Dun, dun, duuun: low brass and timpani strike twice, then hold a dark chord over a cymbal swell."""
    trombone = I.brass("Tenor Trombone", "stac")
    tuba = I.brass("Tuba", "stac")
    hits = played(trombone, [Note(0, 52, 118, 0.2), Note(0.32, 53, 118, 0.2)], 3.0)
    hits += played(tuba, [Note(0, 40, 118, 0.2), Note(0.32, 41, 118, 0.2)], 3.0)
    held = played(I.brass("F Horn", "sus", release=0.6), [Note(0.66, 49, 110, 1.6), Note(0.66, 55, 105, 1.6)], 3.0)
    held += played(I.brass("OldTrombone", "Sustain", release=0.6), [Note(0.66, 49, 112, 1.6)], 3.0)
    timpani = E.trimmed(vsco("Timpani/Timpani1_Hit_v3_rr1_Sum.wav"))
    out = E.layer([(0, E.normalized(hits)), (0, E.gain(E.normalized(held), -2)), (0, E.gain(E.normalized(timpani), -6)),
                   (0.32, E.gain(E.normalized(timpani), -6)), (0.66, E.gain(E.normalized(timpani), -3))])
    return E.decay(E.room(out, 0.2, 1.6, 0.4), 2.2, 0.7)


# MARK: - Comedy and moments

def boing() -> np.ndarray:
    """A flexatone slapped: the wobbling metal ring of a cartoon spring."""
    return E.decay(E.trimmed(vcsl("Idiophones/Struck Idiophones/Flexatone/flexatone_slap1.wav")), 0.6, 0.35)


def rimshot() -> np.ndarray:
    """Ba-dum-tss: a tom, then the low tom with the kick, then the cymbal, on a real kit."""
    kit = I.drum_kit("mid")
    notes = [Note(0, 48, 100, 0.2), Note(0.17, 41, 110, 0.2), Note(0.17, 36, 105, 0.2), Note(0.38, 49, 92, 1.5), Note(0.38, 38, 100, 0.2)]
    return E.decay(played(kit, notes, 2.4), 0.9, 0.9)


def slap() -> np.ndarray:
    """A slapstick's crack: two boards clapped together, the comedy hit."""
    return E.room(E.normalized(E.trimmed(vcsl("Idiophones/Struck Idiophones/Slapstick/slapstick_rr1.wav"))), 0.1, 0.5, 0.5)


def gong() -> np.ndarray:
    """A large gong struck firmly, left to bloom and then damped."""
    return E.decay(E.trimmed(vcsl("Idiophones/Struck Idiophones/Gong 1/gong_f.wav")), 2.4, 1.2)


def clang() -> np.ndarray:
    """A hammer on a car's brake drum: the metal clang for a sudden fall."""
    hit_ = E.trimmed(vcsl("Idiophones/Struck Idiophones/Brake Drum/BrakeDrum1_Hammer_v3_rr1_Mid.wav"))
    anvil = E.trimmed(vcsl("Idiophones/Struck Idiophones/Anvil/Anvil_Hit2_v3_rr1_Mid.wav"))
    out = E.layer([(0, E.normalized(hit_)), (0.003, E.gain(E.normalized(anvil), -6))])
    return E.decay(E.room(out, 0.15, 1.0, 0.5), 0.9, 0.7)


def dream() -> np.ndarray:
    """A harp glissando up two octaves of a major pentatonic, ringing: a flashback, a dream."""
    scale = [0, 2, 4, 7, 9]
    keys = [55 + 12 * octave + step for octave in range(3) for step in scale][:12]
    notes = [Note(i * 0.055, k, 70 + i * 3, 2.5) for i, k in enumerate(keys)]
    return E.decay(E.room(played(I.harp(), notes, 3.4), 0.25, 1.8, 0.55), 2.2, 0.8)


def cartoon_run() -> np.ndarray:
    """A xylophone running up a scale in a blink: something zips by, a character scurries."""
    keys = [72, 74, 76, 77, 79, 81, 83, 84, 86, 88]
    return E.decay(played(I.xylophone(), [Note(i * 0.04, k, 95, 0.3) for i, k in enumerate(keys)], 1.4), 0.7, 0.4)


def sneaky() -> np.ndarray:
    """Tiptoeing: pizzicato cellos and violins stepping in a minor key."""
    low = played(I.strings("Cello Section", "pizzT", release=0.2), [Note(t, k, 95, 0.2) for t, k in ((0, 45), (0.3, 52), (0.6, 45), (0.9, 52))], 1.8)
    high = played(I.strings("Violin Section", "Pizz", release=0.2), [Note(t, k, 85, 0.2) for t, k in ((0.15, 72), (0.45, 71), (0.75, 69), (1.05, 68))], 1.8)
    return E.decay(E.room(E.layer([(0, E.normalized(low)), (0, E.gain(E.normalized(high), -3))]), 0.15, 0.9, 0.5), 1.35, 0.3)


def record_scratch() -> np.ndarray:
    """A record stopped by hand mid-groove: pushed back and forth, then held (a bar of kick, snare, upright bass and vibraphone, all
    public-domain recordings, scratched)."""
    beat = 60 / 88
    kit = [Note(0, 36, 112, 1), Note(beat, 38, 100, 1), Note(1.5 * beat, 36, 90, 1), Note(2 * beat, 36, 108, 1), Note(3 * beat, 38, 104, 1)]
    kit += [Note(k * beat / 2, 42, 70 if k % 2 else 88, 0.3) for k in range(8)]
    bass = [Note(0, 41, 100, 1.4), Note(1.5 * beat, 48, 90, 0.8), Note(2 * beat, 45, 96, 1.4)]
    vibes = [Note(0, n, 72, 2.6) for n in (65, 69, 72, 76)]
    seconds = 4 * beat + 0.6
    groove = E.layer([(0, E.normalized(played(I.drum_kit("lofi"), kit, seconds))),
                      (0, E.gain(E.normalized(played(I.strings("Solo Contrabass", "Pizz", release=0.2), bass, seconds)), -5)),
                      (0, E.gain(E.normalized(played(I.vibraphone(), vibes, seconds)), -9))])
    moves = [(0, 1.0), (0.10, 1.0), (0.13, -3.2), (0.24, -3.0), (0.27, 2.8), (0.36, 2.6), (0.40, -2.4), (0.52, -1.0), (0.62, 0.0)]
    out = E.scratched(E.eq(groove, ("lowpass", 9000)), moves, start_at=0.8)
    return E.faded(E.eq(out, ("highpass", 120), ("peak", 2500, 0.8, 2.0)), 0.002, 0.03)


def cash_register() -> np.ndarray:
    """Ka-ching: a drawer's latch, a bright bell and a handful of coins."""
    latch = E.trimmed(kenney("rpg/OGG/metalLatch.ogg"))
    bell = E.trimmed(vcsl("Idiophones/Struck Idiophones/Hand Chimes/sus_C6_r01_main.wav"))
    triangle = E.trimmed(vsco("Triangle6-Hit_v2_rr1_Sum.wav"))
    coins = E.trimmed(kenney("rpg/OGG/handleCoins.ogg"))
    out = E.layer([(0, E.gain(E.normalized(latch), -6)), (0.06, E.normalized(bell)), (0.06, E.gain(E.normalized(triangle), -6)),
                   (0.12, E.gain(E.normalized(coins), -8))])
    return E.decay(out, 0.9, 0.5)


def referee() -> np.ndarray:
    """A referee's whistle, one short blast."""
    return E.trimmed(vcsl("Aerophones/Edge-blown Aerophones/Ball Whistle/Main_BallWhistle_Short-001.wav"))


def slide_whistle() -> np.ndarray:
    """A siren whistle sliding up and down: the cartoon jump and fall."""
    return E.faded(E.trimmed(vcsl("Aerophones/Free Aerophones/Siren/Main_SirenWhistle-005.wav")), 0.005, 0.08)


def page_turn() -> np.ndarray:
    return E.trimmed(kenney("rpg/OGG/bookFlip1.ogg"))


def footsteps() -> np.ndarray:
    steps = [kenney(f"rpg/OGG/footstep0{n}.ogg") for n in (0, 1, 2, 3)]
    return E.layer([(i * 0.42, E.normalized(E.trimmed(s)) * (0.9 if i % 2 else 1.0)) for i, s in enumerate(steps)])


def censor() -> np.ndarray:
    """The broadcast bleep: a pure 1 kHz tone (a tone is all it ever was)."""
    t = np.arange(int(0.6 * 48000)) / 48000
    return E.faded(np.sin(2 * np.pi * 1000 * t), 0.006, 0.015, curve=2.0)


# MARK: - Foley for text, taps and transitions

def click() -> np.ndarray:
    """A real mouse button: the press, and its softer release."""
    return E.layer([(0, E.normalized(E.trimmed(kenney("ui/mouseclick1.wav")))), (0.07, E.gain(E.normalized(E.trimmed(kenney("ui/mouserelease1.wav"))), -6))])


def double_click() -> np.ndarray:
    press = E.normalized(E.trimmed(kenney("ui/mouseclick1.wav")))
    release = E.gain(E.normalized(E.trimmed(kenney("ui/mouserelease1.wav"))), -6)
    return E.layer([(0, press), (0.05, release), (0.15, E.gain(press, -1)), (0.2, release)])


def typing() -> np.ndarray:
    """A burst of typing on real switches, uneven like a person, with a space bar."""
    keys = [E.normalized(E.trimmed(kenney(f"ui/switch{n}.wav"))) for n in (12, 13, 14)]
    space = E.gain(E.normalized(E.trimmed(kenney("ui/switch28.wav"))), -3)
    random = np.random.default_rng(4)
    parts, at = [], 0.0
    for index in range(11):
        sound = space if index in (4, 9) else keys[index % 3]
        parts.append((at, E.gain(sound, float(random.uniform(-4, 0)))))
        at += float(random.uniform(0.07, 0.14))
    return E.layer(parts)


def pop() -> np.ndarray:
    return E.trimmed(kenney("interface/Audio/drop_001.ogg"))


def glitch() -> np.ndarray:
    """Digital stutter: four short glitches from a real interface set, cut and repeated."""
    bits = [E.normalized(E.trimmed(kenney(f"interface/Audio/glitch_00{n}.ogg"))) for n in (1, 2, 3, 4)]
    order = [0, 0, 2, 1, 1, 3, 0, 2]
    return E.layer([(i * 0.045, bits[n]) for i, n in enumerate(order)])


def whoosh() -> np.ndarray:
    """Air rushing past: an ocean drum's beads swelled and swept, with a little Doppler drop, and a cloth swing in it."""
    beads = E.take(os.path.join(I.VCSL, "Membranophones", "Other Membranophones", "Ocean Drum", "OceanDrum_Sus_2_Mid.wav"))
    piece = beads[int(4.0 * 48000): int(4.0 * 48000) + int(0.95 * 48000)]
    piece = E.gliding(piece, 3, -4, curve=1.4)
    shape = np.concatenate([np.linspace(0, 1, int(len(piece) * 0.62)) ** 2.2, np.linspace(1, 0, len(piece) - int(len(piece) * 0.62)) ** 1.5])
    air = E.swept(piece * shape[: len(piece)], 300, 6000, 0.62)
    cloth = E.trimmed(kenney("rpg/OGG/cloth1.ogg"))
    return E.faded(E.layer([(0, E.normalized(air)), (0.18, E.gain(E.normalized(cloth), -10))]), 0.01, 0.05)


def swish() -> np.ndarray:
    """A quick cloth swing."""
    return E.faded(E.trimmed(kenney("rpg/OGG/cloth4.ogg")), 0.004, 0.03)


def shutter() -> np.ndarray:
    """A camera: the mirror's latch and the shutter's click, close together."""
    latch = E.normalized(E.trimmed(kenney("rpg/OGG/metalLatch.ogg")))
    snap = E.normalized(E.trimmed(kenney("ui/click3.wav")))
    return E.eq(E.layer([(0, snap), (0.035, E.gain(latch, -4)), (0.11, E.gain(snap, -5))]), ("highpass", 300))


RECIPES: Dict[str, Callable[[], np.ndarray]] = {
    # Today's 26
    "whoosh": whoosh, "swish": swish, "riser": riser, "drop": drop, "glitch": glitch,
    "pop": pop, "click": click, "doubleClick": double_click, "bloop": bloop, "typing": typing, "tick": tick,
    "ding": ding, "buzzer": wrong, "tada": tada, "sadTrombone": sad_trombone, "boing": boing, "coin": coin,
    "boom": boom, "hit": hit, "sparkle": sparkle, "drumRoll": drum_roll, "heartbeat": heartbeat,
    "ping": ping, "shutter": shutter, "countdown": countdown, "tickTock": tick_tock,
    # New
    "recordScratch": record_scratch, "rimshot": rimshot, "sting": sting, "gong": gong, "slap": slap, "clang": clang,
    "dream": dream, "cartoonRun": cartoon_run, "sneaky": sneaky, "cashRegister": cash_register, "referee": referee,
    "slideWhistle": slide_whistle, "pageTurn": page_turn, "footsteps": footsteps, "censor": censor,
}


# Foley whose sharp attacks would hold it far below the others: raised by this many decibels into a fast limiter first (attacks a
# little rounder, the body of the sound audible), as sound libraries master them.
BODY = {"footsteps": 6.0, "pageTurn": 6.0, "swish": 6.0, "typing": 4.0, "slap": 4.0, "shutter": 3.0, "hit": 3.0}


def bodied(x: np.ndarray, db: float) -> np.ndarray:
    peak = np.max(np.abs(x)) + 1e-12
    raised = np.stack([x, x], axis=1) / peak * 10 ** (db / 20)
    return dsp.limit(raised.astype(np.float32), 0.0, lookahead=0.0015, hold=0.02)[:, 0].astype(np.float64)


def main() -> None:
    names = sys.argv[1:] or list(RECIPES)
    facts_path = os.path.join(RENDERS, "effects.json")
    facts = json.load(open(facts_path)) if os.path.exists(facts_path) else {}
    for name in names:
        made = RECIPES[name]()
        sound = E.leveled(bodied(made, BODY[name]) if name in BODY else made)
        facts[name] = E.write(name, sound, RENDERS)
        print(name, facts[name])
    with open(facts_path, "w") as file:
        json.dump(facts, file, indent=1)


if __name__ == "__main__":
    main()
