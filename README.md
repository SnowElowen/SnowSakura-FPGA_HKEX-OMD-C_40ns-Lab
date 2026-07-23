# SnowSakura-FPGA

## Deterministic Physical-Layer FPGA Architecture for HKEX OMD-C on ZU15EG / VU9P

SnowSakura-FPGA is a physical-layer FPGA project for HKEX OMD-C market-data ingestion, deterministic receive normalization, fixed-slice parsing, arbitration, and latency-controlled TX release on Xilinx UltraScale+ devices.

The repository records both the active ZU15EG hardware-delivery path and the lower-latency research path. Claims are separated by evidence level: functional simulation, post-route timing, SDF timing simulation, and real hardware measurements are not treated as interchangeable.

| Item | Current value |
|---|---|
| Primary device | Xilinx Zynq UltraScale+ `XCZU15EG-FFVB1156-2-I` |
| Secondary research device | Virtex UltraScale+ VU9P |
| Serial line rate | 10.3125 Gb/s |
| Fabric timing target | 322.56 MHz over-constraint / 322.265625 MHz standard operating point |
| Active transceiver path | GTH Raw Mode / RX Buffer ON / TX Buffer Bypass |
| Active hardware state | Golden Raw32 optical lab path and continuous multi-packet fixed-Message-0 parser completed |
| Active engineering stage | Order State Delta Core |
| Research transceiver path | GTH Raw Mode / RX-TX Buffer Bypass |
| Research latency target | 40 ns-class, subject to hardware proof |

> **Current state:** the real SFP2-to-SFP1 GTH/optical path, PRBS31 closure, Eye Scan, Raw32 alignment, registered packet capture, and continuous multi-packet fixed-Message-0 parsing are complete and frozen. Active engineering has moved to the Order State Delta Core.

---

