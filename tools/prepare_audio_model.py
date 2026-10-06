# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate nominal circuit coefficients and independent floating-point vectors.

Run model_audio.py first for the separate KCL/frequency checks. These are
component-derived authored coefficients, not arcade ROM data.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

from model_audio import audio_network, ladder, FS, COEFFICIENT_BITS, STATE_BITS, ROOT


def hex_words(path: Path, words: np.ndarray | list[int], bits: int = 32) -> None:
	mask, digits = (1 << bits) - 1, (bits + 3) // 4
	temporary = path.with_suffix(path.suffix + ".tmp")
	temporary.write_text("".join(f"{int(word) & mask:0{digits}x}\n" for word in np.asarray(words).flatten()), encoding="ascii", newline="\n")
	temporary.replace(path)


def main() -> None:
	a, b = audio_network()
	transition = np.linalg.solve(np.eye(9) - a / (2 * FS), np.eye(9) + a / (2 * FS))
	input_coeff = np.linalg.solve(np.eye(9) - a / (2 * FS), b / (2 * FS))
	# The integrators supply music high-counts/16 and effects volts/16
	# accumulated across 1000 SYS clocks. These conversions include the
	# half-pot reference and the /4 passive three-source resistor sum.
	input_coeff[:, 1] *= 0.01
	input_coeff[:, 2] *= 0.002
	coefficients = np.c_[transition, input_coeff]
	assert np.max(abs(coefficients)) < 8
	hex_words(ROOT / "rtl/sound/victory_audio_coefficients.hex", np.round(coefficients * 2**COEFFICIENT_BITS).astype(np.int64), bits=36)
	ladder_coefficients = []
	ladder_models = []
	for index in range(512):
		volumes = (index & 7, (index >> 3) & 7, (index >> 6) & 7)
		ladder_a, bias, _ = ladder(volumes)
		ladder_models.append((ladder_a, bias))
		ladder_coefficients.extend(np.round(np.c_[ladder_a, bias] * 2**COEFFICIENT_BITS).astype(np.int64).flatten())
	hex_words(ROOT / "rtl/sound/victory_ladder_coefficients.hex", ladder_coefficients, bits=36)
	# Independent floating-point reference, not a copy of RTL MAC ordering.
	# Include impulses, DC recovery, tones/chirps, all 512 tap combinations,
	# and simultaneous maximum signals that require final output clipping.
	destination = ROOT / "simulation/audio"
	destination.mkdir(parents=True, exist_ok=True)
	state = np.zeros(9)
	capacitors = np.zeros(3)
	previous_input = np.zeros(3)
	inputs, expected = [], []
	for n in range(24576):
		index = 0 if n < 4096 else (n // 32) % 512
		if n < 4096:
			speech = 1.0 if n == 0 else 0.0
			music = 187.5 if n == 256 else 0.0
			effects = 937.5 if n == 512 else 0.0
		elif n < 8192:
			speech, music, effects = 1.0, 187.5, 937.5
		else:
			speech = np.sin(2 * np.pi * 1123 * n / FS)
			music = 93.75 * (1 + np.sin(2 * np.pi * 261.7 * n / FS))
			effects = 468.75 * (1 + np.sin(2 * np.pi * (0.00002 * n*n + 0.0002*n)))
		current_input = np.round(np.array([speech, music, effects]) * 2**STATE_BITS).astype(np.int64)
		values = current_input / 2**STATE_BITS
		state = transition @ state + input_coeff @ (values + previous_input)
		previous_input = values
		ladder_a, bias = ladder_models[index]
		capacitors = ladder_a @ capacitors + bias
		# Output reference is volts normalized to +/-12 V; 2731 is the
		# reproducible PCM-per-volt coefficient rounded to an integer.
		pcm = min(32767, max(-32768, int(np.floor(state[-1] * 2731))))
		inputs.extend([*current_input.tolist(), index])
		expected.extend([pcm, *np.round(capacitors * 2**STATE_BITS).astype(np.int64).tolist()])
	hex_words(destination / "inputs.hex", inputs)
	hex_words(destination / "expected.hex", expected)
	print("Generated 108 audio and 6144 loaded-ladder coefficients; 24576 independent float-reference frames.")


if __name__ == "__main__":
	main()
