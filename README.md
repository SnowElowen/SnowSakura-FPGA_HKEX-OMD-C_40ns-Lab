# SnowSakura: Physical Layer Implementation Specs for 15EG  VU9P
## Target: 22nsLogicLatency（MAC+Parser）+18nsPMALATENCY Deterministic for HKEX-OMD-C 

## 2026 2.10

---

###  The Logic Arena
The pursuit of deterministic latency is a lonely road. I am currently **bored** and seeking intellectual **adversaries** or collaborators. Whether you want to **challenge my routing strategy**, discuss **nanosecond-scale bottlenecks**, or require **strategic consultation** for HFT infrastructure:

- **Email:** `ruansheng333@gmail.com`
- **Status:** Open for deep-dive technical "chess" and advisory.

### Physical Layer Design Philosophy

* **Determinism over Abstraction**: In the realm of 31.5ns latency, standard software stacks are nothing but propagation noise.
* **Hardware Sovereignty**: We bypass OS kernels, PCIe overhead, and standard IP blocks. Logic is mapped directly to the **GTH Transceiver** and dedicated **LUT** resources via manual routing.
* **Timing is Law**: Every clock cycle at 322.26MHz counts. If your logic takes more than 10 cycles, you've already lost the trade.

---
*(Detailed XDC constraints are kept in internal private labs due to proprietary physical optimization logic.)*
# HKEX-OMD-C 31.5ns Parser: Physical Layer Implementation Log
**Target Device**: Xilinx Zynq UltraScale+ XCZU15EG (FFVB1156)
**Operating Frequency**: 322.265625 MHz (GTH Raw Mode, Bypassing PCS)

---

## The Physical Truth of Zero-Jitter Trading

In HFT, software architecture is an illusion; only **Physical Layer Logic** dictates the outcome. The following logs document the three-stage manual routing and timing closure process for a 31.5ns OMDC parser. 

Relying on Vivado's Auto-Router for OMD-C parsing is a death sentence. To squeeze latency down to 31.5ns, every **LUT**, every **Register**, and every **Routing path** must be manually constrained via precise XDC definitions.

## 2026-03-18 
Initial ZU15EG physical timing log: Stage 1 routing, Stage 2 floorplanning, Stage 3 full pipeline squeeze

### Stage 1: Datapath Routing & Net Delay Suppression

![data](img/s1_routing.jpg)


The raw battle between **Logic Delay** and **Net Delay**. When operating in the `gt_txusrclk2` domain at 322MHz, the propagation delay across the silicon is your biggest enemy.
* **Observation**: We manually forced the **Net Delay** to converge around 1.5ns - 1.6ns, keeping the **Logic Delay** strictly under 1ns (e.g., 0.973ns). 
* **Logic**: If you let the GUI decide your Placement, your Net Delay will spike, and your 31.5ns target will be shattered by routing congestion.

### Stage 2: Floorplanning & Initial Timing Closure
![Data_Path_Logic](img/s2_floorplan.jpg)
Initial logic mapping and physical isolation. 
* **Timing Met**: **WNS (Worst Negative Slack)** secured at **0.708 ns**. **WHS (Worst Hold Slack)** tightly locked at **0.024 ns**.
* **Logic**: The logic cells (CLEM) are tightly packed to minimize interconnect latency. This is not arbitrary; this is the result of strict **Pblock** constraints. Zero failing endpoints mean the Triple-FF synchronization logic is physically solid.

### Stage 3: Full Pipeline Squeeze @ 322MHz

![Timing_Summary](img/s3_timing.jpg)

![Clock_Tree](img/4ltigoriena_sim1.png)

As the parsing logic scales, the timing window shrinks to its absolute physical limit.
* **Timing Met**: **WNS** squeezed to **0.472 ns**, **WHS** at **0.030 ns**. 
* **Logic**: 0 Failing Endpoints across 542 endpoints. This proves the deterministic stability of the manual routing pipeline. We are pushing the Ultrascale+ architecture to its extreme edge without violating setup/hold times. 

---

