# SnowSakura-FPGA — Current Progress

## 2026-07-23 — Continuous Multi-Packet OMD-C Parser Hardware Milestone

The frozen Puzhi ZU15EG laboratory path has progressed beyond single-vector parser acceptance. The current RX-domain ILA demonstrates repeated packet-header and Message 0 parsing while the real optical path remains locked.

### Hardware evidence

The captured build shows:

- `align_locked = 1` continuously.
- `parsed_valid` asserts as repeated one-cycle pulses.
- `parsed_error = 0` throughout the observed capture.
- `PktSize` rotates through `16'h004C`, `16'h0010`, and `16'h0030`.
- `MsgCount` rotates through `8'd2`, `8'd0`, and `8'd1`.
- Parsed message output changes between `MsgType = 16'h001F` and `MsgType = 16'h001E` on accepted message windows.
- `OrderId = 64'h1122334455667788`, `PriceRaw = 32'h00007A12`, `Quantity = 32'h000003E8`, and `SendTime = 64'h1122334455667788` remain stable at the observed parser-output boundary.

The `PktSize = 16'h0010` / `MsgCount = 0` case is treated as an OMD-C heartbeat. A heartbeat has no message and therefore is not classified by a `MsgType`; any held `MsgType` bus value during that packet is not interpreted as heartbeat metadata.

### What this closes

This capture closes the following laboratory boundary:

```text
Golden Raw32 TX source
    -> SFP2 / GT X0Y6 TX
    -> 10G-SR optics / OM4
    -> SFP1 / GT X0Y7 RX
    -> stable marker alignment
    -> repeated packet capture
    -> packet-header reconstruction
    -> Message 0 fixed-slice parsing
    -> repeated parsed_valid pulses with parsed_error = 0
```

The project has therefore moved from a single fixed Add Order proof into a repeated multi-packet parser exercise containing one-message, two-message-header, and heartbeat packet forms.

### Evidence boundary

This milestone does **not** claim that the complete Authoritative Truth Walker is finished. The present evidence proves repeated Packet Header handling and fixed Message 0 candidate extraction. It does not yet prove full `MsgSize` walking across every message in a packet, variable `NoEntries` traversal, sequence-gap recovery, duplicate suppression, or authoritative book reconstruction.

The frozen parser-output boundary is now suitable for the next lab core:

```text
Registered parser event
    -> bounded Msg30 / Msg31 / Msg32 classification
    -> lab-scale Order Directory lookup
    -> old-state read
    -> deterministic Order State Delta generation
    -> counters / ILA proof
```

## Next Milestone — Order State Delta Core

The next implementation step is deliberately narrow. It must not reopen the proven GTH, marker, capture, or parser layers.

### Frozen inputs

- Existing RX clock domain and reset ownership.
- Existing registered parser outputs and one-cycle `parsed_valid` contract.
- Existing Golden TX / Lab Source and physical SFP2-to-SFP1 direction.
- Existing GT Raw32, RX Buffer ON, TX Buffer Bypass, polarity, clock, and reset constants.

### First accepted message set

- Add Order — `MsgType = 30`
- Modify Order — `MsgType = 31`
- Delete Order — `MsgType = 32`

### Minimum state contract

The lab directory stores one bounded entry per test OrderId:

```text
valid
security_code
order_id
quantity
side
price_raw
```

The first core must produce registered delta metadata only:

```text
delta_valid
delta_error
delta_kind       // ADD, MODIFY, DELETE
old_quantity
new_quantity
signed_quantity_delta
security_code
order_id
side
price_raw
```

### Physical implementation rule

The first version is a laboratory closure core, not the final 16K production directory. It should use a small bounded register array or inferred RAM with one explicitly counted lookup stage. The parser event must enter an FDRE boundary before lookup/control. No dynamic part-select, runtime barrel shifter, wide priority scan, hidden FIFO, or asynchronous payload crossing is permitted.

At 322.56 MHz, one cycle is approximately 3.1004 ns. Every added stage must be named and verified after implementation. The initial target is:

```text
Cycle N     : parser event registered
Cycle N + 1 : directory read / old-state capture
Cycle N + 2 : delta arithmetic and write decision registered
```

This is a two-cycle post-parser laboratory budget, approximately 6.2008 ns, before any future book-level engine.

### Required closure evidence

- Add creates a previously invalid OrderId entry.
- Modify reads the old quantity and produces the correct signed quantity delta.
- Delete invalidates the entry and exposes the removed quantity.
- Modify/Delete on an unknown OrderId assert `delta_error` and do not corrupt another entry.
- One-cycle `delta_valid` alignment is proven in simulation and ILA.
- Post-route `WNS > 0`, `WHS > 0`, zero unconstrained paths, and zero failing endpoints.
- Critical register-to-register paths stay within two LUT levels unless an additional explicit pipeline stage is added.

## Project Stage Transition

```text
COMPLETED
GTH / optics / PRBS / Eye Scan
    -> Raw32 marker alignment
    -> repeated packet capture
    -> fixed Message 0 parser
    -> continuous parsed_valid hardware evidence

ACTIVE NEXT STAGE
Order State Delta Core
    -> bounded Order Directory
    -> old/new state reconstruction
    -> deterministic delta output

LATER STAGES
Authoritative Truth Walker
    -> full MsgSize walking
    -> sequence/gap/duplicate handling
    -> variable-entry processing
    -> authoritative book state

Fast-Candidate Plane
    -> registered future permits
    -> A/B arbitration
    -> latency-controlled release
```

This transition preserves the completed parser foundation and moves the active engineering work to stateful order-delta arithmetic without mixing in the full production book engine, dual-line arbitration, or 10GBASE-R normalization.
