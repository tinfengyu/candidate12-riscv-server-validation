#!/usr/bin/env bash
# User-run locally on a RISC-V server; no remote connection commands.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
PKG=$(pwd -P)
case "$PKG" in "$HOME/llvm-project/"*) ;; *) echo 'Package must be under ~/llvm-project' >&2; exit 2;; esac
[[ $(uname -m) == riscv64 ]] || { echo 'Native riscv64 required' >&2; exit 2; }
for tool in gcc objdump readelf sha256sum awk; do command -v "$tool" >/dev/null; done
[[ -f SHA256SUMS ]] || { echo 'Root-generated SHA256SUMS required' >&2; exit 2; }
sha256sum --check --strict SHA256SUMS
ITERS=${ITERS:-1000000}
ROUNDS=${ROUNDS:-30}
PERF=${PERF:-0}
[[ $PERF == 0 || $PERF == 1 ]] || { echo 'PERF must be 0 or 1' >&2; exit 2; }
[[ $ITERS =~ ^[1-9][0-9]*$ && $ROUNDS =~ ^[1-9][0-9]*$ && $ROUNDS -ge 30 ]] || { echo 'Positive ITERS and ROUNDS >= 30 required' >&2; exit 2; }
PREFIX=()
if [[ -n ${CPU:-} ]]; then
  [[ $CPU =~ ^[0-9]+$ ]] || { echo 'CPU must be a single nonnegative integer' >&2; exit 2; }
  command -v taskset >/dev/null
  PREFIX=(taskset -c "$CPU")
