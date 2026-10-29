"""The lo-fi track with no drums at all: the muffled upright, upright bass and vibraphone (one of the two takes the owner asked for, 29/10)."""
from __future__ import annotations

from track import Track
from tracks import lofi


def make() -> Track:
    return lofi.make(drums=False)
