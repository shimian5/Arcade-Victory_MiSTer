# Nominal analog audio model

The production tables in `rtl/sound/` are derived from Exidy drawing
**77-0005-01, sheets 8 and 9**, revision A, in the
[Victory Operation and Service Manual](https://www.arcade-museum.com/manuals-videogames/V/Victory.pdf)
(PDF pages 57/58). The copyrighted manual scan is referenced rather than
redistributed. All numerical inputs needed to regenerate the tables are
included in `tools/model_audio.py`; no manual, ROM or external data file is
needed to run the generator.

## Reproduce the tables

From the repository root, use Python 3.13 and the tested NumPy version:

```sh
python -m pip install -r tools/requirements-audio.txt
python tools/model_audio.py
python tools/prepare_audio_model.py
```

The first command after installation checks the continuous network against
independent complex nodal equations at eleven frequencies, all 512 volume
settings against a complete ladder KCL solve, and stability after coefficient
quantization. The generator writes:

- `rtl/sound/victory_audio_coefficients.hex`: 108 signed 36-bit words,
  nine rows of nine state-transition and three input coefficients.
- `rtl/sound/victory_ladder_coefficients.hex`: 6,144 signed 36-bit words,
  512 settings of three rows of three transition coefficients and one bias.

Words are lowercase, nine-digit hexadecimal two's-complement values with
32 fractional bits, one per line. Matrices are stored in row-major order.
The ladder setting index uses bits 2:0, 5:3 and 8:6 for the three tap selectors.
The production reader is `rtl/sound/victory_audio.sv`.

The generator also creates ignored floating-point reference vectors under
`simulation/audio/`. They are generated outputs, not inputs to the model.
`python tools/model_audio.py --write` optionally writes an ignored analysis
report under `docs/`. Simulations and local test harnesses are not distributed.
To adjust the model, edit the component values or assumptions in
`model_audio.py`, rerun its independent checks, then regenerate both tables.
Changes to the hardware scaling must also match `prepare_audio_model.py` and
`victory_audio.sv`.

## Circuit inputs

| Network | Nominal inputs represented in the source model |
| --- | --- |
| Speech coupling and interacting TL082 low-pass | C3 4.7 uF; R10/R12/R14 10 kohm; R13 20 kohm; C6 4,300 pF; C7 0.01 uF; C4 820 pF |
| Following speech gain | R3 10 kohm / R4 2.2 kohm; POT1 10 kohm at half travel |
| Music/effects passive sums | Three 10 kohm output resistors per source group and a 10 kohm pot; the loaded top voltage is the sum divided by four |
| Separate coupling and common mix | Three 22 kohm series paths; C8/C9/C10 0.2 uF; 10 kohm mix loading and nominal gain 56 |
| Cabinet amplifier | Assumed external PVOL 10 kohm at half travel; C45 0.2 uF, R1 10 kohm, R2 33 kohm, C46 0.005 uF |
| Effects volume ladder | Cumulative tap resistances 39, 78, 160, 320, 650, 1,330, 2,630 and 5,330 ohms; each selected switch adds 470 ohms; C11/C12/C13 4.7 uF to ground |

The nine audio states retain speech coupling, the interacting low-pass,
separate music/effects/speech coupling paths, common mixing and cabinet
amplifier filtering. The three volume states retain capacitor voltage across
selector changes, including coincident taps and shared-ladder loading.
Audio uses a bilinear transition at 48 kHz; volume states use an exact
zero-order-hold transition. Capacitor states have 20 fractional bits.

## Explicit assumptions and limits

Op-amps and timer sources are ideal; component values are nominal. POT1/2/3
use the schematic 10 kohm value at 50% travel. External PVOL's value is absent
from sheet 9, so 10 kohm at 50% is a reference assumption. CD4051's 470-ohm
resistance is the typical maximum over signal voltage at 5 V / 25 C in the
[TI CD405xB datasheet](https://www.ti.com/lit/ds/symlink/cd4051b.pdf), not a
measurement from a Victory board.

Speech full scale is normalized to an ideal 1 V peak. Music/effects input
conversions include the half-pot setting and passive sum; their factors are
0.01 and 0.002 in the generator. Timer levels are integrated across each
1,000-clock interval at 48 MHz. This rectangular reconstruction window
reduces sample-level aliases without claiming ideal anti-alias filtering.
PCM uses 2,731 counts per modeled volt and saturates to signed 16 bits.

One shared MAC advances all twelve states in 360 system clocks per sample.
Pause freezes the source integrals, capacitor states and MAC together; reset
clears them. Physical tolerances, op-amp slew, intermediate analog clipping,
actual speech voltage, pot settings and speaker impedance remain unmeasured.
This models more of the analog circuit than the pinned MAME digital mixer;
it does not establish equivalence to a measured cabinet.
