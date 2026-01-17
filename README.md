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
| `DATA_SIZE_ARB` | 14 | 系数模数 *q* 的位宽 (K)，决定了多项式系数的精度。取值范围：9-64位。 |
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

#### 模约减参数详细说明

模约减（Modular Reduction）是 NTT 运算中的关键步骤，用于将乘法结果约减到模数 *q* 范围内。该模块采用了一种高效的迭代约减算法。

**1. `RING_DEPTH` - 多项式环深度**

```
RING_DEPTH = clog2(RING_SIZE)
```

- **作用**：表示多项式环大小的二进制位数
- **示例**：当 `RING_SIZE = 512` 时，`RING_DEPTH = log2(512) = 9`
- **意义**：决定了 NTT 变换需要的阶段数，也影响 twiddle factor（旋转因子）的存储和寻址

**2. `W_SIZE` - 字大小（Word Size）**

```
W_SIZE = RING_DEPTH + 1
```

- **作用**：定义模约减中每个处理单元的字长
- **来源**：由于 NTT 中的素数模数 *q* 通常满足 `q = k * n + 1` 的形式（其中 `n = RING_SIZE`），模数的最低 `RING_DEPTH + 1` 位具有特殊结构
- **示例**：当 `RING_SIZE = 512` 时，`W_SIZE = 9 + 1 = 10` 位
- **意义**：这个参数利用了 NTT 友好素数的特性，使得模约减可以通过简单的移位和乘法来实现

**3. `L_SIZE` - 约减层数（Reduction Levels）**

```
L_SIZE = ceil(DATA_SIZE_ARB / W_SIZE)
```

- **作用**：决定模约减需要多少次迭代才能完成
- **计算逻辑**：输入数据（2 * DATA_SIZE_ARB 位的乘法结果）需要被分成多少个 W_SIZE 位的块来处理
- **示例**：
  - 当 `DATA_SIZE_ARB = 14`，`W_SIZE = 10` 时：`L_SIZE = ceil(14/10) = 2`
  - 当 `DATA_SIZE_ARB = 23`，`W_SIZE = 9` 时：`L_SIZE = ceil(23/9) = 3`
- **意义**：
  - `L_SIZE` 越大，模约减需要更多的硬件资源和时钟周期
  - 每一层都包含一个 `ModRed_sub` 子模块，执行 `qH * T2 + T2H + CARRY` 运算

**4. `MODRED_DELAY` - 模约减延迟**

```
MODRED_DELAY = L_SIZE * 2 + 1
```

- **作用**：模约减操作从输入到输出的总时钟周期数
- **计算逻辑**：
  - 每层 `ModRed_sub` 需要 2 个时钟周期（1 个用于乘法，1 个用于加法）
  - 最后还需要 1 个时钟周期进行最终比较和输出
- **示例**：当 `L_SIZE = 2` 时，`MODRED_DELAY = 2 * 2 + 1 = 5` 个时钟周期
- **意义**：用于流水线设计，确保数据在正确的时钟周期被采样

**5. `R` - 扩展数据位宽**

```
R = W_SIZE * L_SIZE
```

- **作用**：表示扩展后的数据总位宽
- **意义**：由于 `L_SIZE` 是向上取整得到的，`R` 可能会大于原始的 `DATA_SIZE_ARB`，表示实际用于计算的总位数

#### 模约减工作原理

模约减模块 (`ModRed.v`) 的工作流程如下：

1. **输入**：接收 `2 * DATA_SIZE_ARB` 位的乘法结果 `P`
2. **迭代约减**：通过 `L_SIZE - 1` 个 `ModRed_sub` 子模块逐步约减数据宽度
3. **最后一层**：特殊处理，将数据约减到 `DATA_SIZE_ARB + 2` 位
4. **最终减法**：如果结果仍大于 *q*，则减去 *q*
5. **输出**：`DATA_SIZE_ARB` 位的约减结果 `C`

每个 `ModRed_sub` 子模块执行以下操作：
```
T2 = -T1[W_SIZE-1:0]           // 取低 W_SIZE 位并取补码（negation）
T2H = T1 >> W_SIZE             // 高位部分
MULT = qH * T2                 // qH 是 q 的高位部分
C = (MULT + T2H) + CARRY       // 最终加法
```

#### 参数约束

- `DATA_SIZE_ARB` 取值范围：9-64 位（由代码注释说明）
- `W_SIZE` 的大小直接影响乘法器的规模：乘法器大小为 `(DATA_SIZE_ARB - W_SIZE) * W_SIZE` 位
- `L_SIZE` 最大为 8（由 `defines.v` 中的嵌套三元表达式限制）

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

1. **DATA_SIZE_ARB**: 取值需要在9-64位之间，这是模约减算法的约束。
2. **RING_SIZE**: 必须是2的幂次方（如128, 256, 512, 1024等）。
3. **PE_NUMBER**: 增加处理单元可以提高吞吐量，但会增加面积开销。必须满足 `PE_NUMBER ≤ RING_SIZE/2`。
