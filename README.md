# Parametric NTT/INTT Hardware

This repository provides the baseline version of Verilog code for parametric NTT/INTT hardware published in "<a href="https://ieeexplore.ieee.org/document/9171507">An Extensive Study of Flexible Design Methods for the Number Theoretic Transform</a>".

You have to set three parameters defined in `defines.v`:
* `DATA_SIZE_ARB`: bit-size of coefficient modulus *q* (constrained to the values between 8-64 for practical implementations)
* `RING_SIZE`: degree of ring polynomial, namely *n* in *x^n+1* (needs to be a power of 2)
* `PE_NUMBER`: number of processing elements (*butterfly units*) (needs to be a power of 2 and `PE_NUMBER` <= `RING_SIZE`/2)

Other versions of the hardware generator and documentation will be available soon.

If you use this work in your research/study, please cite our work:

```
@ARTICLE{9171507,
  author={A. C. {Mert} and E. {Karabulut} and E. {Ozturk} and E. {Savas} and A. {Aysu}},
  journal={IEEE Transactions on Computers}, 
  title={An Extensive Study of Flexible Design Methods for the Number Theoretic Transform}, 
  year={2020},
  volume={},
  number={},
  pages={1-1},
  doi={10.1109/TC.2020.3017930}}
```

---

## defines.v 参数详细说明 (中文)

`defines.v` 文件包含了 NTT 硬件的所有配置参数。以下是每个参数的详细解释：

### 用户可配置参数

| 参数 | 默认值 | 含义 |
|------|--------|------|
| `DATA_SIZE_ARB` | 14 | 系数模数 *q* 的位宽 (K)，决定了多项式系数的精度。取值范围：8-64位。 |
| `RING_SIZE` | 512 | 多项式环的度数 *n*，即 *x^n+1* 中的 *n*。必须是2的幂次方。 |
| `PE_NUMBER` | 1 | 处理单元（蝴蝶运算单元）的数量 (B)。必须是2的幂次方，且 `PE_NUMBER` ≤ `RING_SIZE`/2。 |

### 整数乘法相关参数（自动计算）

| 参数 | 计算公式 | 含义 |
|------|----------|------|
| `DATA_SIZE` | `1 << clog2(DATA_SIZE_ARB)` | 数据位宽，向上取整到2的幂次方。 |
| `DATA_SIZE_DEPTH` | `clog2(DATA_SIZE)` | 数据位宽的深度（log2值）。 |
| `GENERIC` | `1 << (DATA_SIZE_DEPTH - 4)` | 通用乘法器的分块大小。 |
| `CSA_LEVEL` | 根据DATA_SIZE计算 | 进位保存加法器(CSA)的层数，用于优化乘法运算。 |
| `INTMUL_DELAY` | 3 | 整数乘法器的延迟周期数。 |

### 模约减相关参数（自动计算）

| 参数 | 计算公式 | 含义 |
|------|----------|------|
| `RING_DEPTH` | `clog2(RING_SIZE)` | 多项式环深度（log2值）。 |
| `W_SIZE` | RING_DEPTH + 1 | 字（word）的大小。 |
| `L_SIZE` | `ceil(DATA_SIZE_ARB / W_SIZE)` | 模约减需要的层数。 |
| `MODRED_DELAY` | `L_SIZE * 2 + 1` | 模约减操作的延迟周期数。 |

### 系统参数（自动计算）

| 参数 | 计算公式 | 含义 |
|------|----------|------|
| `PE_DEPTH` | `clog2(PE_NUMBER)` | 处理单元数量的深度（log2值）。 |
| `STAGE_DELAY` | 5 | 每个NTT阶段的延迟周期数。 |
| `R` | `W_SIZE * L_SIZE` | 扩展后的数据位宽。 |

### 参数使用示例

如果您想实现一个支持 Kyber-512 的 NTT 硬件：

```verilog
`define DATA_SIZE_ARB   12    // Kyber使用12位系数模数 q=3329
`define RING_SIZE       256   // Kyber多项式度数 n=256
`define PE_NUMBER       4     // 使用4个蝴蝶单元并行处理
```

如果您想实现支持 Dilithium 的 NTT 硬件：

```verilog
`define DATA_SIZE_ARB   23    // Dilithium使用23位系数模数 q=8380417
`define RING_SIZE       256   // Dilithium多项式度数 n=256
`define PE_NUMBER       8     // 使用8个蝴蝶单元并行处理
```

### 注意事项

1. **DATA_SIZE_ARB**: 取值需要在8-64位之间，这是模约减算法的约束。
2. **RING_SIZE**: 必须是2的幂次方（如128, 256, 512, 1024等）。
3. **PE_NUMBER**: 增加处理单元可以提高吞吐量，但会增加面积开销。必须满足 `PE_NUMBER ≤ RING_SIZE/2`。
