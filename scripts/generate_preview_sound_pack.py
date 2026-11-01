#!/usr/bin/env python3
"""Rebuild LearnAlert's original, preview-only sound pack (Python stdlib only).

All notes, synthesis recipes and waveforms are created here; no samples or
third-party compositions are used. Run from any directory. See
docs/sound-preview-pack.md for intended use and audio measurements.
"""
from __future__ import annotations

import argparse
from array import array
import html
import json
import math
import os
from pathlib import Path
import random
import struct
import wave

RATE = 44100
TAU = 2 * math.pi
REPO = Path(__file__).resolve().parents[1]
OUTPUT = REPO / "LearnAlert" / "Sounds" / "PreviewPack"
PREVIEW = REPO.parent / "LearnAlert-Sound-Preview"


def midi(number: float) -> float:
    return 440 * 2 ** ((number - 69) / 12)


class Canvas:
    def __init__(self, duration: float, seed: int):
        self.samples = array("d", [0.0]) * int((duration + .6) * RATE)
        self.random = random.Random(seed)

    def note(self, note: float, start: float, duration: float, gain=.3,
             voice="glass", end_note: float | None = None):
        count = int(duration * RATE)
        offset = int(start * RATE)
        frequency = midi(note)
        end_frequency = midi(end_note) if end_note is not None else frequency
        attack = .012 if voice in ("pad", "warm") else .0045
        decay = {"glass": 3.6, "bell": 5.8, "pluck": 5.2, "wood": 8.2,
                 "marimba": 6, "pad": 1.4, "warm": 2.8, "bubble": 5,
                 "sparkle": 7, "digital": 4}.get(voice, 4)
        phase = 0.0
        drift = self.random.random() * TAU
        for i in range(count):
            t = i / RATE
            position = i / count
            hz = frequency * (end_frequency / frequency) ** position
            if voice == "bubble":
                hz *= 1 + .24 * math.exp(-t * 25)
            phase += TAU * hz / RATE
            edge = min(1.0, t / attack)
            edge = math.sin(edge * math.pi / 2) ** 2
            release = min(1.0, (duration - t) / min(.07, duration * .25))
            envelope = edge * release ** 2 * math.exp(-decay * position)
            if voice == "glass":
                value = (math.sin(phase + .7 * math.exp(-t * 15) * math.sin(phase * 2))
                         + .16 * math.sin(phase * 3) * math.exp(-t * 8)) / 1.16
            elif voice == "bell":
                value = (math.sin(phase) + .34 * math.sin(phase * 2.756) * math.exp(-t * 7)
                         + .1 * math.sin(phase * 5.404) * math.exp(-t * 15)) / 1.44
            elif voice == "pluck":
                value = (math.sin(phase) + .3 * math.sin(phase * 2) * math.exp(-t * 11)
                         + .16 * math.sin(phase * 3) * math.exp(-t * 18)) / 1.46
            elif voice == "wood":
                value = (math.sin(phase) + .44 * math.sin(phase * 2.04) * math.exp(-t * 28)
                         + .12 * math.sin(phase * 3.93) * math.exp(-t * 38)) / 1.56
            elif voice == "marimba":
                value = (math.sin(phase) + .24 * math.sin(phase * 4) * math.exp(-t * 16)
                         + .09 * math.sin(phase * 7) * math.exp(-t * 25)) / 1.33
            elif voice == "pad":
                value = (math.sin(phase + .014 * math.sin(TAU * 4.2 * t))
                         + .24 * math.sin(phase * 2 + .03 * math.sin(TAU * 3.5 * t + drift))) / 1.24
            elif voice == "warm":
                value = (math.sin(phase) + .17 * math.sin(phase * 2) + .06 * math.sin(phase * 3)) / 1.23
            elif voice == "bubble":
                value = math.sin(phase + .35 * math.sin(phase * 1.5) * math.exp(-t * 20))
            elif voice == "sparkle":
                value = (math.sin(phase) + .2 * math.sin(phase * 2.01) * math.exp(-t * 20)) / 1.2
            else:  # Rounded digital triangle, never a harsh square wave.
                value = (math.sin(phase) - math.sin(phase * 3) / 9 + math.sin(phase * 5) / 25) / 1.151
            if offset + i < len(self.samples):
                self.samples[offset + i] += value * envelope * gain

    def chord(self, notes, start, duration, gain=.16, voice="pad", spread=.012):
        for index, note in enumerate(notes):
            self.note(note, start + index * spread, duration, gain, voice)

    def motif(self, notes, start=0.0, step=.11, duration=.36, gain=.3, voice="glass"):
        for index, note in enumerate(notes):
            if note is not None:
                self.note(note, start + index * step, duration, gain, voice)

    def air(self, start, duration, gain=.05, rise=False, shimmer=False):
        """Filtered breath: soft motion and firework fizz, never a loud bang."""
        offset = int(start * RATE)
        count = int(duration * RATE)
        state = 0.0
        previous = 0.0
        for i in range(count):
            position = i / count
            white = self.random.uniform(-1, 1)
            cutoff = (.02 + .2 * position) if rise else (.2 - .17 * position)
            state += cutoff * (white - state)
            value = (white - previous) * .23 if shimmer else state
            previous = white
            envelope = math.sin(math.pi * position) ** 2
            if offset + i < len(self.samples):
                self.samples[offset + i] += value * envelope * gain

    def sparkles(self, start, count=6, span=.65, gain=.11):
        for i in range(count):
            self.note(self.random.choice([84, 88, 91, 93, 96, 100]),
                      start + span * i / max(1, count - 1),
                      self.random.uniform(.12, .26), gain, "sparkle")

    def finish(self, duration, roomy=False):
        # A few quiet, differently filtered room reflections give rounded tails.
        source = array("d", self.samples)
        taps = [(.029, .1), (.061, .065), (.097, .04)]
        if roomy:
            taps += [(.151, .04), (.223, .023), (.301, .012)]
        for delay, gain in taps:
            shift = int(delay * RATE)
            previous = 0.0
            for i in range(len(source) - shift):
                previous += .38 * (source[i] - previous)
                self.samples[i + shift] += previous * gain
        length = int(duration * RATE)
        samples = self.samples[:length]
        # Soft saturation controls layered peaks without a hard limiter.
        samples = array("d", (math.tanh(value * 1.08) / 1.08 for value in samples))
        peak = max(abs(x) for x in samples)
        active = [x for x in samples if abs(x) > peak * .04]
        active_rms = math.sqrt(sum(x*x for x in active) / max(1, len(active)))
        target_rms = 10 ** (-21 / 20)
        scale = min(target_rms / max(active_rms, 1e-12),
                    10 ** (-4 / 20) / max(peak, 1e-12))
        # Whole-file edge fades are additional protection against sample clicks.
        fade_in, fade_out = int(.004 * RATE), int(.045 * RATE)
        for i in range(len(samples)):
            edge = min(1.0, i / fade_in, (len(samples) - 1 - i) / fade_out)
            samples[i] *= scale * max(0.0, edge)
        return samples


