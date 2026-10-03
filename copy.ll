target triple = "riscv64"
declare <vscale x 1 x i64> @llvm.riscv.vadd.nxv1i64.nxv1i64(<vscale x 1 x i64>,<vscale x 1 x i64>,<vscale x 1 x i64>,i64)
declare <vscale x 2 x i32> @llvm.riscv.vadd.nxv2i32.nxv2i32(<vscale x 2 x i32>,<vscale x 2 x i32>,<vscale x 2 x i32>,i64)
declare void @llvm.riscv.vse.nxv1i64(<vscale x 1 x i64>,ptr,i64)
declare void @llvm.riscv.vse.nxv2i32(<vscale x 2 x i32>,ptr,i64)
define <vscale x 1 x i64> @candidate12_copy(<vscale x 1 x i64> %x, <vscale x 1 x i64> %y, <vscale x 1 x i64> %z, i1 %cond, i64 %vl, ptr %p) {
entry:
 br i1 %cond,label %then,label %else
then:
 %a=call <vscale x 1 x i64> @llvm.riscv.vadd.nxv1i64.nxv1i64(<vscale x 1 x i64> poison,<vscale x 1 x i64> %x,<vscale x 1 x i64> %y,i64 %vl)
 call void @llvm.riscv.vse.nxv1i64(<vscale x 1 x i64> %a,ptr %p,i64 %vl)
 br label %join
else:
 %xx=bitcast <vscale x 1 x i64> %x to <vscale x 2 x i32>
 %yy=bitcast <vscale x 1 x i64> %y to <vscale x 2 x i32>
 %b=call <vscale x 2 x i32> @llvm.riscv.vadd.nxv2i32.nxv2i32(<vscale x 2 x i32> poison,<vscale x 2 x i32> %xx,<vscale x 2 x i32> %yy,i64 7)
 call void @llvm.riscv.vse.nxv2i32(<vscale x 2 x i32> %b,ptr %p,i64 7)
 br label %join
join:
 ret <vscale x 1 x i64> %z
}

