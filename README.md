# Candidate 12 standalone hardware validation package

This package adapts unchanged compiler-generated witness kernels to the scalar
LP64D ABI. It contains no LLVM implementation change. No hardware validation or
runtime improvement is established by preparing this package. Server access is
currently prohibited; run this only after the user separately authorizes native
execution, or the user elects to run it themselves. There are no SSH/SCP commands.

Keep the complete package below `~/llvm-project`, for example
`~/llvm-project/candidate12-riscv-server-validation`. Root supplies `SHA256SUMS`
and all eight kernel objects. Their names are
`{baseline,candidate12}-{default,controlled}-{extract,copy}.o`.
`candidate12_extract` and `candidate12_copy` are only symbol renamings of the
original witness functions. Baseline/candidate and default/controlled codegen
provenance, exact commands, hashes, original IR and generated assembly are
provided by Root. Default and controlled are separate experiment groups;
controlled disables the two tail-duplication mechanisms. Do not combine them.

A future user-run native invocation is:

```sh
cd ~/llvm-project/candidate12-riscv-server-validation
ITERS=1000000 ROUNDS=30 ./run-native.sh
# Optional: choose a known available CPU explicitly.
CPU=3 ITERS=1000000 ROUNDS=30 ./run-native.sh
```

The script requires native Linux riscv64, RVV 1.0 with e32/e64 m1 support,
LP64D, native GCC/binutils and ordinary shell utilities. It checks the package
manifest, builds one shared scalar runner with `-O2 -fno-lto
-fno-tree-vectorize -march=rv64gc -mabi=lp64d`, builds the wrappers with
`-march=rv64gcv -mabi=lp64d`, and links four separate executables using
`--no-relax`. LLVM is never rebuilt. It stores hashes, symbols, disassembly,
ELF headers and attributes of the actual native executables. Before executing
any binary it requires ELF64 little-endian RISC-V with double-float ABI and
RVV 1.0 attributes, then verifies all eight linked kernel mappings:

| Group | Variant | Instructions | Symbol bytes | VSET setups |
|---|---|---:|---:|---:|
| default | baseline | 12 | 48 | 3 |
| default | candidate12 | 12 | 48 | 2 |
| controlled | baseline | 12 | 48 | 3 |
| controlled | candidate12 | 11 | 44 | 2 |

The mapping gate also requires decoded instruction bytes to equal symbol size.
It records `kernel-mapping.csv` and aborts on unexpected mapping rather than
changing a kernel. Static counts do not establish retired instruction counts.
Only after every mapping passes does it probe RVV/OS execution. Unsupported
instructions terminate with a recorded SIGILL failure. A successful probe
establishes usable instructions, not a particular hardware model.

All execution results go into a new `results/run-<UTC>-<pid>` directory. Set
`RESULT_NAME` to a new simple directory name if desired. Existing directories
are rejected. Temporary compiler files use this result directory. The script
never cleans files or changes privileges. `CPU` is optional, explicit single
CPU affinity; without it execution is unbound. Environment, tool versions,
CPU description and allowed affinity are recorded.

Correctness runs before timing in every process. It covers four fixed input
patterns and 256 deterministic random patterns, both branches, full initialized
register inputs, guarded memory and return buffers, AVL 0/1/2/7 and e64 VLMAX
boundaries through UINT64_MAX. The machine's actual e32/e64 VL queries determine
active store prefixes, including implementation-permitted VL choices for AVL
7. Arithmetic uses unsigned modular references and memcpy element access.
Extraction with true branch and AVL zero is excluded because the original
poison passthrough makes extracted lane zero undefined. Copy with AVL zero is
checked, including the full initialized z return. Inactive memory tails and
both guards must remain unchanged. These cases are focused coverage, not an
exhaustive correctness proof.

Timing calls the unchanged kernel once per scalar loop iteration, with branch
choice alternating and the true branch AVL fixed to e64 VLMAX. Full-register
input loads, wrapper call overhead, copy return stores, scalar loop and checksum
accumulation are inside `CLOCK_MONOTONIC_RAW` timing. The checksum reference and
correctness checks are outside timing. Copy also reads the returned first lane
inside timing. Both variants use exactly the same common harness objects and
input initialization. The witness kernel has no LLVM loop; the repetitions are
external harness calls. Results measure this composite call workload, not an
isolated instruction or general application speedup.

Each pipeline/consumer group gets two warmups per variant followed by at least
30 paired rounds, alternating baseline-first and candidate-first order.
`raw.csv` preserves every elapsed_ns, checksum and correctness result;
`summary.csv` reports count, mean, median, sample standard deviation, unscaled
median absolute deviation (MAD), minimum and maximum without selecting runs.
The portable AWK helpers require no server Python installation. Inspect warmup
elapsed_ns and increase ITERS so each timed warmup is at least 100 ms; record
the chosen iteration count and rerun the full protocol in a new results directory.
Do paired statistical analysis locally from all raw rounds, report distributions
and uncertainty, and keep default and controlled conclusions separate. Default
codegen removes one setup but retains the same static instruction/byte count;
controlled codegen has a different shape. No benefit threshold is assumed.

Optional `PERF=1 ./run-native.sh` adds a separate whole-process perf experiment
after timing, using already-installed `perf stat -r "$ROUNDS" -e
instructions,cycles` for both variants and each pipeline/consumer group.
It preserves perf version, CSV, stdout, stderr and exit status. Missing perf or
permission/event failures are recorded without installing anything or changing
permissions. Inspect each event's availability even when perf exits zero;
unavailable/unsupported/not-counted event values are not valid measurements.
Such counters
cover the whole process, including correctness, startup and harness work;
they are not kernel-only counts. Unsupported or denied events must be reported
as unavailable. Never change perf permissions or infer missing counter values.