## Contents
- [Current Hardware Status](#current-hardware-status--2026-07-23)
- [Current Progress](CURRENT_PROGRESS.md)
- [Immediate Hardware Checklist](#immediate-hardware-checklist)
- [HKEX OMD-C Exchange Feed Simulator](#hkex-omd-c-exchange-feed-simulator)
- [Architecture Tracks](#architecture-tracks)
- [Fast-Path Engineering Rules](#fast-path-engineering-rules)
- [Verification Contract](#verification-contract)
- [Historical Engineering Log](#historical-engineering-log)
- [Public / Private Boundary](#public--private-boundary)
- [Collaboration](#collaboration)

---

## Current Hardware Status — 2026-07-23 — COMPLETED

SnowSakura has completed and frozen the **golden single-direction laboratory foundation** on the real Puzhi ZU15EG optical path. The proven physical direction is SFP2 / GT X0Y6 TX → 10G-SR optics → OM4 → SFP1 / GT X0Y7 RX, with fabric-owned Raw32 data above the closed GTH substrate.

The completed base covers deterministic lab-frame generation, stable marker/alignment lock, continuous registered packet capture, and fixed Message 0 parsing across repeated OMD-C packet forms. The hardware repeatedly asserts `parsed_valid`, holds `parsed_error = 0`, and reconstructs the programmed Add/Modify Order fields in the RX user-clock domain. This is real optical-path hardware closure, not a simulation-only milestone.

### Hardware Eye Scan — receiver sampling margin
![pack](img/parckedata.png)
![IBERT Eye Scan with 77.78 percent open UI](img/2026-07-23_ibert_eye_scan_open_ui_77_78.png)

The In-System IBERT scan is a real GT receiver measurement on the active optical path. The completed contour reports:

| Metric | Measured result |
|---|---:|
| Open area | 7680 |
| Open UI | 77.78% |
| Horizontal scan range | -0.500 UI to +0.500 UI |
| Vertical scan range | 100% |
| Horizontal / vertical increment | 8 / 8 |

This closes the earlier non-responsive/fake-plot Eye Scan fault domain. It is receiver sampling-margin evidence for this configuration; it is not substituted for a long-duration BER run.

### Hardware packet capture and field reconstruction

![Locked 12-word capture with OMD-C parser fields](img/2026-07-23_rx_capture_parser_fields.png)

The RX-domain ILA records align_locked = 1 while the capture index advances through the fixed packet window. The parser reconstructs MsgType = 16'h001E, OrderId = 64'h1122334455667788, PriceRaw = 32'h00007A12, and Quantity = 32'h000003E8 directly from the received hardware stream.

### Hardware valid-chain closure

![Packet-valid to parsed-valid hardware closure](img/2026-07-23_packet_valid_parsed_valid.png)

The ILA records capture_index = 0...11, followed by a one-cycle packet_valid pulse and then a one-cycle parsed_valid pulse. parsed_error remains Low, align_locked remains High, and the packet counter increments. This is the physical closure of marker/alignment → 12-word capture → fixed Message 0 parser for the current lab vector.

### Continuous multi-packet parser closure

The RX-domain ILA proves continuous operation rather than a single accepted vector:

| Hardware signal | Observed result |
|---|---|
| `align_locked` | continuously `1` |
| `parsed_valid` | repeated one-cycle output pulses |
| `parsed_error` | continuously `0` |
| `PktSize / MsgCount` | `16'h004C / 2`, `16'h0010 / 0`, `16'h0030 / 1` |
| Accepted `MsgType` | `16'h001F` Modify Order and `16'h001E` Add Order |
| `OrderId` | `64'h1122334455667788` |
| `PriceRaw` | `32'h00007A12` |
| `Quantity` | `32'h000003E8` |
| `SendTime` | `64'h1122334455667788` |

`PktSize = 16'h0010` with `MsgCount = 0` is the OMD-C Heartbeat packet form. It contains no message; the held `MsgType` bus is ignored for that packet. The `16'h004C` packet carries two complete test messages and the `16'h0030` packet carries one, proving repeated packet-header reconstruction and registered fixed-Message-0 output across the programmed stream.

### Completed foundation boundary

~~~text
Golden TX / Lab Source
    -> GTH TX / SFP2
    -> 10G-SR optics / OM4
    -> SFP1 / GTH RX
    -> stable Raw32 marker alignment
    -> continuous registered packet capture
    -> repeated OMD-C Packet Header reconstruction
    -> fixed Message 0 Add / Modify parsing
    -> repeated parsed_valid pulses, parsed_error = 0
~~~

The measured BER/BERT sample depth for this frozen build is **10^8 bits**.

The exchange-feed simulator initial version and the single-direction Raw32 normal-data parser integration are completed and frozen as the reusable SnowSakura lab base. Active development starts after this registered parser boundary; the completed GTH, optics, marker, capture, and fixed-parser layers are not reopened.

No production RTL, GT integration recipe, internal status-bit encoding, board-routing detail, XDC/TCL constraint, or calibration script is published by this update.

---

## Immediate Hardware Checklist

Acceptance is intentionally ordered. A later protocol check cannot compensate for an unproven earlier physical boundary.

### Program image and debug identity

- [x] Acquire the ZU15EG board and optical test setup
- [x] Incorporate the active Puzhi board mappings
- [x] Build the reusable GT hardware shell
- [x] Program an exact known bitstream
- [x] Refresh and match the corresponding ILA probe set

### GT initialization and clocks

- [x] Prove the freerun/reset-helper clock is active
- [x] Prove a continuous MGT reference clock at the selected GT boundary
- [x] Prove `gtpowergood`
- [x] Prove QPLL0 lock and reference-clock selection
- [x] Prove TX/RX PMA reset completion
- [x] Prove `tx_reset_done` and `rx_reset_done`
- [x] Prove RX CDR stability
- [x] Observe active TXUSRCLK2 and RXUSRCLK2 domains in hardware
- [ ] Verify generated clock periods with `report_clocks`

### Physical data movement

- [x] Show changing TX words in the intended TX user-clock domain
- [x] Prove the selected SFP/lane/loopback route
- [x] Show changing raw RX words on the intended lane
- [x] Pass the GT-internal PRBS31 checker
- [x] Prove PRBS31 lock in the intended optical RX lane
- [x] Reach the clean quick-qualification state
- [x] Close PRBS selector and checker-reset startup ambiguity
- [x] Select RX polarity from the PRBS checker result

### OMD-C hardware path

- [x] Deliver live RX words to the parser observation boundary
- [x] Transmit the fixed 48-byte OMD-C payload sequence from the fabric feed model
- [x] Prove TX word-index and state progression in hardware
- [x] Prove stable bounded marker/alignment lock with `align_locked = 1`
- [x] Prove registered `capture_index = 0...11` progression
- [x] Prove one-cycle `packet_valid` after the 12-word capture
- [x] Reconstruct Little-Endian `MsgType` as `16'h001E`
- [x] Assert one-cycle `parsed_valid` with `parsed_error = 0`
- [x] Reconstruct the programmed Add Order fields in hardware
- [x] Prove continuous `PktSize / MsgCount` rotation across two-message, Heartbeat, and one-message packet forms
- [x] Prove repeated fixed-Message-0 outputs for `MsgType = 16'h001F` and `16'h001E`

### Evidence and measurement

- [x] Post-route STA for the active RX Buffer ON exchange-feed build
- [x] Real-hardware Eye Scan capture and interpretation: open area 7680, open UI 77.78%
- [x] Current BER/BERT sample-depth exercise: 10^8 bits
- [x] Continuous hardware valid-chain proof: alignment → capture → packet valid → parsed valid
- [ ] Post-implementation SDF timing simulation
- [ ] Final long-duration BER qualification
- [ ] Measured Version 2 wire-to-wire latency report
- [ ] Version 1 RX Buffer Bypass re-validation
- [ ] Dual-line A/B arbitration validation

---

## HKEX OMD-C Exchange Feed Simulator

The custom exchange feed simulator is a deterministic FPGA-side hardware test source. It is not a software packet replay and does not claim to recreate the complete HKEX exchange network.

Its purpose is narrower and physically testable: generate known OMD-C bytes, send them through the real GTH TX/SFP path, receive them through the selected GTH RX lane, and expose each boundary before parser output is accepted.

### Hardware chain

```text
omdc_packet_rom
    -> tx_feed_fsm
    -> GTH TX / SFP
    -> optical or board loopback
    -> GTH RX Buffer ON
    -> RX capture / pattern checker
    -> fixed-slice OMD-C parser
```

| Block | Physical role | Required evidence |
|---|---|---|
| `omdc_packet_rom` | Stores deterministic OMD-C test bytes | Byte-for-byte reference vector |
| `tx_feed_fsm` | Releases ROM words in the TX user-clock domain | Word index, start, completion |
| GTH TX / SFP | Sends the real 10.3125 Gb/s serial stream with TX Buffer Bypass | Reset status, TX clock, TX activity |
| Loopback path | Returns the stream to the selected RX lane | Proven port and lane mapping |
| GTH RX Buffer ON | Provides the active stable receive baseline | RX reset done, CDR state, RX clock |
| RX capture/checker | Registers RX words and checks movement before parsing | Raw activity, match flag, mismatch count |
| Fixed-slice parser | Extracts protocol fields after boundary proof | Payload progression and parsed fields |

### Level-1 deterministic payload

The first protocol vector is deliberately fixed and small:

| Region | Size | Purpose |
|---|---:|---|
| OMD-C Packet Header | 16 bytes | `PktSize`, `MsgCount`, `SeqNum`, `SendTime` |
| Add Order | 32 bytes | FullTick Add Order with `MsgType = 30` |
| Total payload | 48 bytes | One packet containing one complete message |

OMD-C integer fields are Little-Endian. `MsgType = 30` appears on the byte stream as `1E 00`; the parser must reconstruct it as `16'h001E`.

### Staged test plan

1. **Level 0 — GT link and training pattern: completed**  
   Clocks, resets, QPLL/CDR state, selected optical direction, GT-internal PRBS31 lock, checker startup, and RX polarity are closed for the frozen base.

2. **Level 1 — Fixed 48-byte OMD-C payload: completed**  
   Fabric TX progression, stable marker alignment, 12 × 32-bit capture, packet completion, `MsgType = 16'h001E`, Add Order field reconstruction, and the packet-valid-to-parser-valid chain are proven in hardware.

3. **Level 2 — production 10GBASE-R normalization: separate later stage**  
   Ethernet PCS/framing, IPv4/UDP normalization, and a Registered OMD-C Normalized Window are not inserted into this custom Raw32 laboratory source. They begin only when the project switches to a standards-coded external feed.

4. **Measurement status**  
   Routed timing and the real-hardware Eye Scan are complete. The current BER/BERT depth is 10^8 bits; SDF, final long-duration BER, and measured board latency remain later sign-off items.

---

## Architecture Tracks

### Version 2 — Stable Hardware Delivery Baseline

Version 2 is the current implementation path for the first reproducible ZU15EG hardware deliverable.

| Stage | Physical contract | Evidence target |
|---|---|---|
| GTH RX Buffer ON | Use the RX elastic buffer during stable board bring-up | `rx_reset_done`, CDR stability, clean RX capture |
| GTH Raw Mode | Keep ownership close to the transceiver instead of a vendor MAC/AXI datapath | GT configuration and user-clock reports |
| TX Buffer Bypass | Keep the TX latency source controlled | TX reset done, TX activity, loopback |
| Buffered RX capture | Capture stable GT output into FDREs in RXUSRCLK2 | Post-route timing and SDF simulation |
| Pattern checker | Prove data movement before protocol claims | Sticky match and mismatch counters |
| Fixed OMD-C ROM | Provide deterministic hardware traffic | Repeatable byte sequence |
| Fixed-slice parser | Extract only fixed-position fields | No runtime barrel shifter; routed timing proof |
| Latency measurement | Include GT and buffer latency explicitly | Measured sub-60 ns target |

RX Buffer latency is treated as configuration-dependent. It will be reported from the actual GT Wizard configuration and hardware measurement rather than assumed as a marketing constant.

### Version 1 — Deterministic Low-Latency Research Blade

Version 1 preserves the original RX/TX Buffer Bypass direction as a 40 ns-class research target.

| Stage | Budget | Physical meaning |
|---|---:|---|
| RX normalization | 3 cycles | Alignment-owned valid/data handoff into a fixed parser interface |
| Parser extraction | 1 cycle | Fixed-offset field extraction without a runtime barrel shifter |
| Arbitration | 2 cycles | Dual-path-ready control with recovery separated from physical alignment |
| TX release | 1 cycle | Pre-registered template/control release |
| PMA model | approximately 18 ns | Explicit transceiver contribution under the bypass model |

At 322.56 MHz, one fabric cycle is approximately 3.1004 ns. Seven listed fabric cycles are approximately 21.70 ns before the PMA model. This is why Version 1 is publicly described as a **40 ns-class research target**, not as completed board-level latency proof.

Version 1 requires phase-related clock proof, manual alignment, buffer-bypass done/error validation, post-route STA, timing simulation, BER evidence, and measured hardware latency before it becomes a deliverable claim.

---

## Fast-Path Engineering Rules

1. **No runtime barrel shifter in the steady-state RX path.**  
   A dynamic part-select maps to a mux network, not a metal wire.

2. **No wide alignment scanner in the accepted steady-state path.**  
   A scanner may assist bring-up, but the locked parser interface must be fixed.

3. **No Async FIFO in the latency-critical path.**  
   The final path must be same-domain or demonstrably phase-related. Buffering used by Version 2 must be counted explicitly.

4. **Triple-FF applies only to single-bit asynchronous controls or status.**  
   Triple-FF does not make a changing multi-bit payload coherent. Payload must remain in one domain, use a proven phase relationship, or cross through an explicitly designed coherency mechanism outside the critical path.

5. **GTH RX Data Path combinational depth is limited to two LUT levels.**  
   The limit is accepted only when confirmed after implementation.

6. **No uncontrolled fanout.**  
   Parser valid, arbitration select, packet valid, and TX release controls must be localized or replicated when routed fanout threatens the 3.1004 ns period.

7. **No hidden latency source.**  
   Vendor MAC, AXI, FIFO, PCS buffering, and GT buffering must be named and counted when present.

8. **No parser debugging before the RX stream is proven.**  
   Constant or invalid GT output is a clock/reset/link problem until raw RX movement is demonstrated.

9. **No latency claim from functional simulation alone.**  
   Timing and board behavior require routed and physical evidence.

---

## Verification Contract

| Evidence | What it proves | What it does not prove |
|---|---|---|
| RTL simulation | Functional state and field-extraction behavior | Routed delay, GT behavior, BER |
| Stress test | Behavior under the modeled jitter/phase assumptions | Real PMA/CDR/board behavior |
| Post-route STA | Setup/hold timing for constrained implemented paths | Packet correctness or analog link quality |
| SDF timing simulation | Netlist behavior with annotated routed delays | Real optical channel BER |
| `report_clocks` | Actual generated clock objects and relationships | Data correctness by itself |
| ILA capture | Internal hardware state at sampled boundaries | Unsampled analog eye quality |
| Eye Scan | Receiver sampling margin under the tested setup | Long-duration error rate by itself |
| BER run | Error statistics over the measured bit count | Untested environmental conditions |
| Latency measurement | Actual boundary-to-boundary delay for the measured configuration | A different GT/buffer configuration |

Required implementation review includes WNS, WHS, failing endpoints, logic levels, route delay, high-fanout nets, clock interaction, exceptions, SDF timing, and the exact endpoints covered by each constraint.

---

## Historical Engineering Log

Earlier figures and metrics are preserved as development evidence. They describe the build in which they were captured; they are not automatically proof of the current RX Buffer ON hardware configuration.

### 2026-03-18 — Initial ZU15EG Physical Timing Work

#### Datapath routing and net-delay suppression

![data](img/s1_routing.jpg)

Representative paths pushed logic delay below approximately 1 ns, while net delay near 1.5 ns became the dominant problem. The physical lesson was that simple RTL still fails when placement creates long routes through switch matrices and interconnect tiles.

#### Floorplanning and initial timing closure

![Data_Path_Logic](img/s2_floorplan.jpg)

- WNS: +0.708 ns
- WHS: +0.024 ns
- Failing endpoints: 0

#### Full pipeline squeeze at 322 MHz class

![Timing_Summary](img/s3_timing.jpg)

![Clock_Tree](img/4ltigoriena_sim1.png)

- WNS: +0.472 ns
- WHS: +0.030 ns
- Failing endpoints: 0 across 542 endpoints

This phase established that clock trees, register placement, routing detours, and fanout must be reviewed together.

### 2026-04-29 — RX / Parser / TX Single-Channel Validation

![Physical_Mapping](img/enasim4x2_.png)

The waveform work examined deterministic cycle behavior from Start-of-Packet detection into parser output signaling under the tested Raw Mode assumptions.

![Manual_Routing](img/朽木冬子_5.png)

The synthesis schematic was used to inspect FDRE ownership, LUT depth, routing locality, and whether debug outputs distorted the fast path. A schematic shows topology; routed timing and hardware measurement are still required for latency proof.

Reported results from the tested implementation:

- WNS: +0.472 ns
- WHS: +0.030 ns
- Failing endpoints: 0 across 542 endpoints

### VU9P Matrix Scaling and SLR Isolation

Representative reported metrics:

- WNS: +2.011 ns
- WHS: +0.159 ns
- Net Delay: 0.760 ns
- Logic Delay: 0.217 ns

![Output_Waveform](img/tkyou_6.png)

![rooting](img/shio_7.png)

The scaling study exposed SLR distance and control fanout as physical routing costs. Critical fanout above approximately 12 became a review trigger, with register replication preferred over a global control driving a wide mux field.

#### Placement and routing evidence

![new_art](img/utou_8.png)

![new_art](img/yuki_9.png)

These images remain useful placement records, but a clean Device View is not independent timing proof.

#### Simulation snapshots

![SIM](img/10sim2_1.png)

![SIM](img/11sim2_2.png)

Simulation exposed functional and pipeline behavior. Later work tightened the distinction between parser success and GTH/CDC/board proof.

### 2026-05-15 — First Public Simulation Release

![Overview](img/over1.png)

![Python_Sim_1](img/pythonsim2.png)

![Python_Sim_2](img/pythonsim2_2.png)

The project moved from isolated timing experiments toward a broader IEEE 802.3 / OMD-C simulation framework. Historical packet capture increased from approximately 10% to 71.3%, exposing parser-state and validity failures that required further correction.

Frank Bruno's high-speed serial-interface material was an important external influence during this stage.

#### 9,974 / 10,202 stress-test milestone

![Vivado_Sim_1](img/12sim3_.png)

The public stress test reached 9,974 of 10,202 captures, approximately 97.8%, under the simulation assumptions at that time. It explored ppm offset, ps-scale jitter, sub-ns phase perturbations, and raw-data ingestion.

![Vivado_Sim_2](img/13sim3_2.png)

![Vivado_Sim_3](img/14sim3_3.png)

```text
/sim/tb_omdc_top.v : physical-layer-oriented testbench
/sim/raw_data.hex  : HKEX OMD-C raw stream test dataset
```

#### Routing geometry studies

![Vivado_routing1](img/routing1.png)

![Vivado_routing2](img/routing2.png)

Short Manhattan distance and fewer switchbox hops can reduce route delay, but visual route shape must be tied to implemented timing reports.

### 2026-05-18 — 10,000 / 10,000 Simulation Milestone

![tcl](img/tclover2.png)

The first major simulation target reached 10,000 of 10,000 packet ingestions without adding a pipeline cycle to that simulation architecture.

The correction that remains active today is important: a selected path reporting one or zero logic levels is not full-system proof. Endpoint coverage, route delay, fanout, setup/hold, clocks, and hardware behavior still matter.

Reported metrics from that tested implementation included:

- WNS: +0.593 ns on selected critical control paths
- Total Logic Delay: approximately 0.176 ns on selected paths

![device](img/device1.png)

![pysim3](img/pysim3.png)

### 2026-06-24 — Deterministic Research Architecture

The research architecture converged on explicit RX normalization, fixed-slice parsing, bounded arbitration, TX release, and an explicitly counted PMA model. The verification environment also became stricter about RX ownership, legal bit windows, multi-clock behavior, and post-implementation timing.

The architectural lessons retained from this phase are:

- OMD-C packet ordering is not Ethernet bit/block alignment.
- Dynamic offsets create mux networks and are not fixed metal routes.
- A multi-bit CDC bus cannot be repaired with independent synchronizers.
- A fixed-cycle pipeline must be stated in cycles and ns.
- Physical constraints are part of the design and missing objects must fail loudly.

### 2026-07-03 — Real Hardware Phase

![FPGA](img/FPGA.jpg)

The ZU15EG board and 10G optical test setup moved SnowSakura from architecture and simulation work into real GTH/SFP validation.

The hardware program covers board bring-up, Raw Mode, RX Buffer ON, TX Buffer Bypass, clocks and resets, pattern checking, deterministic OMD-C ROM traffic, post-route STA, timing simulation, Eye Scan, BER, and measured latency.

### 2026-07-07 — RX Buffer ON Delivery Baseline

Extended bring-up exposed the sensitivity of RX Buffer Bypass to RXUSRCLK2/RXPROGDIVCLK construction, reset sequencing, phase alignment, bypass status, and debug observability.

The repository was therefore split into two tracks:

- Version 2 proves stable real-hardware packet movement and measured latency with RX Buffer ON.
- Version 1 preserves RX Buffer Bypass for the 40 ns-class deterministic research path after the baseline is established.

### 2026-07-13 — From `0x1F` Initialization to Live Optical RX Data

The day began with reference-clock validation and a corrected GT integration moving the live board beyond the earlier reset-boundary condition. The routed design generated a fresh bitstream, and the dedicated bring-up status first reached `16'h001F` in ILA.

![Earlier 0x1F initialization boundary](img/0x1f_ila.png)

Later hardware captures crossed that boundary: TX became active through the selected optical loopback, RX produced changing 32-bit fabric words, and the PRBS/training observer advanced. The parser observation boundary is now driven by live hardware traffic rather than a frozen status value.

This closes the physical-link/no-data fault domain for the current bring-up image. The next public milestone is deterministic frame and protocol acceptance: stable training lock, fixed 48-byte OMD-C transfer, Little-Endian `MsgType = 16'h001E`, followed by BER and measured latency evidence.

The public evidence records the state transition and acceptance order only; source RTL, integration scripts, status-bus encoding, calibration logic, and physical placement details remain private.

### 2026-07-14 — GTH Physical Layer Closed with Internal PRBS31 BERT

The final bring-up day converted the July 13 live-data milestone into a protocol-independent serial-link proof. GT-internal PRBS31 was enabled across the real SFP2-to-SFP1 optical route so that fabric word boundaries, training markers, packet capture, parser state, and OMD-C formatting could no longer contaminate the diagnosis.

The remaining variables were removed in a controlled order: the known-good MGT reference and QPLL0 route were preserved, RX polarity was tested by checker outcome, PRBS selection was applied without lane-slice ambiguity, and the RX checker received an explicit post-reset counter-reset session. The receive side then reached CDR lock, PRBS lock, and the clean quick-qualification state recorded in the final ILA capture.

This closes the GTH bring-up phase for the active RX Buffer ON / TX Buffer Bypass baseline. SnowSakura now moves from transceiver diagnosis to deterministic OMD-C framing and fixed-slice parser acceptance.

### 2026-07-16 — Fabric TX/RX Exchange-Feed Milestone

The project returned from the frozen PRBS diagnostic image to normal fabric-owned data. Hardware ILA captures showed deterministic TX word/state progression, live Raw32 RX activity across the proven SFP2-to-SFP1 optical path, and an implemented timing summary with WNS `+0.452 ns`, WHS `+0.013 ns`, and zero failing endpoints.

At that historical checkpoint marker/frame acceptance had not asserted and the parsed OMD-C fields remained zero. The failure was isolated above the frozen GTH substrate and was subsequently closed by the July 23 laboratory-base build.

### 2026-07-23 — Golden Raw32 OMD-C Laboratory Foundation and Continuous Parser Completed

The completed build proves stable `align_locked = 1`, deterministic packet capture, repeated one-cycle `parsed_valid` pulses, and `parsed_error = 0` across a continuous programmed stream. Hardware rotates through `PktSize / MsgCount = 16'h004C / 2`, `16'h0010 / 0`, and `16'h0030 / 1`; the fixed Message 0 parser outputs `MsgType = 16'h001F` and `16'h001E` while preserving `OrderId = 64'h1122334455667788`, `PriceRaw = 32'h00007A12`, and `Quantity = 32'h000003E8`.

A real In-System IBERT Eye Scan on the same active direction reports open area 7680 and open UI 77.78%, closing the earlier Eye Scan execution fault domain. The current BER/BERT test depth is 10^8 bits and is intentionally recorded as a pre-final measurement depth, while long-duration BER, SDF, wire-to-wire latency, production 10GBASE-R normalization, and dual-line arbitration remain separate later stages.

This completes and freezes the exchange-feed simulator initial version plus the real optical Raw32 alignment/capture/continuous fixed-parser integration as the reusable SnowSakura laboratory foundation. The active engineering stage is now the Order State Delta Core.

### Built From Almost Nothing

SnowSakura was not built inside a university laboratory, research group, or company hardware team. Its starting environment was one laptop, one desk lamp, one pen, public documentation, repeated engineering iteration, and one GPT.

![lab](img/mylab.jpeg)

The repository records the learning process from RTL and simulation through FDRE/LUT mapping, physical routing, GTH configuration, CDC boundaries, timing closure, and real hardware bring-up.

---

## Public / Private Boundary

### Public repository

- architecture and development notes
- selected simulation and timing evidence
- hardware-test direction and acceptance criteria
- reproducible stress-test material
- selected board-level measurements as they become available

### Private lab

- Raw Mode production RTL
- exact GT Wizard integration and reset dependency
- internal debug-bus bit assignments and training/checker implementation
- exact XDC/TCL placement strategy
- Pblock coordinates and LOC/BEL assignments
- phase/alignment calibration scripts
- proprietary implementation constraints

The public repository documents the engineering direction and evidence chain. Exact physical implementation scripts remain private.

---

## Collaboration

Technical challenge, adversarial architecture review, and collaboration around FPGA market-data infrastructure, deterministic latency, GTH bring-up, and nanosecond-scale timing closure are welcome.

**Email:** `ruansheng333@gmail.com`

SnowSakura is an independent physical-layer engineering record built through direct iteration, routed timing evidence, and continuing hardware validation.