### Proprietary Disclaimer
**Do not ask for the XDC scripts.** The exact coordinates, `set_property LOC/BEL` mappings, and Phase Interpolator calibration values are proprietary and isolated in private labs. What you see here is the physical result; the manual routing logic behind it remains classified.
### Phase 3 - Extreme RX-Parser-TX (Single Channel) Summary

*Oops, sorry guys, I simply forgot to include these waveforms and schematics in yesterday's push. Here's the final validation of the deterministic single-channel pipeline before we scale up to the dual-path arbiter architecture.*

#### I. Latency Validation: Waveform Snapshot
We are running `GTH Raw Mode` on the Ultrascale+ architecture, stripping away all non-essential protocol overhead (e.g., standard 802.3 buffers, PCS alignment primitives) for direct hardware parallel data access. 
![Physical_Mapping](img/enasim4x2_.png)

## 2026-04-29 
Phase 3 RX-Parser-TX single-channel validation and manual routing schematic update

* **Highlight:** The cursor measurements demonstrate deterministic, extreme low-cycle latency from Start-of-Packet (SoP) detection directly to the Parser Output pulse. 

#### II. Implementation Details: Synthesis Schematic
This isn't generic RTL synthesis; this is **direct physical mapping**. We are manually configuring registers (`mock_gth_data_reg`) and logic gates to absolutely minimize interconnect routing delay at the silicon level.
![Manual_Routing](img/朽木冬子_5.png)



* **Clock Tree:** `IBUFDS_GTE4` -> `BUFG_GT_SYNC`. Direct-driven reference clock path ensuring zero-latency clock enables across the 16nm die matrix.
* **Matrix Mapping:** Direct-mapped parallel registers to output pins with aggressive LUT-1 combinational bypass elements. We do not waste clock cycles waiting to propagate simple data mappings.

#### III. Static Timing Report Summary
As the parsing logic scales, the timing window shrinks to its absolute physical limit. The final synthesis proves deterministic stability under extreme constraint conditions.

* **Timing Constraints**: **Met**
* **Failing Endpoints**: **0** (Across all 542 endpoints)
* **Worst Negative Slack (WNS)**: **0.472 ns** (Setup)
* **Worst Hold Slack (WHS)**: **0.030 ns** (Hold)

> **Proprietary Disclaimer:** > **Do not ask for the XDC constraint scripts.** The exact `set_property LOC/BEL` coordinate mappings and Phase Interpolator calibration values are proprietary and isolated. What you see here is the physical result; the manual routing logic behind it remains classified.
### Stage NEW: VU9P Matrix Scaling & SLR Isolation

Scaling the core engine to the **Virtex UltraScale+ VU9P** architecture. In this 16nm multi-die matrix, the physical dimension of the silicon becomes the primary latency bottleneck.

* **Timing Met**: **WNS (Worst Negative Slack)** secured at **2.011 ns**. **WHS (Worst Hold Slack)** locked at **0.159 ns**.
* **Logic Analysis**: The baseline **Five-FF Stage** demonstrates deterministic stability at **322.56 MHz**. However, the **Net Delay** (0.760 ns) now significantly outweighs the **Logic Delay** (0.217 ns). This proves that interconnect routing, rather than gate switching, is the dominant factor in the **36ns** path.
* **Physical Layer Isolation**: We implemented strict **Pblock** constraints to anchor the parsing logic within the same **SLR** (Super Logic Region) **SLL (Super Long Line)** cross-SLR penalty, which typically incurs a 1.5 ns - 2.2 ns overhead.

### Stage 2: High-Fanout Congestion Management & Routing Matrix Pressure

![Output_Waveform](img/tkyou_6.png)

As the **OMD-C** parsing tree expands, **High Fanout** nodes (Fanout > 12) begin to strain the **Routing Matrix**. On a high-density device like the **VU9P**, even moderate fanout forces the router to bridge multiple **CLEM** tiles, leading to unpredictable timing skew.

* **Metric**: **0 Failing Endpoints** across initial baseline paths.
* **Fanout Governance**: 
    * Any control signal (e.g., `packet_valid`, `sof_detect`) with a fanout exceeding 12 is flagged for manual **Register Replication**. 
    * We prohibit the EDA tool from "lazy-routing" critical enable signals across the die. Instead, we force physical replicas of the **FF** to reside immediately adjacent to their target **LUT** clusters using `(* MAX_FANOUT = 12 *)` attributes.
