	.attribute	4, 16
	.attribute	5, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_v1p0_zicsr2p0_zmmul1p0_zaamo1p0_zalrsc1p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0"
	.file	"copy.ll"
	.text
	.globl	candidate12_copy                # -- Begin function candidate12_copy
	.p2align	2
	.type	candidate12_copy,@function
	.variant_cc	candidate12_copy
candidate12_copy:                       # @candidate12_copy
	.cfi_startproc
# %bb.0:                                # %entry
	andi	a0, a0, 1
	beqz	a0, .LBB0_2
# %bb.1:                                # %then
	vsetvli	zero, a1, e64, m1, ta, ma
	vadd.vv	v8, v8, v9
	vse64.v	v8, (a2)
	vmv1r.v	v8, v10
	ret
.LBB0_2:                                # %else
	vsetivli	zero, 7, e32, m1, ta, ma
	vadd.vv	v8, v8, v9
	vse32.v	v8, (a2)
	vmv1r.v	v8, v10
	ret
.Lfunc_end0:
	.size	candidate12_copy, .Lfunc_end0-candidate12_copy
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