# Recipes are explicitly authored, not random variations of one effect.
# Randomness only adds reproducible microscopic timbre/sparkle variation.
UI = [
    ("correct_bloom", "Correct · Bloom", "answer.correct", .64, "A round ascending glass answer chime."),
    ("incorrect_soft", "Try again · Soft", "answer.incorrect", .52, "A gentle low wooden answer cue, without a buzzer."),
    ("correct_sparkle", "Correct · Sparkle", "answer.correct.alternate", .82, "Two bright bell notes with a tiny sparkling finish."),
    ("answer_locked", "Answer selected", "answer.selected", .26, "A small, satisfying rounded pluck."),
    ("card_flip", "Card flip", "card.flip", .34, "A soft paper-like air sweep and downward bubble."),
    ("card_reveal", "Reveal", "card.reveal", .58, "An opening, gently rising fifth."),
    ("card_next", "Next card", "card.next", .31, "A quiet two-part wooden tick."),
    ("pair_matched", "Perfect pair", "matching.matched", .56, "Two plucked notes joining in harmony."),
    ("blank_filled", "Blank filled", "blank.filled", .3, "A rounded digital drop seating into place."),
    ("hint_glow", "A little hint", "hint.opened", .72, "An airy suspended chord with a warm bell."),
    ("deck_added", "Deck added", "deck.added", 1.02, "A friendly three-note marimba lift."),
    ("deck_removed", "Deck removed", "deck.removed", .57, "A soft descending wooden tuck."),
    ("deck_pinned", "Pinned", "deck.pinned", .48, "A tiny tactile wooden pin and glass accent."),
    ("saved", "Saved", "data.saved", .61, "A compact resolved two-note confirmation."),
    ("search_open", "Search", "search.opened", .3, "A short airy rising glint."),
    ("filter_set", "Filter changed", "filter.selected", .28, "A low, soft tactile selection pop."),
    ("like", "A little love", "community.liked", .67, "A warm two-part heartbeat with a bright little bloom."),
    ("unlike", "Heart released", "community.unliked", .4, "A small, gently falling bubble."),
    ("profile_ready", "Hello, you", "profile.created", 1.18, "A welcoming plucked major-seventh flourish."),
    ("upload_start", "Sending", "upload.started", .75, "A smooth upward digital send."),
    ("upload_done", "Shared!", "upload.completed", 1.22, "A broad warm chord and bell answer."),
    ("download_done", "Download ready", "download.completed", 1.01, "Descending glass settling into a soft marimba note."),
    ("import_start", "Import begins", "anki.import.started", .83, "A gentle unfolding digital arpeggio."),
    ("import_step", "Import milestone", "anki.import.milestone", .49, "A tiny two-note progress marker."),
    ("import_done", "All unpacked", "anki.import.completed", 1.4, "A climbing sequence resolving into a spacious glass chord."),
    ("level_complete", "Topic complete", "study.topic.completed", 1.6, "An encouraging marimba flourish with a bright final accent."),
    ("streak", "On a roll", "study.streak", 1.31, "An upbeat, syncopated rounded digital riff."),
    ("daily_done", "That is enough for today", "study.daily.completed", 1.95, "A calm, contented bell and soft major-sixth landing."),
    ("pause", "Take a breath", "study.paused", .55, "A soft suspended pair fading gently away."),
    ("schedule_stop", "Alerts paused", "schedule.stopped", .62, "A calm descending interval with no alarm quality."),
]

