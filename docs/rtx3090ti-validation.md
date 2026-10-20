# RTX 3090 Ti validation

Code changes, review and result analysis: **GPT-6.1 Sol (Codex)**.
Measurements were collected on physical hardware.

An RTX 3090 was successfully unlocked and benchmarked first. The same unlock
sequence was then applied to an RTX 3090 Ti and tested.

Dense cuBLAS GEMM, `M=N=K=8192`, FP32 accumulation/output, 450 W limit;
medians of five samples:

| Input | Before (TFLOPS) | After (TFLOPS) |
|---|---:|---:|
| FP16 | 87.46 | 118.39 |
| BF16 | 87.50 | 157.41 |
| TF32 | 42.58 | 82.61 |

The Ti benchmark used Ubuntu kernel `7.0.0-38-generic`, a modified NVIDIA
`610.43.02` driver and a custom pre-udev initramfs hook. Both models were later
unlocked together with runtime device detection; CUDA FP16/BF16 checks passed
and no Xid was observed. These hardware results precede this final minimal
source cleanup. Other boards and packaged boot integration remain unvalidated.
