"""What a track hands the renderer: its stems (an instrument, its notes and how it sits in the mix) and how the whole is finished."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional, Tuple

import numpy as np

from sampler import Instrument, Note


@dataclass
class Stem:
    name: str
    instrument: Instrument
    notes: List[Note]
    # Its level while it plays, in dB against the others: each stem is first set to the same loudness where it sounds, so the balance
    # doesn't depend on how loud each library recorded its instrument.
    gain_db: float = 0.0
    pan: float = 0.0
    width: float = 1.0
    eq: Tuple = ()
    # How much goes to the room (0 dry).
    send: float = 0.15
    # (threshold dB, ratio, attack s, release s), or None.
    compress: Optional[Tuple[float, float, float, float]] = None
    # Ducked by another stem's level (a kick pushing the bass and pads down a moment), as (stem name, dB at most).
    duck: Optional[Tuple[str, float]] = None
    # Tape wow on this stem: (cents, Hz).
    wow: Optional[Tuple[float, float]] = None


@dataclass
class Mix:
    room_seconds: float = 1.8
    room_brightness: float = 0.5
    room_return_db: float = -4.0
    # The voice's band, 2–4 kHz, a few dB down for tracks meant to sit under speech.
    speech_dip_db: float = 0.0
    glue: Tuple[float, float, float, float] = (-20.0, 1.8, 0.02, 0.25)
    warmth: float = 1.2
    bus_eq: Tuple = ()
    target_lufs: float = -16.0
    ceiling_db: float = -1.0


@dataclass
class Track:
    id: str
    title: str
    tempo: float
    beats_per_bar: int
    bars: int
    seconds: float
    stems: List[Stem]
    mix: Mix = field(default_factory=Mix)
    under_speech: bool = False
    # Downbeat times of each bar, for the editor's beat snapping.
    beats: List[float] = field(default_factory=list)
    # Sounds that aren't notes (a record's crackle), added to the mix as they are, dry.
    textures: List[np.ndarray] = field(default_factory=list)