RINGTONES = [
    ("cloud_drops", "Cloud drops", [76, 79, 83, 79, None, 76, 84], "glass", .24, 2.52),
    ("woodland", "Woodland", [67, 74, 71, None, 67, 76, 74], "wood", .26, 2.55),
    ("little_orbit", "Little orbit", [72, 79, 84, 79, 74, 81, 86], "digital", .22, 2.46),
    ("sunbeam", "Sunbeam", [77, 81, 84, None, 79, 84, 89], "bell", .25, 2.8),
    ("pebble_pool", "Pebble pool", [72, 76, None, 79, 76, None, 84], "bubble", .25, 2.55),
    ("morning_keys", "Morning keys", [69, 73, 76, 81, None, 76, 73, 69], "marimba", .2, 2.52),
    ("paper_lantern", "Paper lantern", [74, 78, 81, None, 78, 85, 81], "pluck", .255, 2.7),
    ("blue_hour", "Blue hour", [67, 74, 78, 81, None, 78, 74], "warm", .25, 2.9),
    ("tiny_comet", "Tiny comet", [81, 88, 85, None, 83, 90, 88, 85], "sparkle", .19, 2.45),
    ("pocket_garden", "Pocket garden", [72, 76, 79, 76, None, 74, 77, 81, 84], "marimba", .21, 2.9),
]

CELEBRATIONS = [
    ("sky_bloom", "Sky bloom", [72, 76, 79, 84], "glass", [60, 64, 67, 72], 2.55),
    ("confetti_pop", "Confetti pop", [76, 79, 84, 88, 91], "marimba", [60, 67, 72, 76], 2.3),
    ("starlight", "Starlight", [79, 83, 86, 91, 95], "bell", [55, 62, 67, 71], 2.95),
    ("rocket_ripple", "Rocket ripple", [69, 73, 76, 81, 85], "bubble", [57, 64, 69, 73], 2.55),
    ("arcade_daydream", "Arcade daydream", [72, 79, 76, 84, 88, 91], "digital", [60, 64, 67, 74], 2.5),
    ("golden_hour", "Golden hour", [65, 69, 72, 77, 81], "warm", [53, 60, 65, 69], 3.1),
    ("sparkler_dance", "Sparkler dance", [74, 81, 78, 85, 90], "pluck", [62, 66, 69, 76], 2.65),
    ("paper_fireworks", "Paper fireworks", [67, 71, 74, 79, 83], "wood", [55, 62, 67, 71], 2.4),
    ("moonrise", "Moonrise", [76, 80, 83, 88], "pad", [52, 59, 64, 68], 3.2),
    ("grand_little_finale", "Grand little finale", [72, 76, 79, 84, 88, 91, 96], "glass", [48, 60, 64, 67, 72], 3.05),
]


