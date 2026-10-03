# Candidate 12 — SpacemiT X60 Hardware Validation

## Hardware

- Architecture: RISC-V 64-bit
- CPU: SpacemiT X60
- Native execution on the X60 server
- CPU frequency scaling was enabled during validation

## Validation runs

Three independent formal runs were retained.

### Run 1 — Unpinned

Directory:

`results/run-20261003T100451Z-4023730`

Configuration:

- `ITERS=1000000`
- `ROUNDS=30`
- No CPU affinity pinning
- No PMU collection

### Run 2 — CPU 0 pinned

Directory:

`results/x60-cpu0-run2`

Configuration:

- `CPU=0`
- `ITERS=1000000`
- `ROUNDS=30`
- No PMU collection

### Run 3 — CPU 0 pinned with PMU

Directory:

`results/x60-cpu0-perf-run3`

Configuration:

- `CPU=0`
- `ITERS=1000000`
- `ROUNDS=30`
- `PERF=1`
- PMU events: retired instructions and cycles

All eight perf invocations completed with exit status 0.

## Native correctness

For every formal run, the validation harness executed the actual linked X60 binaries.

Probe and correctness checks completed successfully for:

- baseline / default / extract
- Candidate 12 / default / extract
- baseline / default / copy
- Candidate 12 / default / copy
- baseline / controlled / extract
- Candidate 12 / controlled / extract
- baseline / controlled / copy
- Candidate 12 / controlled / copy

Executed-binary SHA256 verification also passed.

## Final binary mapping

The X60-linked binaries confirmed the expected static mapping.

| Pipeline | Version | Instructions | Bytes | RVV configuration setups |
| --- | --- | ---: | ---: | ---: |
| default | baseline | 12 | 48 | 3 |
| default | Candidate 12 | 12 | 48 | 2 |
| controlled | baseline | 12 | 48 | 3 |
| controlled | Candidate 12 | 11 | 44 | 2 |

The default pipeline therefore removes one redundant RVV configuration setup without reducing total static instruction count.

With the controlled pipeline, Candidate 12 additionally reduces the sequence from 12 to 11 instructions and from 48 to 44 bytes.

## Wall-clock results

Mean Candidate 12 runtime relative to baseline:

| Pipeline / consumer | Run 1 | Run 2, CPU 0 | Run 3, CPU 0 + PMU |
| --- | ---: | ---: | ---: |
| default / extract | -5.21% | -5.34% | -5.08% |
| default / copy | +0.62% | +0.82% | +0.66% |
| controlled / extract | -0.49% | -0.94% | -0.67% |
| controlled / copy | +1.24% | +1.18% | +1.51% |

Negative values mean Candidate 12 ran faster in that microbenchmark.
Positive values mean Candidate 12 ran slower.

The direction of all four observations reproduced across all three formal runs.

These measurements are microbenchmark results and must not be generalized into an overall application-performance claim.

## PMU results

Run 3 collected retired instructions and cycles.

| Pipeline / consumer | Retired instructions | Cycles | IPC |
| --- | ---: | ---: | ---: |
| default / extract baseline | 50,668,031 | 46,573,265 | 1.088 |
| default / extract Candidate 12 | 49,182,045 | 44,856,794 | 1.096 |
| default / copy baseline | 58,676,575 | 58,558,139 | 1.002 |
| default / copy Candidate 12 | 57,198,113 | 58,909,785 | 0.971 |
| controlled / extract baseline | 50,675,224 | 46,242,907 | 1.096 |
| controlled / extract Candidate 12 | 49,654,285 | 46,170,364 | 1.075 |
| controlled / copy baseline | 58,712,370 | 58,637,177 | 1.001 |
| controlled / copy Candidate 12 | 57,669,282 | 59,060,984 | 0.976 |

Approximate Candidate 12 deltas:

| Pipeline / consumer | Instructions | Cycles |
| --- | ---: | ---: |
| default / extract | -2.93% | -3.69% |
| default / copy | -2.52% | +0.60% |
| controlled / extract | -2.01% | -0.16% |
| controlled / copy | -1.78% | +0.72% |

Candidate 12 reduced retired instructions in all four measured cases.

Runtime and cycle effects were consumer-dependent.

In particular, default/extract repeatedly improved by approximately 5% in wall-clock measurements and showed lower PMU cycle count, while both copy cases repeatedly became slightly slower despite retiring fewer instructions.

The microarchitectural reason for the copy behavior has not been established and should remain unresolved rather than inferred from the available counters.

## Supported conclusions

The X60 validation supports the following claims:

1. Candidate 12 preserves correctness for the tested native workloads.
2. Candidate 12 removes the targeted redundant RVV configuration setup in the final linked binaries.
3. The controlled pipeline reduces static instruction count from 12 to 11 and code size from 48 to 44 bytes.
4. Candidate 12 reduces dynamically retired instructions in all four PMU measurements.
5. Runtime impact on X60 is consumer-dependent.

The validation does **not** establish a general runtime speedup.

The observed copy slowdown remains an unresolved microarchitectural effect.
