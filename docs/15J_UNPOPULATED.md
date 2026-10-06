# Unpopulated 15J: corrected board evidence

Updated 2026-10-04. This supersedes earlier development notes describing a
"missing 15J dump" as a requirement for finishing Victory modeling.

The user reports that Exidy left HSC position 15J unpopulated at the factory.
The [Victory PCB discussion, posts 9 and 10](https://forums.arcade-museum.com/threads/exidy-victory-pcb.539236/)
provides corroborating board evidence: HudsonArcade asks about the empty position
and its schematic connections; Phil Bennett identifies another auction board
with the same position unpopulated. The thread does not establish the electrical
levels or tie-offs on the unused output nets.

The user additionally supplied a top-side HSC board photograph on 2026-10-04,
retained locally as `Victory_HSC_user_board_photo.jpg` (not distributed).
The empty socket is visible at column J, row 15, corroborating the population
finding. This photograph does not establish the underside wiring, continuity,
or electrical levels on the unpopulated socket's output nets. Its original
photographer and the board's operating condition are not established here.

The HSC schematic 77-0004-01, sheet 4, draws a 2716 at 15J. That schematic symbol
alone does not establish factory population. Its absence from the supplied set
and pinned MAME manifest is consistent with an unused position, and is not
evidence of a lost or bad dump. No fabricated ROM table is needed or justified.

## What still needs modeling evidence

The modeled socket outputs feed:

- Q7/pin 17: the horizontal limit NAND with video-control bit 7.
- Q6/pin 16: the vertical limit NAND with video-control bit 6.
- Q5/pin 15: 12J's D input, sampled by SSR LOAD; BIRQEA controls its clear.
  The resulting EBIRQ enables the background-collision pending latch.

Production currently drives all three low through `blanking_rom_data=0`.
That is a provisional software constant, not a demonstrated electrical model
of an empty socket. It leaves the limit NAND outputs high and EBIRQ low, hence
disables background-collision interrupts even though coordinate capture can
continue. Stock startup diagnostics cannot prove this behavior is correct.

Check the as-built board for pull resistors, trace changes, straps, and how these
receiver inputs are biased. Do not replace zero with `8'hff` merely because TTL
inputs often read high when undriven: the actual board configuration matters.
Once established, model the factory connections directly and validate both
background-collision interrupts and blanking/scroll behavior with original ROMs.

This is an as-built wiring verification task, not a missing-ROM acquisition task.
The optional populated-socket schematic model may remain useful for chip tests;
it must not be confused with the production factory configuration.

## Receiver documentation review

The [TI SN74LS00 datasheet](https://www.ti.com/lit/gpn/SN74LS00), section 11.1,
requires defined input bias; it does not guarantee an unconnected net's operating
level. The [TI SN74LS74A datasheet](https://www.ti.com/lit/ds/symlink/sn74ls74a.pdf)
also specifies input thresholds, not a measured voltage on this PCB. These
sources help evaluate the receivers but cannot establish undocumented straps
or bias on the photographed board. The three socket output nets must be traced
as built before production levels are accepted.

## Physical evidence request (2026-10-05)

The user confirmed that no physical board is available for this investigation.
Rechecking the PCB discussion did not establish receiver voltages, pull
resistors, or straps. This gate remains unresolved; production RTL has not
been changed on the basis of an assumed floating-input level.

A board owner or repair technician can supply the following evidence. Record
the PCB revision, receiver part markings, operating condition, and any repairs
or modifications. Identify pins from the package notch and schematic, rather
than the photograph's orientation.

| Empty 15J socket pin | Schematic destination/function | Evidence required |
| --- | --- | --- |
| 17 (Q7) | 14J horizontal-limit NAND input | Continuity to the receiver; any ground/+5 V strap or bias component; powered receiver voltage/waveform |
| 16 (Q6) | 14J vertical-limit NAND input | Continuity to the receiver; any ground/+5 V strap or bias component; powered receiver voltage/waveform |
| 15 (Q5) | 12J D2, physical pin 2; sampled into EBIRQ | Continuity to the receiver; any ground/+5 V strap or bias component; powered D2 and Q1/pin 5 waveforms |

With power disconnected, trace each net and record resistance to ground and
+5 V, including whether a connection is direct or through a resistor. In-circuit
resistance alone cannot distinguish every semiconductor path from a resistor;
include underside trace photographs or identified component connections.
Use resistance/continuity measurements only with power disconnected.

On a working board, measure at the receiver inputs, not just the empty socket.
Record voltages during startup diagnostics and gameplay. A scope trace is
needed if a net varies or has an ambiguous DC reading. For Q5, correlate 12J
D2 and Q1 with SSR LOAD at CLK1/pin 3 and BIRQEA at /CLR1/pin 1. This separates
the input level from the register's enable/clear behavior. Do not add a pull-up,
jumper, or test ROM while collecting factory-configuration evidence.

After the connections and receiver levels are established, implement those
connections explicitly. Validate Q5 sampling and BIRQEA clear, background
collision pending/coordinate capture, CPU interrupt delivery and read-clear,
then run the original-ROM processor-interrupt diagnostic and gameplay.
Check Q7/Q6 with both limit-control settings and scroll/orientation changes.
Existing synthetic high/low chip tests validate logic conditional on their
inputs; they do not satisfy this physical evidence gate.

## Victory 3.0 software audit

The main-ROM CRC32 is `8ee32752`. The repeatable
`tools/audit_15j_rom.py` audit checks the following against original ROM bytes;
its report is `simulation/socket_15j_rom_audit.json`.

The one-based diagnostic dispatcher at 0989 subtracts one before indexing the
table at 0F66. Test 4 therefore enters 0AB0. Its setup at 0E80 writes control
08 through B081, with background-interrupt enable clear. The test checks frame
and foreground interrupts and foreground coordinates, then returns through
0B47. It does not enable background interrupts or check background coordinates.
The nearby background error codes and the manual's documented tests do not
establish that this ROM revision actually executes those checks. This explains
how the existing zero-input core passes the processor-interrupt diagnostic.

The gameplay handler at B12A does contain background support: it checks status
bit 4, reads C002/C003 at B12F, corrects X and stores coordinates at E00A.
A963 contains a consumer of E00A, but finding that code is not proof that the
game reaches it. The directly identified initialization/control-set calls use
08; the byte search finds no direct CALL to the B094 control-OR helper. The
palette helper at A5C5 temporarily clears bit 5 and restores the saved control.
These static observations suggest dormant background support, not a proven
whole-game absence of background interrupts. Passive gameplay traces are
required before narrowing that conclusion.

MAME supplies background events and gates its CPU IRQ with control bit 5. This
models behavior when enabled; it does not prove that Victory 3.0 enables it.
MAME is consistent with a Q5-high receiver hypothesis, but cannot distinguish
a pull-up, direct tie, or floating receiver, and does not resolve Q7/Q6.

That consistency is conditional on BIRQEA being enabled. The runtime comparison
below demonstrates a separate MAME shortcut: background pending/status can be
set with BIRQEA off, independently of any Q5 level in our schematic model.
Changing Q5 to high cannot reproduce that behavior while BIRQEA holds 12J clear.

## Receiver and collision acceptance

`make -C sim socket-15j` tests all eight Q7/Q6/Q5 combinations, both enable
states, both collision masks, and all 64 foreground/background pixel pairs:
2,048 cases. The independent predicate is MAME's nonzero foreground combined
with background mask 7 or 4. Its 308 enabled hits verify first-hit coordinate
retention, read-clear and recapture. The test also checks SSR LOAD sampling,
held D2 data, BIRQEA clear, and both limit NANDs.

`make -C sim socket-15j-cpu` connects the actual 12J model and collision chips
to the actual TV80 CPU-board interface. Q5 high produces CPU IRQ and status,
correct X/Y reads and pending clear. The Q5-low negative control suppresses
IRQ/status while coordinates continue capturing. The synthetic CPU program
deliberately enables BIRQEA; it does not represent Victory's gameplay behavior.

Both tests pass. The separate background-chip regression also passes 1,024
VP/mask/enable/timing cases, pause and read-clear races, and 400 pending holds.
The existing CPU-interface regression passes changing WAIT-extended reads and
aliases. These tests establish functional consequences of the candidate inputs
without establishing their factory electrical levels.

An unmodified cold boot with candidate Q5 high also passes the processor
interrupt diagnostic at SYS clock 568,564,152, the same checkpoint as the
accepted Q5-low baseline. Through that checkpoint the passive trace counts
zero BIRQEA enables, zero limit-control enables and zero background pending
edges. This run intentionally stops after diagnostic 4; it is not a new
all-eight-stage or gameplay acceptance run. Its terminal record is
`simulation/socket_15j_cold_run.log`.

The CPU fixture's `+GAME_HANDLER` case copies B09D-B146 unchanged from the
checksum-verified original ROM into a synthetic startup harness. With Q5 high
and BIRQEA deliberately enabled, the real TV80 executes that handler, reads
and clears background pending, saves corrected X/Y=40,25 in E00A/E00B and
returns to HALT. No handler instruction is patched. The harness supplies the
startup code, IM1 vector, stack and controlled collision, so this is original
routine acceptance, not evidence that ordinary gameplay reaches the branch.

All eight receiver combinations in both orientations also pass through the
whole native HSC with native master cadence, nonzero scroll, independent
serializer/palette/pixel checks, live CPU Y reads and coordinated pause. The
16 verified cases check 3,440,424 pixels/packets and 49,709,520 settled collision
comparisons. Limit bits are disabled in these native image cases; the focused
receiver test separately exercises enabled limit gates. The explicit argv
runner `tools/test_15j_candidates.py` checks that each requested level and
orientation actually appears in the test result. Its report supersedes the
earlier shell-loop sweep, whose orientation arguments were not applied.

Two attempted original-ROM fast-start gameplay comparisons (Q5 low and high)
both stop at the same audio diagnostic: result FF, F=AC, PC=05C5, clock
359,736,900. Neither run is accepted as gameplay coverage; neither failure
selects a receiver hypothesis. No assertion was weakened or diagnostic failure
acknowledged to continue. This failed test route is recorded separately from
the existing accepted full cold-start/cabinet run.

One schematic/MAME distinction remains deliberate: BIRQEA clears 12J's EBIRQ
enable but does not clear an already stored 13H pending bit. Y-read clears
that pending bit. MAME instead gates the CPU interrupt directly with the
current enable bit. The focused receiver test checks this pending/enable
independence; matching MAME's overlap predicate is not a claim of identical
interrupt timing or acknowledgement behavior.

## Headless MAME gameplay comparison

Local MAME 0.288, Victory 3.0, ran 120 emulated seconds from separate cold NVRAM
with `sim/compare_15j.lua`. Startup checks were observed passively. Only the
expected cold CMOS notice was acknowledged. After attract entry, the script
injected repeated coin/start, fire/thrust and dial inputs through the cabinet
ports. The saved frame visibly shows Player 1 gameplay. No ROM or RAM was
patched. This is runtime evidence from MAME 0.288, distinct from the pinned
source comparison.

| Observed event | Count |
| --- | ---: |
| Emulated frames | 7,200 |
| Attract entry | Frame 2,672 |
| C10A control writes | 48 |
| Writes enabling BIRQEA | 0 |
| Writes enabling horizontal/vertical limit controls | 0 |
| Reads of status with background pending | 92,103 |
| Background-handler opcode visits at B12F | 2,709 |
| Background-coordinate consumer visits at A963 | 0 |

Records: `simulation/mame_15j_final/run.log` and
`simulation/mame_15j_final/snap/victory/0000.png`. The earlier 120-second run
produced the same control/status/handler counts; the final run also checks the
coordinate consumer and retains the gameplay image.

MAME's timer sets background pending regardless of BIRQEA. Bit 5 gates only
the CPU IRQ contribution; a frame or foreground interrupt can consequently
enter the shared handler and collect background status/coordinates anyway.
Thus zero enable writes do not imply zero background-handler execution in
MAME. The schematic model samples EBIRQ into the pending latch and does not
set pending under BIRQEA clear. This difference cannot be repaired by choosing
another constant at the empty socket. There is no evidence here for bypassing
12J, changing the BIRQEA connection, or replacing its behavior with MAME's.

The bounded gameplay evidence supports an unused dedicated background IRQ and
unused limit-control features in the tested Victory 3.0 paths. It does not
prove every game situation or another ROM revision behaves that way. The
absent ROM may belong to optional HSC features unused by Victory; that is a
plausible explanation, not verified factory design history.

## Decision

Keep the existing provisional low receiver inputs in production. All eight
candidate combinations have valid, tested circuit behavior, but neither the
stock diagnostic nor the tested game control writes discriminate between the
actual factory levels. Do not label zero, high, or a fabricated ROM image as
measured board behavior. The collision path itself is modeled and tested,
including unchanged original handler execution when deliberately enabled.

Software/circuit investigation is complete to the scope above. Physical
receiver bias, straps and any as-built departure from the schematic remain
unresolved. Board measurements are the remaining way to select a factory
electrical model. Production RTL and the delivered RBF are unchanged by this
investigation; no Quartus build was performed.

The accepted logs, gameplay image, fixture sources and source/executable
hashes are preserved in the local bounded investigation archive. The
`simulation/`, `sim/` and audit-tool paths cited above identify development
evidence, not files included in this source package. Only the audio
coefficient reproduction tools are distributed.