def render_ui(index, spec):
    ident, _, _, duration, _ = spec
    c = Canvas(duration, 101 + index)
    if ident == "correct_bloom":
        c.motif([76, 81], step=.105, duration=.42, gain=.38)
    elif ident == "incorrect_soft":
        c.motif([57, 55], step=.13, duration=.29, gain=.38, voice="wood")
        c.note(45, .02, .26, .09, "warm")
    elif ident == "correct_sparkle":
        c.motif([79, 84], step=.14, duration=.48, gain=.33, voice="bell")
        c.sparkles(.32, 3, .16, .09)
    elif ident == "answer_locked":
        c.note(77, .0, .22, .4, "pluck")
    elif ident == "card_flip":
        c.air(0, .24, .16, rise=True)
        c.note(82, .07, .19, .18, "bubble", 67)
    elif ident == "card_reveal":
        c.note(69, .0, .43, .26, "warm")
        c.note(76, .08, .42, .29, "glass")
    elif ident == "card_next":
        c.motif([74, 79], step=.055, duration=.2, gain=.29, voice="wood")
    elif ident == "pair_matched":
        c.motif([72, 79], step=.09, duration=.36, gain=.31, voice="pluck")
        c.note(76, .14, .31, .14, "warm")
    elif ident == "blank_filled":
        c.note(86, 0, .23, .3, "digital", 74)
    elif ident == "hint_glow":
        c.chord([67, 72, 74], 0, .57, .11, "pad")
        c.note(86, .12, .42, .2, "bell")
    elif ident == "deck_added":
        c.motif([65, 69, 77], step=.14, duration=.55, gain=.34, voice="marimba")
    elif ident == "deck_removed":
        c.motif([69, 64, 57], step=.085, duration=.29, gain=.31, voice="wood")
        c.air(.06, .28, .08)
    elif ident == "deck_pinned":
        c.note(62, 0, .17, .34, "wood")
        c.note(86, .045, .32, .17, "glass")
    elif ident == "saved":
        c.motif([71, 76], step=.1, duration=.38, gain=.32, voice="warm")
    elif ident == "search_open":
        c.note(73, 0, .24, .25, "glass", 85)
        c.air(0, .18, .05, rise=True)
    elif ident == "filter_set":
        c.note(64, 0, .2, .34, "bubble")
        c.note(76, .025, .16, .12, "wood")
    elif ident == "like":
        c.note(52, .0, .18, .33, "warm")
        c.note(59, .13, .2, .28, "warm")
        c.motif([81, 88], .21, .06, .29, .2, "bubble")
    elif ident == "unlike":
        c.note(74, 0, .3, .3, "bubble", 67)
    elif ident == "profile_ready":
        c.motif([67, 71, 74, 78, 79], step=.13, duration=.51, gain=.26, voice="pluck")
        c.chord([55, 62, 67], .34, .61, .07)
    elif ident == "upload_start":
        c.note(60, 0, .47, .26, "digital", 79)
        c.note(84, .35, .28, .22, "glass")
        c.air(.03, .42, .06, rise=True)
    elif ident == "upload_done":
        c.chord([60, 64, 67], 0, .76, .16, "warm")
        c.motif([79, 84, 88], .12, .15, .62, .24, "bell")
    elif ident == "download_done":
        c.motif([84, 79, 76], step=.12, duration=.38, gain=.24)
        c.note(60, .35, .51, .34, "marimba")
    elif ident == "import_start":
        c.motif([60, 67, 72, 76], step=.105, duration=.39, gain=.26, voice="digital")
        c.air(.1, .46, .065, rise=True)
    elif ident == "import_step":
        c.motif([79, 81], step=.075, duration=.31, gain=.25, voice="marimba")
    elif ident == "import_done":
        c.motif([60, 64, 67, 72, 79, 84], step=.1, duration=.49, gain=.25)
        c.chord([72, 76, 79], .56, .64, .14, "pad")
    elif ident == "level_complete":
        c.motif([65, 69, 72, 77, 81, 84], step=.115, duration=.52, gain=.29, voice="marimba")
        c.chord([65, 72, 77], .62, .65, .1, "warm")
        c.sparkles(.72, 4, .29, .07)
    elif ident == "streak":
        for note, start in [(72, 0), (76, .13), (79, .24), (76, .43), (84, .57), (88, .72)]:
            c.note(note, start, .38, .27, "digital")
    elif ident == "daily_done":
        c.motif([79, 76, 72, 69, 72], step=.19, duration=.61, gain=.23, voice="bell")
        c.chord([48, 60, 64, 69], .54, 1.1, .08, "pad")
    elif ident == "pause":
        c.chord([65, 72], 0, .44, .24, "warm", .06)
    elif ident == "schedule_stop":
        c.motif([72, 67], step=.14, duration=.35, gain=.28, voice="marimba")
    else:
        raise ValueError(ident)
    return c.finish(duration, duration > 1)