* **Strategic Buffer**: Maintaining a **2.011 ns** slack is not just for timing closure; it is a critical buffer for the upcoming **Order Book** parallel search logic. In the **VU9P** environment, **Fanout** is not a mere routing statistic—it is a direct threat to the **Zero Jitter** mandate.
  ### Stage 2: High-Fanout Congestion Management & Routing Matrix Pressure
![rooting](img/shio_7.png)



As the **OMD-C** parsing tree expands, **High-Fanout** nodes (Fanout > 12) exert immense pressure on the **Routing Matrix**. In high-density devices like the **VU9P** or **ZU15EG**, even moderate fanout forces the router to bridge multiple **CLEM** tiles, leading to unpredictable **Timing Skew**.
### True Technical Mastery: Derived from Absolute Control of the Physical Layer, Not Blind Adherence to Architectural Updates

Many believe that newer chips or more complex architectures equate to higher technical skill—this is a pure amateur's delusion. Look at this **Manual Routing** on the **ZU15EG**; this is the ultimate dialogue between **FPGA** logic and the physical world.

#### The Duel Between Logic Levels and Latency:
In the **HFT** arena where every **nanosecond (ns)** counts, automated routing yields results that are merely "good enough to pass." I demand **Logic Level = 0**. The symmetry and direct-path routing shown here push the **Net Delay** to its absolute physical limit.

#### Cross-Architectural Dominance:
I previously stress-tested critical paths with a **Fanout** of 12 on the **VU9P (Virtex UltraScale+)**. Under such high-fanout pressure, standard automated tools inevitably trigger **Timing Violations** due to their inability to balance **Clock Skew** and **Data Path Delay**. Through deep intervention at the **Physical Layer**, I maintained absolute signal synchronization.

#### The Truth of Architecture and Mastery:
Whether it’s **UltraScale+** or the overhyped **Versal**, without a profound understanding of manual constraints, **Manual Placement**, and internal **Switchbox** hops, even the most powerful hardware is just wasting **Clock Cycles**.

**True technical mastery does not reside in new architectures; it originates from total control over the low-level hardware.** While others are still figuring out how to "drag-and-drop" in the **Vitis** GUI, I am already on the silicon’s metal layers, using **TCL scripts** to precisely map the flight path of every single electron.

---

**This demonstrates that true engineering excellence is not derived from chasing the latest architecture, but from absolute mastery over the Physical Layer.** While automated black-box tools struggle with stochastic delays under **Routing Matrix** pressure, only precise control over physical hardware resources ensures dominance in the nanosecond-scale battlefield.

#### The Art on Silicon: A 0.009ns Ultimate Physical Seal
Under the high-frequency heartbeat of **322.26MHz**, I saw through the automated tool's coordinate mapping illusions and successfully locked down the true physical port of entry for the **GTH** (**Clock Region X3Y4**). Through extreme **Pblock** constraints, precise **Register Replication**, and manual routing intervention, the core **U-turn** path of **SnowSakura** has secured epic physical metrics:


#### Absolute Mastery over the Physical Layer
This period of extreme **Physical Layer** squeezing has allowed me to truly achieve absolute control over every metal routing trace and every internal **Switchbox**. The single-path, low-level foundation for handling the **HKEX OMD-C** protocol is now rock-solid.
![new_art](img/utou_8.png)

![new_art](img/yuki_9.png)

#### New Simulation
![SIM](img/10sim2_1.png)
![SIM](img/11sim2_2.png)
###  Technical Specification & Performance Edge

