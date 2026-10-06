# Victory for MiSTer

FPGA implementation of Exidy's **Victory (1982)**, based on Template_MiSTer
and the original operation/service schematics. Includes graphics, sound and
speech, rotary controls, pause with optional OSD pause/dimming, and automatic
2 KiB battery-RAM saving. The owner confirmed working gameplay, sound,
controls and corrected background orientation.

## Install

Copy `releases/Arcade-Victory_20261005.rbf` into `_Arcade/cores/` and
`releases/Victory (Exidy).mra` into `_Arcade/`. Supply your own MAME 0.257 split
`victory.zip` in `games/mame/`. ROM data is not included.

The **Victor Banana** modification kit is available in
`releases/_alternatives/_Victory/Victor Banana.mra`. For split ROM sets,
supply both `victorba.zip` and `victory.zip`; it uses the same Victory RBF.
On first boot without a save, press a button at **CMOS RAM RESET**.
Battery RAM saves automatically; **Save Settings** saves immediately.

## Controls

Map Thrust, Fire, Shields, Doomsday, Start, Coin, Service and Pause using the
MiSTer controller menu. D-pad Left/Right, a relative mouse/trackball/spinner,
or the horizontal stick can turn the rotary control. In the service menu,
hold Left/Right to move the knob and press Fire to select.
Optional dimming starts after ten seconds paused. Reset clears manual pause;
use **Reset and close OSD** when OSD pause is enabled.

## Video

Fresh settings default to **CRT 15kHz**; **Native** remains selectable.
Both preserve 256x256 game pixels and approximately 59.996811 Hz refresh.
CRT uses 336x262 at approximately 15.719 kHz; Native uses 336x280 at
approximately 16.799 kHz. CRT output uses a 32-row RGB24 rolling store,
with predicted conversion delay of approximately 45 microseconds to 1.04 ms.
CPU, HSC and audio retain native execution timing.

FX None uses a fixed /8 pixel divider. Direct Video with forced scandoubling
or effects uses /4 and selects Native; ordinary non-DV HQ2x retains /2.
Geometry runs inside the core on the shared analog/HDMI stream. H-Position
and V-Shift preserve RGB, DE and pixel cadence while shifting sync. H-Size
operates only on Native output without scandoubling or Direct Video. Wider shifts may crop edges; the known single
top scanline loss in Direct Video is anticipated.

## Build

```sh
git clone --recurse-submodules https://github.com/shimian5/Arcade-Victory_MiSTer.git
cd Arcade-Victory_MiSTer
```

Build with Intel Quartus Prime Lite 17.0.2. Open `Arcade-Victory.qpf` and
select **Processing > Start Compilation**, or run from the project directory
with the Quartus binaries on your PATH:

```sh
quartus_sh --flow compile Arcade-Victory
```

TV80 is pinned as a submodule; the wrapper enables external refresh.
Keep the system PLL instance named `pll`. It supplies 48 MHz CPU/audio and
a 96 MHz cascade reference for the native video PLL. All `sys/` files remain
byte-for-byte upstream; video and CRT processing use standard emu outputs
and the supported `hps_io.direct_video` indication.
The package includes `releases`, `rtl`, `sys`, required root files and the
audio reproduction scripts with their circuit documentation. Other development
material remains local. Imported licenses and notices are retained.

To reproduce the audio tables, install `tools/requirements-audio.txt`, run
`python tools/model_audio.py`, then `python tools/prepare_audio_model.py`.
All component inputs and assumptions are included; see
[the audio circuit note](docs/AUDIO_CIRCUIT.md).

## Provenance and validation

