# SnowSakura-FPGA — Current Progress

## 2026-07-23 — Continuous Multi-Packet OMD-C Parser Hardware Milestone Completed

The Golden Puzhi ZU15EG laboratory path is complete and frozen through the registered fixed-Message-0 parser boundary. The result is running on the real SFP2 / GT X0Y6 TX → 10G-SR optics → OM4 → SFP1 / GT X0Y7 RX path with fabric-owned Raw32 data.

## Hardware proof

| Boundary | Completed result |
|---|---|
| GTH and optics | SFP2 TX → SFP1 RX physical direction closed |
| Receiver | RX Buffer ON, stable user-clock-domain Raw32 stream |
| Alignment | `align_locked = 1` continuously |
| Packet stream | `PktSize / MsgCount` rotates through `16'h004C / 2`, `16'h0010 / 0`, and `16'h0030 / 1` |
| Parser output | repeated one-cycle `parsed_valid` pulses |
| Error output | `parsed_error = 0` continuously |
| Message types | `16'h001F` Modify Order and `16'h001E` Add Order |
| Order identity | `OrderId = 64'h1122334455667788` |
| Price | `PriceRaw = 32'h00007A12` |
| Quantity | `Quantity = 32'h000003E8` |
| Timestamp | `SendTime = 64'h1122334455667788` |

The `16'h0010 / 0` packet is the OMD-C Heartbeat form and contains no message. The `16'h004C / 2` and `16'h0030 / 1` packets prove continuous packet-header reconstruction across two-message and one-message forms; the registered fixed-Message-0 output advances through Modify Order and Add Order without loss of alignment.

## Closed hardware chain

```text
Golden Raw32 TX / Lab Source
    -> SFP2 / GT X0Y6 TX
    -> 10G-SR optics / OM4
    -> SFP1 / GT X0Y7 RX
    -> stable marker alignment
    -> continuous registered packet capture
    -> OMD-C Packet Header reconstruction
    -> fixed Message 0 Add / Modify parsing
    -> repeated parsed_valid, parsed_error = 0
```

This is the completed reusable SnowSakura laboratory foundation. The GTH, optical direction, clocks, reset ownership, RX polarity, buffer mode, marker/alignment, packet capture, and fixed parser are frozen.

## Active engineering stage

Development has moved to the **Order State Delta Core** behind the registered parser boundary:

```text
registered parser event
    -> Msg30 / Msg31 / Msg32 classification
    -> bounded Order Directory lookup
    -> old-state capture
    -> signed quantity delta
    -> registered delta_valid / delta_error
```

The first state-engine closure will process Add Order, Modify Order, and Delete Order without modifying the completed optical/parser foundation.
