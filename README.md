# LoAS SNN Accelerator — Twin-Laggy Pipelined RTL

Twin-laggy pipelined implementation of the LoAS inner-join accelerator. Both fiber-A and fiber-B bitmasks go through separate laggy prefix-sum units running in parallel. A priority encoder scans the AND result one match per cycle, accumulating directly where spikes actually fire. No speculative accumulation, no correction FIFOs. The 16-cycle laggy latency is hidden inside the previous frame's scan on the warm path.

## Architecture

**Cold start:** IDLE → WAIT_COLD (16 cycles, both laggies running) → SCAN (popcount(AND) cycles) → DONE_ST

**Warm path:** DONE_ST → SCAN directly, zero stall. Laggies for frame N+1 were fired during frame N's scan.

**Fallback:** If frame N+1's start arrives too late for laggies to finish before frame N's scan ends, DONE_ST falls back to WAIT_COLD and waits for the remaining cycles.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| T | 4 | Timesteps per inference pass |
| N_TPPE | 16 | Output neurons in parallel |
| BM_WIDTH | 128 | Input neuron count (bitmask width) |
| W_WIDTH | 8 | Weight bit width |
| ACC_WIDTH | 32 | Accumulator bit width |
| OFF_W | 7 | ceil(log2(BM_WIDTH)) — prefix offset width |
| N_ADDERS | 8 | Adder lanes per laggy (latency = BM_WIDTH/N_ADDERS) |
| THRESHOLD | 1 | LIF firing threshold |

## Files

| File | Description |
|------|-------------|
| `priority_encoder.sv` | Combinational lowest-set-bit finder using in & -in + generate-based one-hot encoder |
| `laggy_prefix_sum.sv` | Sequential adder-chain prefix sum, BM_WIDTH/N_ADDERS cycle latency, 1-deep input queue |
| `inner_join_unit.sv` | Twin laggy + PE scan + direct accumulation + pipelined warm path |
| `p_lif.sv` | Spatially unrolled LIF, T comparators in parallel |
| `tppe.sv` | Wraps inner_join_unit + p_lif for one output neuron, exposes ready_o |
| `top_loas.sv` | 16x TPPE array, bm_b broadcast, per-TPPE fiber_a slice |
| `tb_top_loas.sv` | 5 directed tests including pipeline timing verification |

## Test Cases

| Test | Input | Expected |
|------|-------|----------|
| T1 | 128 matches, all spikes 1111, weight=1 | spike=1111 (membrane=128) |
| T2 | 128 matches, all spikes 0000, weight=1 | spike=0000 (no accumulation) |
| T3 | Disjoint bitmasks, 0 matches | spike=0000, exits SCAN in 1 cycle |
| T4 | 8 matches, spike=1010, weight=4 | spike=1010 (membrane[t1,t3]=32) |
| T5 | Frame 0: 128 matches. Frame 1: 8 matches fired 50 cycles into frame 0's scan | Frame 1 done 10 cycles after frame 0 done (pipeline saves 16 cycles vs 26 without) |

## Simulation — iverilog

## Simulation — Vivado (Tcl console)

Add all source files then run all tests from the Tcl console:

```tcl
add_files -scan_for_includes {
    priority_encoder.sv
    laggy_prefix_sum.sv
    inner_join_unit.sv
    p_lif.sv
    tppe.sv
    top_loas.sv
}
add_files -scan_for_includes -fileset sim_1 tb_top_loas.sv
set_property top tb_top_loas [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
launch_simulation
run all
```

Expected output:

```
T1: dense fire — 128 matches, all spikes 1111
T1 TPPE[0] spike=1111 (expect 1111)
...
T2: dense no-fire — 128 matches, all spikes 0000
T2 TPPE[0] spike=0000 (expect 0000)
...
T3: disjoint bitmasks — 0 matches
T3 TPPE[0] spike=0000 (expect 0000)
...
T4: 8 matches, spike=1010, weight=4
T4 TPPE[0] spike=1010 (expect 1010)
...
T5: pipeline — frame0=128 matches, frame1=8 matches fired mid-scan
T5 frame0 done at cyc=153
T5 frame0 TPPE[0] spike=1111 (expect 1111)
...
T5 frame1 done at cyc=163 delta=10 (expect ~10, non-pipeline would be ~26)
T5 frame1 TPPE[0] spike=1010 (expect 1010)
...
Done.
```

## Pipeline Timing

For the warm path (start_i for frame N+1 arrives during frame N's SCAN):

| Scenario | Cycles per frame |
|----------|-----------------|
| Cold start | 16 (laggy) + popcount(AND) (scan) + 2 (done + p_lif) |
| Warm, laggy done before scan ends | popcount(AND) + 2 |
| Warm, laggy not done | remaining laggy cycles + popcount(AND) + 2 |

The 16-cycle stall is paid only once. After warmup, throughput is limited by popcount(AND) — the actual number of spike matches, not the bitmask width.