def render_ringtone(index, spec):
    ident, _, notes, voice, step, duration = spec
    c = Canvas(duration, 301 + index)
    c.motif(notes, .06, step, .62 if voice in ("bell", "warm") else .45, .3, voice)
    # Each ringtone has a supporting texture rather than a second loud melody.
    if ident in ("sunbeam", "blue_hour", "paper_lantern"):
        root = next(note for note in notes if note is not None) - 24
        c.chord([root, root + 7], .06, duration - .5, .05, "pad", .025)
    if ident == "pebble_pool":
        c.air(.05, .4, .035)
    if ident == "tiny_comet":
        c.note(72, .01, .8, .07, "glass", 96)
    return c.finish(duration, roomy=True)


def render_celebration(index, spec):
    ident, _, notes, voice, chord, duration = spec
    c = Canvas(duration, 501 + index)
    step = [.105, .085, .15, .11, .09, .15, .115, .095, .17, .085][index]
    lift_duration = len(notes) * step
    c.air(0, lift_duration + .16, .09, rise=True)
    c.motif(notes, .055, step, .58 if voice != "pad" else .95, .28, voice)
    burst = lift_duration + .07
    c.chord(chord, burst, duration - burst - .18, .13 if len(chord) < 5 else .1, "pad", .018)
    c.note(notes[-1] + 12, burst, .73, .22, "bell")
    c.air(burst + .025, .57, .12, shimmer=True)
    c.sparkles(burst + .15, 6 + index % 4, min(.85, duration - burst - .45), .09)
    if ident == "rocket_ripple":
        c.note(notes[0] - 12, 0, .57, .11, "bubble", notes[-1])
    elif ident == "arcade_daydream":
        c.motif([notes[-1], notes[-2], notes[-1]+7], burst+.2, .1, .34, .1, "digital")
    elif ident == "golden_hour":
        c.chord([chord[0]-12, chord[1]], burst+.04, 1.55, .09, "warm")
    elif ident == "paper_fireworks":
        for start in [burst+.1, burst+.3, burst+.48]:
            c.air(start, .14, .11, shimmer=True)
    elif ident == "moonrise":
        c.note(notes[0]-12, 0, 1.3, .1, "warm", notes[-1]-12)
    elif ident == "grand_little_finale":
        c.motif([notes[-1]-12, notes[-1]-5, notes[-1]], burst+.33, .095, .67, .16, "marimba")
        c.sparkles(burst+.6, 10, .72, .065)
    return c.finish(duration, roomy=True)


def write_wav(path: Path, samples):
    pcm = array("h", (round(max(-1, min(1, x)) * 32767) for x in samples))
    if struct.pack("=H", 1) != struct.pack("<H", 1):
        pcm.byteswap()
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())


def measurements(samples):
    peak = max(abs(x) for x in samples)
    rms = math.sqrt(sum(x*x for x in samples) / len(samples))
    return {"duration": round(len(samples) / RATE, 4),
            "peakDBFS": round(20 * math.log10(max(peak, 1e-12)), 2),
            "rmsDBFS": round(20 * math.log10(max(rms, 1e-12)), 2)}