* **Sub-Nanosecond OMD-C Gateway** — This repository hosts a high-performance OMD-C (Optimized Message Data-Cast) hardware parser and framer, engineered for sub-nanosecond precision in High-Frequency Trading (HFT) environments. By utilizing GTH Transceiver PMA/PCS Bypass (Raw Mode), this architecture achieves a deterministic U-turn latency that pushes the physical limits of the 16nm FinFET fabric.
* **Zero-Wait Predictive Barrel Shifter** — Implements a combinatorial 128-to-64 bit sliding window to resolve bit-slip offsets in Raw Mode without adding a single clock cycle of latency.
* **Parallel Preamble Sniffing** — Utilizes a high-speed pattern matching array to detect the SFD (0xD5) across all 8 byte-lanes simultaneously, ensuring immediate frame synchronization.
* **CARRY8-Optimized Parsing** — Hardware-mapped 16-bit magnitude comparators for MsgType and MsgLen validation, achieving logic levels < 4 for maximum timing closure headroom.
* **Deterministic Pipeline** — A strictly enforced 5-FF Stage path (4-cycle RX, 1-cycle TX) ensures zero-jitter response times, critical for competitive market data feedback loops.

###  Hardcore Timing Metrics (Post-Implementation)

* **Worst Negative Slack (WNS): 0.511 ns** — Under the lethal 1.2ns cross-module deadline, I forcefully extracted an absolute margin of half a nanosecond.
* **Logic Level = 0** — The signal launches from **RX** with zero logic gate attrition, driving straight into the **TX** core relying purely on bare **Copper Traces**.
* **Worst Hold Slack (WHS): 0.009 ns** — A mere 9 picoseconds! This means our parsing logic has been relentlessly pinned at absolute zero distance to the physical pins, perfectly illustrating what "flying close to the ground" means in **HFT**.
### Next Use python Test
![SIM](img/pythontest_1.png)

### ### Major Milestone: IEEE 802.3 Framework Refactor & OMD-C Throughput Breakthrough

**Current Status: v0.7-Alpha (Refactored)**
![Overview](img/over1.png)
![Python_Sim_1](img/pythonsim2.png)
![Python_Sim_2](img/pythonsim2_2.png)




* **Architectural Overhaul** – Completely re-engineered the underlying **IEEE 802.3** framework to eliminate vendor-specific IP overhead. By transitioning to a custom high-performance physical layer, the packet capture stability has surged from a baseline of **10%** to a robust **71.3%** (**7,131/10,000** packets) under peak simulation load.
* **Physical Layer Precision** – Achieved stable **HKEX OMD-C v1.45** binary parsing at a line speed of **322.56MHz**. This refactor optimizes the **GTH Raw Mode** data path, ensuring significantly tighter alignment and reduced jitter during high-density bursts.
* **Special Acknowledgments** – I would like to extend my deepest gratitude to **Frank Bruno**. His invaluable insights and technical guidance on high-speed serial interfaces were the catalyst for this breakthrough. Without his mentorship, reaching the **7,000+** packet milestone in this timeframe would not have been possible.

## 2026-05-15 
First simulation release with public tb_omdc_top.v and raw_data.hex stress-test dataset

### ### Next Steps

* **Gate-Level Delta Mapping** – Currently mapping the remaining **28.6%** loss at the gate level.
* **FSM Optimization** – Focused on perfecting the **FSM** state-transition logic within the newly refactored framework to achieve a **Zero-Loss (0%)** production-ready state for the **15EG** platform.

##  Update: Cracking the 9,900+ Barrier & Public Stress Test Release

Following the initial breakthrough, I’ve pushed the **SnowSakura-FPGA** architecture even further. We aren't just talking about functional simulation anymore; we are talking about **Physical Layer Survival**.

I have officially achieved **9,974/10,202** packet captures (97.8% success rate) under extreme physical constraints. To the community and fellow HFT architects: **The Testbench and Raw Data are now public.** If you think your parser can handle the heat of a real-world HKEX line, feel free to clone and run the simulation yourself.

![Vivado_Sim_1](img/12sim3_.png)

###  What’s inside the Stress Test? (Why most parsers will fail)

This isn't your typical "ideal world" simulation. To replicate the brutal environment of the **HKEX OMD-C** feed at a **322.56 MHz** line speed, I’ve injected real-world physical distortions into the `tb_omdc_top.v`:

*   **Clock Skew & 25 PPM Offset**: In reality, the exchange's clock and your local oscillator are never in perfect sync. I’ve introduced a **25 PPM** frequency offset to test if your architecture can handle "clock drift" without a standard Elastic Buffer.
*   **6.0 ps RMS Random Jitter**: We are simulating the **GTH PMA** recovered clock noise. This jitter will ruthlessly attack your **Setup/Hold windows**. If your **Triple-FF** synchronization or **CDC** logic isn't physically constrained (TCL-locked), your FSM will flip.
*   **Sub-nanosecond Phase Shifts**: The data injection is randomized to hit the clock edges at the worst possible moments, testing the absolute limits of metastability recovery.
*   **Raw Mode Data Stream**: Using the provided `raw_data.hex`, the test forces you to deal with raw bitstreams directly from the transceiver, bypassing vendor-specific IP "black boxes" to achieve the **36ns-37ns** latency boundary.

![Vivado_Sim_2](img/13sim3_2.png)

### The Goal: The Final 2.2%

Currently, the **Five-FF** stage architecture handles **97.8%** of the burst under these conditions. The remaining **228 packets** are the final frontier—a battle against the laws of physics at **3.1ns** cycles. 

**Think your FSM can do better?**
1.  Clone the `/sim` folder.
2.  Point the `$readmemh` in `tb_omdc_top.v` to the provided `raw_data.hex`.
3.  Set your simulation timescale to `1ps / 1fs` and run.

If you can hit **100% zero-loss** without adding more than **37ns** of wire-to-wire latency, let’s talk.

![Vivado_Sim_3](img/14sim3_3.png)

###  Repository Structure (Simulation)
- `/sim/tb_omdc_top.v` : The high-precision physical layer testbench.
- `/sim/raw_data.hex` : 100,00lines of OMD-C raw binary stream.
### The "Zero-Detour" ManifestoThe "Zero-Detour" Manifesto
Look at these Metal Layers. 
Most people let the tool 'optimize' their paths, resulting in a messy 'Z' or 'S' shape that introduces uncontrollable Jitter. 
**I don't.**
![Vivado_routing1](img/routing1.png)



This is a Hardened Physical Path crossing multiple Clock Regions with the absolute Minimal Manhattan Distance. 
By manually locking the Interconnect Tiles and Switch Matrices via TCL, 
I’ve eliminated every unnecessary Via and Detour.
![Vivado_routing2](img/routing2.png)


We’re talking about Sub-nanosecond Propagation Delay across the entire Die. 
In the high-speed domain, this level of Skew control is what defines a deterministic system. 
I’m not just writing Verilog; I’m performing Surgery on Silicon.

This isn't a routing result; 
it's a Physical Geometry enforced on the **ZU15EG** fabric. Every Metal Point is exactly where it must be to maintain the 322.56 MHz phase integrity.

## 2026-05-18
100% zero-loss completion and Phase 1 pre-university milestone

BREAKING: 100% Zero-Loss Achieved Under Extreme Physical Layer Distortions

We have officially conquered the final frontier. The remaining 228 packets—previously lost to the brutal laws of physics under raw line-rate stress—have been completely captured. 

By hard-coding a deterministic physical-layer synchronization mechanism and enforcing absolute spatial isolation via floorplanning, the SnowSakura-FPGA engine has achieved **100% zero-loss packet ingestion (10,000/10,000)** across the entire HKEX OMD-C raw binary stream. 

All of this was accomplished without adding a single cycle of pipeline latency, keeping our wire-to-wire budget strictly locked at **36ns**.

![tcl](img/tclover2.png)


### The Simulation Report (Vivado XSim)

Only 1 logic level its snow fpga always
### How the Final 2.2% Was Won (Physical Layer Breakdown)

1. **Eliminating CDC Metastability Without Latency Penalties**
   Instead of falling back on standard, high-latency elastic buffers that ruin the latency budget, the alignment logic was redesigned to exploit the deterministic phase relationships of the **GTH PMA** recovered clock. The tracking state machine now resolves raw word alignment within the sub-nanosecond windows dictated by the **25 PPM frequency offset**.

2. **Strict Combinational Logic Gating (< 2 Levels)**
   The critical path from `gt_rx_data_out[63:0]` to `parsed_msg_valid` was mercilessly flattened. By strictly restricting the asynchronous clock domain crossing to a manual **Triple-FF synchronization** structure with less than two levels of combinational logic, we prevented any multi-bit skew from tearing the data vectors apart.