Primary reference: **Victory Operation and Service Manual, I Edition**,
HSC drawing **77-0004-01** and audio drawing **77-0005-01**, revision A.
The supplied scan and [Museum scan](https://www.arcade-museum.com/manuals-videogames/V/Victory.pdf)
were cross-checked against manufacturer datasheets. MAME comparisons below
use commit `d4024db0e8e3824d937e3d9a165119a8eb4829a2`.

The packaged stock-framework RBF passes the full Quartus flow and all 50
analyzed timing checks, minimum +0.247 ns, using 265/553 RAM blocks and five
PLLs. Its SHA256 is
`4649bbc2c3b12f4c5b23a76daeaaf0fec4ebbc485712ac367e6c9736bd58c55f`.
Integration tests pass 36 images and 33 geometry / Direct Video images,
including fixed /8 and forced /4 repetition, plus focused controls and CMOS
tests. Hardware acceptance of this framework integration remains with the
owner; the prior owner-tested build had working gameplay, sound, controls
and corrected background orientation.

Earlier original-ROM cold/cabinet validation predates the background
correction and is not claimed as a repeat full-ROM run on this artifact.
Optional physical register transformations are disabled to avoid Quartus 17
stalls with the cascade; final timing analysis remains enabled.
Combinational optimization is retained.

Factory-empty **15J** uses provisional low receiver levels; software tests
cannot establish the physical bias without board access. The current zero
input disables background-collision interrupts; see the
[15J evidence and unresolved measurements](docs/15J_UNPOPULATED.md). Analog BUSY/RGB/audio
models use nominal components and unmeasured tolerances. Generic external
speech-ROM modes and cabinet electrical adapters are outside this implementation.

## Implemented differences from pinned MAME


These follow more of the documented circuit than the listed approximations.
They are specific improvements at modeled circuit boundaries, not proof of
complete equivalence to a measured PCB.

| Circuit | Pinned MAME approximation | Current schematic implementation |
| --- | --- | --- |
| HSC execution | Software command handlers and calculated BUSY duration | PROM sequencing, RAM/write phases, ready latch and display arbitration; nominal R7/C27 BUSY filter and LS241 hysteresis. HSC sheets 2/4/7-14. |
| CPU/video storage | Direct software memory access | SEAADV ownership, shared tile/pattern/palette ports, latched palette address and physical WAIT. Live status/coordinate reads follow decoder strobes throughout RD. Sheets 4-6/16. |
| Alignment, plots and copies | Direct shifts/copies and linear addr+1 | Paired Am25LS22 storage, LS299 serialization and actual write strobes; eight-bit X wraps within its row. CMD writes do not invent command-6 triggering: 18J D6 is tied high. Sheets 7-15. |
| Vectors | Software accumulator and destination writes | Downloaded 13E direction/finish PROM, registered carry feedback, independent X/Y clocks and the SR1-only vector write phase. Sheets 8-10. |
| Foreground collision | Matching-color overlap and some write-plane masking | RGB occupancy combines before overlap; different colors collide independently of write enables. LS374/LS74 capture/pending/clear follows wiring, including coordinate capture while clear is held. Sheet 15. |
| Background collision | Scheduled hits with a 128-event budget | Continuous pre-palette VP qualification, return-edge capture and live acknowledgement, without an event budget. **Unpopulated 15J board wiring still needs verification; the current zero input disables EBIRQ.** Sheets 4/16. |
| RGB output | Uniform pal3bit conversion | Complemented 82S09 pins and nominal resistor-current weights 20:39:78. Physical blank gating and eight-pixel stream normalization preserve all pixels. Sheet 16. |
| MC6840 | Shared Exidy helper implements a mode/status subset | Manufacturer-derived modes, gates, prescaling, buffers and status acknowledgement. The board's unwired IRQ remains unwired. Audio sheet 9; Motorola DS9802R3. |
| Noise/audio network | Software LFSR surrogate and linear gains | Wired CD4006/CD4070 stages, continuous phase, resistor taps, switch loading and separate effects/music/speech filtering. Audio sheets 9/11/12; nominal assumptions remain explicit. |


## Licenses and attribution

The combined core is **GPL-3.0-or-later**. Original notices/licenses remain
with the framework, imported components and archived references.

- **Sorgelig and the upstream MiSTer team and contributors**, for the MiSTer
  platform, Template_MiSTer and the shared framework that provides video,
  audio, OSD and HPS integration. Their original source notices are retained
  in `sys/`.
- **d18c7db's TMS5220 FPGA core**, copyright 2020 d18c7db, GPL-3.0-or-later:
  [TMS5220_FPGA](https://github.com/d18c7db/TMS5220_FPGA), revision
  `5285e1eff99859ca25e9f2d6bdab10b9830dd0ff`. Original VHDL/license are in
  `rtl/sound/imports/tms5220`. Adapted `victory_tms5220.vhd` replaces four
  variable-width slices with shifts, clears PCM on reset, corrects buffer-low
  so speech starts on byte nine, and fixes three command comparisons to retain
  residual FIFO data. Original-ROM diagnostics verify these boundaries. These
  fix the imported implementation; they are not claimed as improvements over
  MAME's speech model. Speak External, status, ready and interrupts are supported.
- **T65**, Daniel Wallner, Mike Johnson, Wolfgang Scherr and Morten Leikvoll,
  BSD-style license; from [Exidy2 revision bfd1b5c](https://github.com/MiSTer-devel/Arcade-Exidy2_MiSTer/tree/bfd1b5c2a1ea7607f3cf7255b01a8dc2a11f8236/modules/cpu-t65).
- **Kitune-san's KF8253 programmable interval timer**, copyright 2020
  kitune-san, MIT. Original source and license are retained in
  `rtl/sound/imports/KF8253`.
- **TV80**, [hutch31/tv80](https://github.com/hutch31/tv80), pinned to
  `66a131c38d05ef58b3d8c4f1507a72e6e4aa5d65`; wrapper adapted from Z80-3D.
- **rmonic79's MiSTer-CRT-Adjust**, GPL-3.0-or-later, pinned unchanged at
  `c682de9f4acc61d8f4c7779efb48149d3baa3a8e` in `crt_adjust_sys.sv`.
- Pause adapted from **Jim Gregory's
  [Pause_MiSTer](https://github.com/JimmyStones/Pause_MiSTer)**, copyright 2021
  Jim Gregory, GPL-3.0-or-later. Original notices are retained in `rtl/pause.sv`.
- Relative input handling is copyright 2026 **shimian5**, GPL-3.0-or-later.
  Battery-RAM saving uses the upstream MiSTer `hps_io` upload/download interface.