fi
NAME=${RESULT_NAME:-run-$(date -u +%Y%m%dT%H%M%SZ)-$$}
[[ $NAME =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'Invalid RESULT_NAME' >&2; exit 2; }
mkdir -p results
[[ ! -L results && $(realpath results) == "$PKG/results" ]] || { echo 'Unsafe results path' >&2; exit 2; }
mkdir "results/$NAME"
OUT="$PKG/results/$NAME"
mkdir "$OUT/tmp"
export TMPDIR="$OUT/tmp"
exec > >(tee "$OUT/run.log") 2>&1
{
  date -u
  uname -a
  gcc --version
  objdump --version
  readelf --version
  printf 'package=%s\nITERS=%s\nROUNDS=%s\nCPU=%s\nPERF=%s\n' "$PKG" "$ITERS" "$ROUNDS" "${CPU:-unbound}" "$PERF"
  cat /proc/cpuinfo
  cat /proc/self/status
  if command -v lscpu >/dev/null; then lscpu; fi
} > "$OUT/environment.txt"
cp SHA256SUMS "$OUT/package-SHA256SUMS"
set -x
gcc -O2 -fno-lto -fno-tree-vectorize -march=rv64gc -mabi=lp64d -Wall -Wextra -Werror -c runner.c -o "$OUT/runner.o"
gcc -fno-lto -march=rv64gcv -mabi=lp64d -c wrappers.S -o "$OUT/wrappers.o"
printf 'pipeline,label,consumer,symbol,instructions,symbol_bytes,decoded_bytes,setups,expected_instructions,expected_bytes,expected_setups,mapping\n' > "$OUT/kernel-mapping.csv"
for pipeline in default controlled; do
  for label in baseline candidate12; do
    exe="$OUT/$label-$pipeline"
    gcc -fno-lto -march=rv64gcv -mabi=lp64d -Wl,--no-relax "$OUT/runner.o" "$OUT/wrappers.o" \
      "$label-$pipeline-extract.o" "$label-$pipeline-copy.o" -o "$exe"
    sha256sum "$exe" >> "$OUT/executed-SHA256SUMS"
    objdump -d "$exe" > "$exe.disassembly.txt"
    objdump -d --disassemble=candidate12_extract "$exe" > "$exe.extract.txt"
    objdump -d --disassemble=candidate12_copy "$exe" > "$exe.copy.txt"
    objdump -t "$exe" > "$exe.symbols.txt"
    readelf -h "$exe" > "$exe.elf-header.txt"
    readelf -A "$exe" > "$exe.elf-attributes.txt"
    awk '/Class:/ && /ELF64/ {cls=1} /Data:/ && /little endian/ {le=1} /Machine:/ && /RISC-V/ {rv=1} /Flags:/ && /double-float ABI/ && !/RVE/ {abi=1} END {exit !(cls && le && rv && abi)}' "$exe.elf-header.txt" || { echo "Unexpected ELF/LP64D header: $exe"; exit 1; }
    awk -F '"' '/Tag_RISCV_arch:/ {if ($2 ~ /^rv64/ && $2 ~ /_v1p0(_|$)/) ok=1} END {exit !ok}' "$exe.elf-attributes.txt" || { echo "Missing expected RVV 1.0 attribute: $exe"; exit 1; }
    expected_instructions=12
    expected_bytes=48
    expected_setups=3
    if [[ $label == candidate12 ]]; then
      expected_setups=2
      if [[ $pipeline == controlled ]]; then expected_instructions=11; expected_bytes=44; fi
    fi
    for consumer in extract copy; do
      awk -v pipeline="$pipeline" -v label="$label" -v consumer="$consumer" \
        -v symbol="candidate12_$consumer" -v expected_instructions="$expected_instructions" \
        -v expected_bytes="$expected_bytes" -v expected_setups="$expected_setups" \
        -f check-mapping.awk "$exe.symbols.txt" "$exe.$consumer.txt" >> "$OUT/kernel-mapping.csv" || { echo "Unexpected linked kernel mapping: $exe/$consumer"; exit 1; }
    done
  done
done
# Every actual binary must pass mapping before any probe or correctness run.
for pipeline in default controlled; do
  for label in baseline candidate12; do
    exe="$OUT/$label-$pipeline"
    "${PREFIX[@]}" "$exe" --probe > "$exe.probe.txt"
    "${PREFIX[@]}" "$exe" --check > "$exe.correctness.txt"
  done
done
set +x
printf 'pipeline,consumer,round,order,label,reported_consumer,iters,vlenb,elapsed_ns,checksum,correctness\n' > "$OUT/raw.csv"
for pipeline in default controlled; do
  for consumer in extract copy; do
    for warm in 1 2; do
      for label in baseline candidate12; do
        "${PREFIX[@]}" "$OUT/$label-$pipeline" --bench "$consumer" "$ITERS" >> "$OUT/warmup.csv"
      done
    done
    for ((round=1; round<=ROUNDS; ++round)); do
      if ((round % 2)); then labels=(baseline candidate12); else labels=(candidate12 baseline); fi
      order=0
      for label in "${labels[@]}"; do
        order=$((order + 1))
        line=$("${PREFIX[@]}" "$OUT/$label-$pipeline" --bench "$consumer" "$ITERS")
        printf '%s,%s,%s,%s,%s,%s\n' "$pipeline" "$consumer" "$round" "$order" "$label" "$line" >> "$OUT/raw.csv"
      done
    done
  done
done
sha256sum --check --strict "$OUT/executed-SHA256SUMS"
awk -f summarize.awk "$OUT/raw.csv" > "$OUT/summary.csv"
if [[ $PERF == 1 ]]; then
  if command -v perf >/dev/null; then
    perf --version > "$OUT/perf-version.txt"
    printf 'pipeline,consumer,label,exit_status\n' > "$OUT/perf-status.csv"
    for pipeline in default controlled; do
      for consumer in extract copy; do
        for label in baseline candidate12; do
          status=0
          "${PREFIX[@]}" perf stat -r "$ROUNDS" -x, -e instructions,cycles \
            -o "$OUT/perf-$label-$pipeline-$consumer.csv" -- \
            "$OUT/$label-$pipeline" --bench "$consumer" "$ITERS" \
            > "$OUT/perf-$label-$pipeline-$consumer.stdout.txt" \
            2> "$OUT/perf-$label-$pipeline-$consumer.stderr.txt" || status=$?
          printf '%s,%s,%s,%s\n' "$pipeline" "$consumer" "$label" "$status" >> "$OUT/perf-status.csv"
        done
      done
    done
  else
    printf 'unavailable: perf is not installed; no installation attempted\n' > "$OUT/perf-unavailable.txt"
  fi
fi
printf 'Completed local native run: %s\n' "$OUT"
