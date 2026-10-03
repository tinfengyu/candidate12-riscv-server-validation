target triple = "riscv64"
declare <vscale x 1 x i64> @llvm.riscv.vadd.nxv1i64.nxv1i64(<vscale x 1 x i64>,<vscale x 1 x i64>,<vscale x 1 x i64>,i64)
declare <vscale x 1 x i64> @llvm.riscv.vsub.nxv1i64.nxv1i64(<vscale x 1 x i64>,<vscale x 1 x i64>,<vscale x 1 x i64>,i64)
declare void @llvm.riscv.vse.nxv1i64(<vscale x 1 x i64>,ptr,i64)
declare i64 @llvm.riscv.vmv.x.s.nxv1i64(<vscale x 1 x i64>)
define i64 @join_extract(<vscale x 1 x i64> %x,<vscale x 1 x i64> %y,i1 %cond,i64 %vl,ptr %p) {
entry:
 br i1 %cond,label %then,label %else
then:
 %a=call <vscale x 1 x i64> @llvm.riscv.vadd.nxv1i64.nxv1i64(<vscale x 1 x i64> poison,<vscale x 1 x i64> %x,<vscale x 1 x i64> %y,i64 %vl)
 call void @llvm.riscv.vse.nxv1i64(<vscale x 1 x i64> %a,ptr %p,i64 %vl)
 br label %join
else:
 %b=call <vscale x 1 x i64> @llvm.riscv.vsub.nxv1i64.nxv1i64(<vscale x 1 x i64> poison,<vscale x 1 x i64> %x,<vscale x 1 x i64> %y,i64 7)
 call void @llvm.riscv.vse.nxv1i64(<vscale x 1 x i64> %b,ptr %p,i64 7)
 br label %join
join:
 %v=phi <vscale x 1 x i64> [%a,%then],[%b,%else]
 %out=call i64 @llvm.riscv.vmv.x.s.nxv1i64(<vscale x 1 x i64> %v)
 ret i64 %out
}