def make_preview(entries, rendered):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    rows = []
    for entry in entries:
        source = Path(os.path.relpath(OUTPUT / entry['fileName'], PREVIEW)).as_posix()
        rows.append(f"<article><strong>{html.escape(entry['title'])}</strong>"
                    f"<small>{html.escape(entry['category'])} · {entry['duration']:.2f}s</small>"
                    f"<audio controls preload='none' src='{source}'></audio>"
                    f"<p>{html.escape(entry['description'])}</p></article>")
    page = """<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>
<title>LearnAlert original sound sketches</title><style>
body{font:15px system-ui;margin:30px auto;max-width:1000px;padding:0 20px;color:#dfe9f2;background:#131a20}
header{max-width:720px;margin-bottom:28px}h1{font-size:26px}p,small{color:#a5b9c9}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:12px}
article{padding:16px;border:1px solid #394957;border-radius:14px;background:#1b252e}strong,small{display:block}small{margin:6px 0}audio{width:100%;margin-top:8px}p{font-size:13px;line-height:1.5}
</style><header><h1>LearnAlert · 50 original sound sketches</h1><p>30 app effects, 10 notification ringtones, and 10 schedule celebrations. Preview only; none of the existing app sounds are replaced. These are original procedural compositions with no third-party samples.</p></header><main>""" + "".join(rows) + "</main>"
    (PREVIEW / "index.html").write_text(page)
    # A spaced montage makes it easy to scan the family without fifty taps.
    sampler = array("d")
    silence = array("d", [0]) * int(.55 * RATE)
    for samples in rendered:
        sampler.extend(samples)
        sampler.extend(silence)
    write_wav(PREVIEW / "learnalert-50-sound-sampler.wav", sampler)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-preview", action="store_true", help="Skip the HTML index and long sampler.")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    entries, rendered = [], []
    for index, spec in enumerate(UI):
        ident, title, event, _, description = spec
        samples = render_ui(index, spec)
        filename = f"la_ui_{ident}.wav"
        write_wav(OUTPUT / filename, samples)
        entries.append({"id": f"ui.{ident}", "title": title, "category": "interface",
                        "event": event, "fileName": filename, "description": description,
                        **measurements(samples)})
        rendered.append(samples)
    for index, spec in enumerate(RINGTONES):
        ident, title, _, voice, _, _ = spec
        samples = render_ringtone(index, spec)
        filename = f"la_ring_{ident}.wav"
        write_wav(OUTPUT / filename, samples)
        entries.append({"id": f"ringtone.{ident}", "title": title, "category": "ringtone",
                        "event": "notification.ringtone", "fileName": filename,
                        "description": f"A short, original {voice} notification motif with a soft room tail.",
                        **measurements(samples)})
        rendered.append(samples)
    for index, spec in enumerate(CELEBRATIONS):
        ident, title, _, _, _, _ = spec
        samples = render_celebration(index, spec)
        filename = f"la_schedule_{ident}.wav"
        write_wav(OUTPUT / filename, samples)
        entries.append({"id": f"celebration.{ident}", "title": title, "category": "celebration",
                        "event": "schedule.started", "fileName": filename,
                        "description": "An ascending lift, harmonic bloom and gentle firework sparkles.",
                        **measurements(samples)})
        rendered.append(samples)
    manifest = {"version": 1, "sampleRate": RATE, "channels": 1, "bitsPerSample": 16,
                "created": "2026-11-01", "license": "Original LearnAlert procedural sound designs; no third-party samples.",
                "previewOnly": True, "sounds": entries}
    (OUTPUT / "learnalert-sound-pack.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    if not args.no_preview:
        make_preview(entries, rendered)
    print(json.dumps({"files": len(entries), "durations": {"min": min(x["duration"] for x in entries),
          "max": max(x["duration"] for x in entries), "total": round(sum(x["duration"] for x in entries), 2)},
          "peakDBFS": {"min": min(x["peakDBFS"] for x in entries), "max": max(x["peakDBFS"] for x in entries)},
          "bytes": sum((OUTPUT / x["fileName"]).stat().st_size for x in entries)}, indent=2))


if __name__ == "__main__":
    main()
