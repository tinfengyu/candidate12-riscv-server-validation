/* Scalar ABI adapters only. Candidate kernels are unchanged compiler objects. */
.text
.p2align 2
.globl c12_run_extract
.type c12_run_extract,@function
c12_run_extract:
  addi sp, sp, -16
  sd ra, 8(sp)
  vsetvli t0, zero, e8, m1, ta, ma
  vl1re8.v v8, (a0)
  vl1re8.v v9, (a1)
  mv a0, a2
  mv a1, a3
  mv a2, a4
  call candidate12_extract
  ld ra, 8(sp)
  addi sp, sp, 16
  ret
.size c12_run_extract,.-c12_run_extract

.globl c12_run_copy
.type c12_run_copy,@function
c12_run_copy:
  addi sp, sp, -16
  sd ra, 8(sp)
  sd a6, 0(sp)
  vsetvli t0, zero, e8, m1, ta, ma
  vl1re8.v v8, (a0)
  vl1re8.v v9, (a1)
  vl1re8.v v10, (a2)
  mv a0, a3
  mv a1, a4
  mv a2, a5
  call candidate12_copy
  ld t0, 0(sp)
  vs1r.v v8, (t0)
  ld ra, 8(sp)
  addi sp, sp, 16
  ret
.size c12_run_copy,.-c12_run_copy

.globl c12_vlen_bytes
.type c12_vlen_bytes,@function
c12_vlen_bytes:
  csrr a0, vlenb
  ret
.size c12_vlen_bytes,.-c12_vlen_bytes

.globl c12_vl64
.type c12_vl64,@function
c12_vl64:
  vsetvli a0, a0, e64, m1, ta, ma
  ret
.size c12_vl64,.-c12_vl64

.globl c12_vl32
.type c12_vl32,@function
c12_vl32:
  vsetvli a0, a0, e32, m1, ta, ma
  ret
.size c12_vl32,.-c12_vl32
.section .note.GNU-stack,"",@progbits
