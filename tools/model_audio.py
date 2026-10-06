# SPDX-License-Identifier: GPL-3.0-or-later
"""Component-level nominal audio network, Exidy 77-0005-01 sheets 8/9.

Source model for the production coefficient tables. Capacitor
voltages are states; ideal op-amps and switches avoid inventing PCB tolerances.
CD4051 on resistance uses TI's 25 C / 5 V typical maximum over signal voltage.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
FS = 48000.0
COEFFICIENT_BITS = 32
STATE_BITS = 20
TAPS = np.array([39, 78, 160, 320, 650, 1330, 2630, 5330], dtype=float)
POT_FRACTION = 0.5
POT_OHMS = 10000.0
SWITCH_OHMS = 470.0


def ladder(volumes: tuple[int, int, int]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
	"""Eliminate the resistive ladder to its three capacitor ports.

	R_ij is the Green's resistance of a chain driven at both ends. Each
	selected port adds its own series switch, including coincident taps.
	"""
	r = TAPS[list(volumes)]
	resistance = np.minimum.outer(r, r) - np.outer(r, r) / TAPS[-1]
	resistance += np.eye(3) * SWITCH_OHMS
	conductance = np.linalg.inv(resistance)
	target = 5.0 * r / TAPS[-1]
	a = -conductance / 4.7e-6
	b = conductance @ target / 4.7e-6
	# Exact zero-order hold is suitable for these DC volume-control states.
	# Equal capacitances make A real symmetric: diagonalize without scipy.
	eigenvalues, vectors = np.linalg.eigh(a)
	transition = (vectors * np.exp(eigenvalues / FS)) @ vectors.T
	bias = (np.eye(3) - transition) @ target
	return transition, bias, resistance


def full_ladder_nodal(volumes: tuple[int, int, int], capacitor_volts: np.ndarray) -> np.ndarray:
	"""Independent 11-node KCL solve, retaining every ladder resistor.

	The end at +5 V is a known voltage. Seven internal taps and three
	capacitor-port current equations remain; the redundant rail tap is kept
	as an explicit voltage equation to make port indexing straightforward.
	"""
	g = np.zeros((8, 8))
	rhs = np.zeros(8)
	resistors = np.diff(np.r_[0.0, TAPS])
	for node in range(7):
		g[node, node] += 1.0 / resistors[node]
		if node:
			g[node, node - 1] -= 1.0 / resistors[node]
		g[node, node] += 1.0 / resistors[node + 1]
		g[node, node + 1] -= 1.0 / resistors[node + 1]
	g[7, 7] = 1.0
	rhs[7] = 5.0
	for channel, tap in enumerate(volumes):
		if tap != 7:
			g[tap, tap] += 1.0 / SWITCH_OHMS
			rhs[tap] += capacitor_volts[channel] / SWITCH_OHMS
	tap_volts = np.linalg.solve(g, rhs)
	return (tap_volts[list(volumes)] - capacitor_volts) / SWITCH_OHMS


def audio_network() -> tuple[np.ndarray, np.ndarray]:
	"""Continuous nine-state model including C3 and the final power filter.

	States: C3 voltage, C6/C7 node voltages, first TL082 output, C8/C9/C10
	voltages, C45 voltage, final amplifier output. R11 loads an ideal SPK
	source without altering its voltage. Audio inputs are ideal speech SPK,
	post-pot music and post-pot effects volts. Power POT is a documented
	10k/half reference setting, since its external value is not on sheet 9.
	"""
	a, b = np.zeros((9, 9)), np.zeros((9, 3))
	r10, r12, r13, r14 = 10000.0, 10000.0, 20000.0, 10000.0
	c3, c6, c7, c4 = 4.7e-6, 4300e-12, 0.01e-6, 820e-12
	a[0, 0:2] = -1 / (r10 * c3)
	b[0, 0] = 1 / (r10 * c3)
	a[1, 0] = -1 / (r10 * c6)
	a[1, 1] = -(1 / r10 + 1 / r12) / c6
	a[1, 2] = 1 / (r12 * c6)
	b[1, 0] = 1 / (r10 * c6)
	a[2, 1] = 1 / (r12 * c7)
	a[2, 2] = -(1 / r12 + 1 / r13 + 1 / r14) / c7
	a[2, 3] = 1 / (r13 * c7)
	a[3, 2] = -1 / (r14 * c4)

	# Three 10k output resistors and the 10k pot are a passive sum;
	# the top voltage is (V0+V1+V2)/4, not their unscaled sum.
	r_top = 10000.0 / 3
	r_pot_low = POT_FRACTION * POT_OHMS
	r_pot_high = (1 - POT_FRACTION) * POT_OHMS
	r_tone = 1 / (1 / r_pot_low + 1 / (r_pot_high + r_top))
	r_speech = POT_FRACTION * (1 - POT_FRACTION) * POT_OHMS
	r_paths = np.array([22000 + r_speech, 22000 + r_tone, 22000 + r_tone])
	g_paths = 1 / r_paths
	y_mix = 1 / 10000 + sum(g_paths)
	h_mix = g_paths / y_mix
	g_mix = np.diag(g_paths) - np.outer(g_paths, g_paths) / y_mix
	u_state = np.zeros((3, 9))
	u_state[0, 3] = -(10000.0 / 2200.0) * POT_FRACTION
	u_input = np.array([[0., 0., 0.], [0., 1., 0.], [0., 0., 1.]])
	x_mix = np.zeros((3, 9))
	x_mix[:, 4:7] = np.eye(3)
	a[4:7, :] = (g_mix / 0.2e-6) @ (u_state - x_mix)
	b[4:7, :] = (g_mix / 0.2e-6) @ u_input
	mix_state = -56 * h_mix @ (u_state - x_mix)
	mix_input = -56 * h_mix @ u_input

	# PVOL/C45/R1 input high-pass followed by R2 || C46 feedback.
	r_master = POT_FRACTION * (1 - POT_FRACTION) * POT_OHMS
	tau_hp = (10000 + r_master) * 0.2e-6
	tau_lp = 33000 * 0.005e-6
	amp_gain = -33000 / (10000 + r_master)
	a[7, :] = POT_FRACTION * mix_state / tau_hp
	a[7, 7] -= 1 / tau_hp
	b[7, :] = POT_FRACTION * mix_input / tau_hp
	a[8, :] = amp_gain * POT_FRACTION * mix_state / tau_lp
	a[8, 7] -= amp_gain / tau_lp
	a[8, 8] -= 1 / tau_lp
	b[8, :] = amp_gain * POT_FRACTION * mix_input / tau_lp
	return a, b


def independent_response(frequency: float) -> np.ndarray:
	"""Complex nodal solve, without using the state-space matrices above."""
	s = 2j * math.pi * frequency
	if frequency == 0:
		return np.zeros(3, dtype=complex)
	g10, g12, g13, g14 = 1 / 10000, 1 / 10000, 1 / 20000, 1 / 10000
	speech = np.linalg.solve(np.array([
		[s * 4.7e-6 + g10, -g10, 0, 0],
		[-g10, g10 + g12 + s * 4300e-12, -g12, 0],
		[0, -g12, g12 + g13 + g14 + s * 0.01e-6, -g13],
		[0, 0, -g14, -s * 820e-12],
	], dtype=complex), np.array([s * 4.7e-6, 0, 0, 0]))[-1]
	r_speech = 2500.0
	r_tone = 1 / (1 / 5000.0 + 1 / (5000.0 + 10000 / 3))
	y = 1 / (np.array([22000 + r_speech, 22000 + r_tone, 22000 + r_tone]) + 1 / (s * 0.2e-6))
	response = -56 * y / (1 / 10000 + sum(y))
	response[0] *= -speech * (10000 / 2200) * POT_FRACTION
	response *= -33000 * s * 0.2e-6 / ((1 + s * 12500 * 0.2e-6) * (1 + s * 33000 * 0.005e-6)) * POT_FRACTION
	return response


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--write", action="store_true", help="write local analysis JSON")
	args = parser.parse_args()
	a, b = audio_network()
	assert max(np.linalg.eigvals(a).real) < 0
	transition = np.linalg.solve(np.eye(9) - a / (2 * FS), np.eye(9) + a / (2 * FS))
	input_coeff = np.linalg.solve(np.eye(9) - a / (2 * FS), b / (2 * FS))
	quantized_transition = np.round(transition * 2**COEFFICIENT_BITS) / 2**COEFFICIENT_BITS
	quantized_input = np.round(input_coeff * 2**COEFFICIENT_BITS) / 2**COEFFICIENT_BITS
	assert max(abs(np.linalg.eigvals(quantized_transition))) < 1
	rows = []
	for frequency in [0, 1, 20, 100, 261.7, 1000, 2000, 4000, 8000, 12000, 20000]:
		continuous = np.linalg.solve(2j * math.pi * frequency * np.eye(9) - a, b)[-1]
		reference = independent_response(frequency)
		assert max(abs(continuous - reference)) < 1e-9
		z = np.exp(2j * math.pi * frequency / FS)
		discrete = np.linalg.solve(z * np.eye(9) - quantized_transition, quantized_input * (z + 1))[-1]
		warped = FS / math.pi * math.tan(math.pi * frequency / FS)
		warped_reference = independent_response(warped)
		assert max(abs(discrete - warped_reference)) < 1e-3
		rows.append({"frequency_hz": frequency, "analog_magnitudes": abs(reference).tolist(), "quantized_magnitudes": abs(discrete).tolist()})
	maximum_ladder_eigenvalue = 0.0
	for index in range(512):
		volumes = (index & 7, (index >> 3) & 7, (index >> 6) & 7)
		ladder_a, bias, resistance = ladder(volumes)
		quantized = np.round(ladder_a * 2**COEFFICIENT_BITS) / 2**COEFFICIENT_BITS
		maximum_ladder_eigenvalue = max(maximum_ladder_eigenvalue, float(max(abs(np.linalg.eigvals(quantized)))))
		for voltages in [np.zeros(3), np.array([0.25, 2.0, 4.0]), np.array([5.0, 0.5, 1.0])]:
			currents = np.linalg.solve(resistance, 5 * TAPS[list(volumes)] / TAPS[-1] - voltages)
			assert max(abs(currents - full_ladder_nodal(volumes, voltages))) < 1e-12
	assert maximum_ladder_eigenvalue < 1
	result = {
		"source": "Victory 77-0005-01 sheets 8/9, manual PDF pages 57/58",
		"status": "source model for production coefficient tables",
		"model": "Ideal op-amps and timer sources; 470-ohm CD4051 resistance; three grounded 4.7uF volume capacitors; separate passive pot/coupling paths and common mix; final cabinet amplifier filter",
		"pot_reference": "POT1/2/3: 10k, wipers at 50%; external PVOL: assumed 10k/50% for this reference model",
		"sample_rate_hz": FS,
		"coefficient_fraction_bits": COEFFICIENT_BITS,
		"state_fraction_bits": STATE_BITS,
		"continuous_poles": [[float(x.real), float(x.imag)] for x in np.linalg.eigvals(a)],
		"maximum_quantized_pole": float(max(abs(np.linalg.eigvals(quantized_transition)))),
		"maximum_ladder_pole_all_512_settings": maximum_ladder_eigenvalue,
		"transition": transition.tolist(),
		"input_coefficients": input_coeff.tolist(),
		"response": rows,
	}
	if args.write:
		(ROOT / "docs" / "audio_network_analysis.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
	print("PASS: nine-state audio network agrees with independent complex nodal solves at 11 frequencies;")
	print("      all 512 loaded volume settings agree with complete ladder KCL; quantized poles are stable.")
	print(f"Maximum Q{COEFFICIENT_BITS} coefficient: {max(np.max(abs(transition)), np.max(abs(input_coeff))):.6f}")
	print(f"Largest quantized audio pole: {result['maximum_quantized_pole']:.9f}; ladder: {maximum_ladder_eigenvalue:.9f}")


if __name__ == "__main__":
	main()
