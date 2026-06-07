# loas-twin-laggy

SystemVerilog RTL of a modified LoAS SNN accelerator. The original LoAS paper uses one fast prefix-sum and one laggy prefix-sum in an asymmetric inner-join, which requires a speculative pseudo-accumulator, FIFO-B, FIFO-mp, and correction accumulators to fix wrong predictions. This implementation replaces that entire speculative path with twin symmetric laggy prefix trees, a front-end coalescing buffer, and a deterministic T-stage cascade pipeline — no speculation, no correction overhead.

---

## How the original LoAS inner-join works

The paper computes the inner-join between two 128-bit fiber bitmasks (bm-A from the spike matrix, bm-B from the weight matrix) like this:

1. AND gate finds matched positions
2. Fast prefix-sum (1 cycle) immediately generates an offset for fiber-B and accumulates the weight into a pseudo-accumulator, assuming fiber-A fires at all timesteps
3. Laggy prefix-sum (many cycles) slowly computes the actual fiber-A offsets
4. When laggy finishes, it checks each buffered position — if fiber-A was NOT all-1s, the wrong contribution is sent to correction accumulators and subtracted at the end

This works but carries hardware cost: FIFO-B, FIFO-mp, pseudo-accumulator, and a full correction accumulator array.

---

## What this implementation does differently

Both prefix-sum circuits are now laggy (twin symmetric). Since neither tree is speculative, the pipeline is:

```
AND gate → twin laggy trees → coalescing buffer → cascade spine → P-LIF
```

**Coalescing and Early-Bypass Buffer** — sits between the inner-join and the compute spine. If the AND result is all-zero (very common given SNN sparsity), a single OR-reduction gate detects it in 1 cycle and skips the spine entirely. If the token is sparse but non-zero, the buffer holds it and OR-merges it with the next incoming token before firing into the spine.

**Cascade Spine** — a T-stage shift-register pipeline where stage `s` is physically dedicated to temporal slot `s`. When a token arrives at stage `s`, if bit `s` of the token is 1 the accumulator updates; if it is 0 the clock-enable to that accumulator is suppressed and the adder draws zero dynamic power. Tokens advance unconditionally every cycle — zero stall, deterministic T-cycle latency.

**P-LIF** — T parallel LIF comparators that all fire in the same clock cycle, generating output spikes for all timesteps at once.

No pseudo-accumulator. No FIFO-B. No correction logic anywhere.

---

## Files

| File | What it does |
|---|---|
| `laggy_prefix_sum.sv` | Sequential adder chain, LAGGY_LAT cycles, 1-deep input queue for back-to-back frames |
| `inner_join_unit.sv` | AND gate + twin laggy trees, latches resolved mask when both trees finish |
| `coalescing_bypass_buffer.sv` | Zero-bypass OR gate + sparse token coalescing with 2-cycle timeout |
| `cascade_spine.sv` | T-stage shift pipeline, per-stage ICG clock-enable on accumulator |
| `plif_bank.sv` | T parallel LIF comparators, signed threshold, one-shot firing |
| `tppe.sv` | One output neuron: inner_join → coalescing → spine → P-LIF |
| `spike_compression_unit.sv` | Packs 1-bit spikes into T-bit bitmask words, 2-cycle pipeline |
| `evolved_top.sv` | Top level: SCU + N_TPPE array + 6-state FSM |
| `tb_evolved_top.sv` | 6 simulation tests |

---

## Parameters

| Parameter | Default | Notes |
|---|---|---|
| T | 128 | Fiber/bitmask width — timesteps per token |
| K | 4 | K-frames per tile |
| M / N_TPPE | 8 | Output neurons |
| W_WIDTH | 8 | Signed weight bit-width |
| ACC_WIDTH | 32 | Accumulator width |
| THRESHOLD | 256 | LIF firing threshold |
| LEAK_SHIFT | 0 | 0 = hard reset; N = v_mem >>> N at frame_start |
| LAGGY_LAT | 128 | Cycles per laggy tree |
| DRAIN_CYCLES | 400 | FSM drain budget — must be >= LAGGY_LAT + T + frame_gap + margin |

---

## Running

**iverilog**
```bash
iverilog -g2012 -o sim \
  laggy_prefix_sum.sv inner_join_unit.sv coalescing_bypass_buffer.sv \
  cascade_spine.sv plif_bank.sv tppe.sv spike_compression_unit.sv \
  evolved_top.sv tb_evolved_top.sv
vvp sim
```

**Vivado** — add all 9 `.sv` files as design sources, set `tb_evolved_top` as simulation top, run Behavioral Simulation. No `` `include `` needed.

**Expected output**
```
=== T1: dense, weight=6, acc=12 > 10, all fire ===     PASS
=== T2: dense, weight=4, acc=8  < 10, no fire  ===     PASS
=== T3: zero bitmask, zero-bypass, no fire      ===     PASS
=== T4: disjoint bitmasks, AND=0, no fire       ===     PASS
=== T5: alternating bitmask, even bits fire     ===     PASS
=== T6: coalescing, lower 32 bits fire          ===     PASS
```

---

## What is and isn't modelled

The memory subsystem (global FiberCache, DMA, scheduler, crossbar) is not implemented — bitmasks and weights arrive as direct port inputs. The RTL covers the full compute path from bitmask inputs to output spikes.
