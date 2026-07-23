# SnowSakura-FPGA — Current Progress

## 2026-07-24 — HKEX OMD-C Exchange Feed Simulator Completed and Sealed

The Puzhi ZU15EG laboratory system is now complete from the Golden fabric TX source through the real optical link, continuous OMD-C parsing, authoritative order-state updates, price-level aggregation, top-of-book selection, and registered snapshot export.

The simulator is no longer an unfinished parser foundation. It is a sealed Golden hardware test source for the next SnowSakura single-lane Fast-Candidate work.

## Completed physical path

```text
GTHE4_CHANNEL_X0Y6 TX pins / SFP2
    -> 10G-SR transmitter optics
    -> OM4 fibre
    -> SFP1 receiver optics
    -> GTHE4_CHANNEL_X0Y7 RX pins
    -> X0Y7 RX sampler
    -> Raw32 alignment and packet capture
    -> fixed Message 0 parser
    -> Order State Delta
    -> 64-bit Price-Level Aggregator
    -> Top-of-Book Bitmap / priority selection
    -> Register Snapshot export
```

## Hardware proof

| Boundary | Completed result |
|---|---|
| GTH and optics | X0Y6/SFP2 TX pins → optics → OM4 → X0Y7/SFP1 RX pins |
| Eye Scan | X0Y7 RX sampler, open UI 77.78% and open area 6720 at the 1e-10 dwell BER setting |
| Receiver | RX Buffer ON, stable user-clock-domain Raw32 stream |
| Alignment | `align_locked = 1` continuously |
| Packet stream | `PktSize / MsgCount` rotates through `16'h004C / 2`, `16'h0010 / 0`, and `16'h0030 / 1` |
| Parser output | repeated one-cycle `parsed_valid` pulses, `parsed_error = 0` |
| Message types | `16'h001F` Modify Order and `16'h001E` Add Order |
| Security / side | `SecurityCode = 32'h000002BC`, `Side = 8'h01` |
| Order identity | `OrderId = 64'h1122334455667788` |
| Price / quantity | `PriceRaw = 32'h00007A12`, `Quantity = 32'h000003E8` |
| Book error state | `position_error = 0` |
| Snapshot state | init done, clean, version `32'h00000001` |
| Snapshot best offer | valid, level `6'h12`, price `32'h00007A12`, aggregate quantity `64'h00000000000003E8` |

The `16'h0010 / 0` packet is the OMD-C Heartbeat form and contains no message. The held `MsgType` bus is ignored on that packet.

## Closed implementation chain

- Golden TX/Lab Source
- SFP2 TX / GT X0Y6 → OM4 → SFP1 RX / GT X0Y7 Raw32 hardware integration
- marker/alignment and continuous registered packet capture
- fixed Message 0 parser
- `omdc_order_state_delta`
- 64-bit Price-Level Aggregator
- Top-of-Book Bitmap/priority selection
- Register Snapshot export
- simulation
- synthesis and implementation
- post-route timing closure
- bitstream/ILA hardware regression
- final In-System IBERT Eye Scan evidence

## Frozen boundary

The simulator, GTH substrate, optical direction, marker/alignment, packet capture, fixed parser, order-state laboratory chain, aggregator, bitmap, and snapshot export are sealed. They are retained as the Golden hardware test source and are not the next engineering task.

## Active engineering stage

Development has returned to the **single-lane HKEX OMD-C Fast-Candidate path**. The immediate single-lane closure stops at the registered candidate boundary; it does not pretend that dual-line arbitration is already active. The final dual-line latency budget is:

```text
registered RX normalization: 3 cycles
    -> fixed-slice Fast-Candidate extraction: 1 cycle
    -> chunked one-hot A/B arbitration: 1 cycle
    -> registered TX release: 1 cycle
```

At 322.56 MHz, six fabric cycles are approximately 18.60 ns. Together with the approximately 18 ns PMA model, the architectural target is approximately 36.6 ns. The exact result will be accepted only from the matching post-route STA, timing simulation, BER, and measured hardware configuration.