3. **Vivado TCL-Locked Floorplanning & Timing Closure**
   As shown in the hardware layout, the entire `u_omdc_top` core has been tightly constrained into a dedicated **PBLOCK** right adjacent to the transceiver columns. 
   * **Operating Frequency:** 322.56 MHz (3.1ns clock cycle)
   * **Worst Negative Slack (WNS):** +0.593 ns setup slack remaining on the most critical control paths (`u_rx...sg_valid_reg/C` to `u_tx...state_reg[1]/CE`). 
   * **Total Logic Delay:** Slashed down to a mere **0.176 ns**, ensuring the design easily survives real-world clock distribution jitter.

4.  **I have translated the comments and refactored my testbench; it's ready for testing whenever needed**


![device](img/device1.png)

![pysim3](img/pysim3.png)

##  Phase 1 Complete: Pre-University Milestone Achieved

As of today, all architectural objectives set for my pre-university phase have been flawlessly executed. The single-path parser is officially locked at 100% zero-loss under real-world line distortions.

This will be the final major update before university starts. The repository is now entering a strategic stabilization and deep-refinement phase.

---

##  The Next Frontier: Dual-Path Line A/B Arbitration & Retransmission

The next step is where the architecture faces true hardware-level complexity: handling the HKEX OMD-C Dual-Path (`Line A` and `Line B`) feed over 10G Ethernet. 

In real-world production trading, packets can be dropped or delayed on either line due to network jitter. To achieve absolute resilience, the engine must ingest both paths simultaneously, arbitrate the first-arriving valid packet, and maintain state for gap detection—all without blowing the latency budget.

### The 2-Cycle Challenge
My architectural constraint for Dual-Path Arbitration and Retransmission logic is strictly locked at **2 clock cycles (6.2 ns @ 322.56 MHz)**. 

This is not a simple state machine job. Within these 2 cycles, the RTL must:
1. **Decode & Compare:** Parse the sequence numbers of both paths incoming from the asynchronous CDC boundaries.
2. **Arbitrate:** Route the first-arriving packet to the downstream parser while masking the duplicate packet from the redundant line.
3. **Trigger Retransmission Request (Ouch):** Detect gaps in sequence numbers and immediately flag a retransmission trigger to the TCP/IP recovery module.

Executing multi-bit sequence comparison, dual-path multiplexing, and error-flag generation within a 2-cycle physical budget means there is zero room for heavy combinational logic. Every path must be meticulously balanced across individual registers to prevent **Setup/Hold time** violations.

---
## 2026 6.24



## Final Architecture Update

The final single-channel architecture has now been defined as a fixed-cycle pipeline:

* **3 cycles** for RX normalization
* **1 cycle** for parser extraction
* **2 cycles** for arbitration
* **1 cycle** for TX release
* plus an explicitly budgeted **18 ns PMA latency** under the GTH Raw Mode / RX-TX Buffer Bypass path

This architecture has been validated through strict post-route SDF timing simulation on the FPGA fabric side, with the PMA latency budget treated as part of the final wire-to-wire target. I have also replaced the earlier testbench with a much stricter verification setup. Looking back, the old testbench clearly had major limitations, especially in how it modeled physical-layer behavior and packet validity.

Compared with what I believed at the beginning of 2026, the gap is enormous. My understanding of the physical layer has changed significantly. I no longer describe the design with vague claims such as “zero jitter.” Instead, the next validation focus is much more concrete: **BER measurement, Eye Scan results, and SFP loopback testing**.

In addition, my original plan to purchase the ZU15EG board during my sophomore year has now been moved forward to July. Around mid-July, I expect to attach real SFP hardware and the actual ZU15EG platform to this project.

I have also updated the repository timestamps. Looking back at this repository, I feel genuinely reflective: at the beginning of 2026, I was still learning logic gates—not even full gate-level circuit design yet. To reach this point during a gap year, starting from that level, has been a significant personal milestone.

This repository is no longer just a collection of timing screenshots. It is the record of a full physical-layer learning curve: from basic logic-gate thinking at the beginning of 2026 to a fixed-cycle GTH Raw Mode architecture with post-route timing evidence, stricter simulation, and an upcoming real ZU15EG + SFP hardware validation phase.

