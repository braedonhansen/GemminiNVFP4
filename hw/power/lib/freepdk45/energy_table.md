| Bank | bits | leakage (uW) | write E (pJ) | read E (pJ) | write pJ/bit | read pJ/bit | leak nW/bit |
|---|---|---|---|---|---|---|---|
| bk_1rw_256x128_ws8 | 32768 | 33.59 | 48.87 | 48.87 | 0.382 | 0.382 | 1.025 |
| bk_1w1r_64x512_ws8 | 32768 | 34.22 | 96.28 | 96.28 | 0.188 | 0.188 | 1.044 |
| bk_1w1r_256x128_ws8 | 32768 | 34.22 | 84.78 | 84.78 | 0.662 | 0.662 | 1.044 |
| bk_1w1r_64x512_ws256 | 32768 | 34.04 | 95.98 | 95.98 | 0.187 | 0.187 | 1.039 |
| bk_1w1r_128x128_nomask | 16384 | 17.78 | 46.12 | 46.12 | 0.360 | 0.360 | 1.085 |

| Design | Macro (ext) | Shape | Ports | Mask | Banks (deep x wide) | Instances | write E (pJ) | read E (pJ) | leakage / instance (uW) | leakage total (uW) | derived |
|---|---|---|---|---|---|---|---|---|---|---|---|
| int8 | mem_ext | 4096x128 | 1RW | 8 | 16x1 | 4 | 48.9 | 48.9 | 537.4 | 2149.7 | no |
| int8 | mem_0_ext | 512x512 | 1W+1R | 8 | 8x1 | 2 | 96.3 | 96.3 | 273.8 | 547.5 | no |
| int8 | **total SRAM leakage** | | | | | | | | | **2697.2** | |
| mxfp4 | mem_ext | 4096x128 | 1W+1R | 8 | 16x1 | 4 | 84.8 | 84.8 | 547.6 | 2190.3 | no |
| mxfp4 | banks_0_ext | 256x512 | 1W+1R | 256 | 4x1 | 4 | 96.0 | 96.0 | 136.1 | 544.6 | no |
| mxfp4 | banks_0_0_ext | 128x128 | 1W+1R | - | 1x1 | 8 | 46.1 | 46.1 | 17.8 | 142.2 | no |
| mxfp4 | **total SRAM leakage** | | | | | | | | | **2877.1** | |
| nvfp4 | mem_ext | 4096x128 | 1W+1R | 8 | 16x1 | 4 | 84.8 | 84.8 | 547.6 | 2190.3 | no |
| nvfp4 | banks_0_ext | 256x1024 | 1W+1R | 256 | 4x2 | 4 | 192.0 | 192.0 | 272.3 | 1089.1 | no |
| nvfp4 | banks_0_0_ext | 128x128 | 1W+1R | - | 1x1 | 8 | 46.1 | 46.1 | 17.8 | 142.2 | no |
| nvfp4 | **total SRAM leakage** | | | | | | | | | **3421.6** | |
| mxfp8 | mem_ext | 4096x128 | 1W+1R | 8 | 16x1 | 4 | 84.8 | 84.8 | 547.6 | 2190.3 | yes |
| mxfp8 | banks_0_ext | 256x512 | 1W+1R | 256 | 4x1 | 4 | 96.0 | 96.0 | 136.1 | 544.6 | yes |
| mxfp8 | banks_0_0_ext | 128x128 | 1W+1R | - | 1x1 | 8 | 46.1 | 46.1 | 17.8 | 142.2 | yes |
| mxfp8 | **total SRAM leakage** | | | | | | | | | **2877.1** | |
| fp32 | mem_ext | 4096x128 | 1RW | 8 | 16x1 | 4 | 48.9 | 48.9 | 537.4 | 2149.7 | yes |
| fp32 | mem_0_ext | 4096x128 | 1W+1R | 8 | 16x1 | 1 | 84.8 | 84.8 | 547.6 | 547.6 | yes |
| fp32 | **total SRAM leakage** | | | | | | | | | **2697.3** | |
