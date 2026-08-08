# Cascaded Moore Counter

> A hierarchical VHDL design built from two cascaded Moore state machines: one counts up from 0 to 7, then hands control off to a second machine that counts back down from 7 to 0 — both sharing a single 3-bit LED bank through a structural mux. Written for a Quartus-targeted FPGA.

![Language](https://img.shields.io/badge/Language-VHDL-purple)
![Architecture](https://img.shields.io/badge/Architecture-Moore%20FSM-orange)
![Toolchain](https://img.shields.io/badge/Toolchain-Quartus-blue)

## Overview

`top_level.vhd` structurally wires two identical-in-shape but behaviorally opposite Moore machines together: `moore_machine_up` counts 0 → 7, and `moore_machine_down` counts 7 → 0. The up-counter's "done" output is tied directly to the down-counter's "go" input, so the second machine sits idle until the first formally reaches its terminal state. A single LED bank is multiplexed between the two outputs based on that same done signal, so the physical display shows one continuous count: up, then down.

## Block Diagram

```
   sys_clk ────────────┬───────────────────────────────┬─────────────────────
                       │                               │
   btn_reset ──────────┼────┬──────────────────────────┼────┬────────────────
                       │    │                          │    │
                       ▼    ▼                          ▼    ▼
               ┌─────────────────────┐   done_cable   ┌─────────────────────┐
   btn_go ────►│  moore_machine_up   ├───────────────►│  moore_machine_down │
               │    (counts 0→7)     │  o_dn     i_go │    (counts 7→0)     │
               └──────────┬──────────┘                └──────────┬──────────┘
                          │ chip_a (3-bit)                       │ chip_b (3-bit)
                          └──────────────────┬───────────────────┘
                                             ▼
                               led_bank <= chip_a when done_cable = '0'
                                          else chip_b
```

## State Machines

Both FSMs share the same three-state shape, but differ in direction, exit condition, and `i_go` polarity.

`moore_machine_up`
```
        i_go = '0'                          w_cntr = "111"
 IDLE ────────────────► COUNT ────────────────────────────► DONE
  ▲                  (w_cntr++ each tick)                      │
  │                                                             │ o_dn = '1', holds
  └── i_rst = '0'  (async, from any state) ────────────────────┘
```

`moore_machine_down`
```
        i_go = '1'                          w_cntr = "000"
 IDLE ────────────────► COUNT ────────────────────────────► DONE
  ▲                  (w_cntr-- each tick)                      │
  │                                                            │ holds (no o_dn)
  └── i_rst = '0'  (async, from any state) ────────────────────┘
```

Each FSM also runs an internal clock-divider process: a free-running counter (`0` to `MAX_COUNT-1`) that pulses `w_clk_tk` high for a single cycle once it wraps, decoupling the FSM's state-transition rate from the raw system clock. State transitions only happen on a `w_clk_tk` tick, not every `sys_clk` edge.

## Port Map

`top_level`

| Port | Direction | Width | Description |
|---|---|---|---|
| `sys_clk` | in | 1 | System clock, pin-assigned in Quartus |
| `btn_reset` | in | 1 | Active-low asynchronous reset, shared by both FSMs |
| `btn_go` | in | 1 | Active-low start trigger for the up-counter |
| `led_bank` | out | 3 | 3-bit display, multiplexed between the up- and down-counter outputs |

`moore_machine_up` / `moore_machine_down`

| Generic/Port | Direction | Width | Description |
|---|---|---|---|
| `MAX_COUNT` | generic | natural | Clock-divider period; default `50_000_000` |
| `i_clk` | in | 1 | System clock |
| `i_rst` | in | 1 | Active-low asynchronous reset |
| `i_go` | in | 1 | Start trigger — **active-low** on the up-counter, **active-high** on the down-counter |
| `o_dn` | out | 1 | *(up-counter only)* Asserted once `COUNT` reaches `"111"` |
| `o_led` | out | 3 | Inverted counter value (active-low LED encoding) |

## Technical Details

- Clock-divided ticking: Rather than transitioning state on every `sys_clk` edge, each FSM waits for its internal divider to overflow and emit a single-cycle `w_clk_tk` pulse. This keeps the state logic independent of the raw clock frequency — the same entity runs at physical, human-visible speed with a large `MAX_COUNT`, or fast for simulation with a small one.
  
- Active-low LED encoding: Both modules drive `o_led <= not w_cntr`, inverting the internal counter before it reaches the pins, which is standard for boards where an LED lights up on a logic low (like my Altera Cyclone II).

  
- Structural handoff instead shared control logic: The down-counter doesn't know it's "second" so it just treats the up-counter's `o_dn` as its own `i_go`. The sequencing lives entirely in how `top_level` wires the two together.

  
- Mixed `i_go` polarity: The up-counter starts on `i_go = '0'`; the down-counter starts on `i_go = '1'`. This is intentional (noted in-code) instead of being an oversight. It's worth checking before reusing either module in a context where both are expected to share one polarity.

- Asynchronous, active-low reset: Both FSMs include `i_rst` in their process sensitivity list, so a reset forces the state back to `IDLE` immediately, independent of the clock edge.

## Simulation

The default `MAX_COUNT` of `50_000_000` is sized for a real clock on real hardware. For waveform inspection, instantiate the FSMs with a small `MAX_COUNT` (e.g. `4` or `8`) via the generic map instead of relying on the top-level default.

1. Load `top_level.vhd`, `moore_machine_up.vhd`, and `moore_machine_down.vhd` into a VHDL simulator (ModelSim, GHDL, Vivado).
2. Write a testbench that drives `sys_clk`, pulses `btn_reset` low, then drives `btn_go` low to start the up-counter.
3. Observe `led_bank`: it should count `chip_a` from `0` to `7`, then switch over and count `chip_b` back down from `7` to `0`.

## Synthesis (Quartus)

1. Create a new Quartus project targeting your FPGA device.
2. Add `top_level.vhd`, `moore_machine_up.vhd`, and `moore_machine_down.vhd` as design files, with `top_level` set as the top-level entity.
3. In the Pin Planner / Assignments Editor, map `sys_clk`, `btn_reset`, `btn_go`, and `led_bank(2 downto 0)` to your board's physical clock, buttons, and LEDs.
4. Run Start Compilation.
5. Program the device via the Programmer using your board's JTAG/USB-Blaster connection.

## Controls

| Signal | Action |
|---|---|
| `btn_reset` | Hold low to reset both FSMs back to `IDLE` |
| `btn_go` | Pull low to start the up-counter (0→7); the down-counter (7→0) starts automatically once the up-counter finishes |

---
*powered by logic, coffee, and many sleepless nights*