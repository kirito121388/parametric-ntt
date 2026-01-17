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

---

## 模乘模块详细说明

模乘模块（`ModMult.v`）是 NTT 运算的核心组件，负责计算 `(A * B) mod q`。该模块由两个主要子模块组成：整数乘法器（`intMult`）和模约减器（`ModRed`）。

### 模块层次结构

```
ModMult (模乘顶层模块)
├── intMult (整数乘法器)
│   ├── DSP 乘法单元 (16位分块乘法)
│   ├── CSA (进位保存加法器树)
│   │   └── FA (全加器)
│   └── 最终加法器
└── ModRed (模约减器)
    ├── ModRed_sub (约减子模块) × (L_SIZE-1)
    ├── ModRed_sub (最后一层约减)
    └── 最终比较减法器
```

### 1. ModMult - 模乘顶层模块

**文件**: `ModMult.v`

**功能**: 计算 `C = (A * B) mod q`

**接口说明**:

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | 输入 | 1 | 系统时钟 |
| `reset` | 输入 | 1 | 异步复位信号 |
| `A` | 输入 | DATA_SIZE_ARB | 被乘数 |
| `B` | 输入 | DATA_SIZE_ARB | 乘数 |
| `q` | 输入 | DATA_SIZE_ARB | 模数 |
| `C` | 输出 | DATA_SIZE_ARB | 模乘结果 `(A*B) mod q` |

**工作流程**:

```
A, B ──→ intMult ──→ P (2*DATA_SIZE_ARB 位) ──→ ModRed ──→ C
              │                                      │
              │    INTMUL_DELAY = 3 周期             │   MODRED_DELAY 周期
              └──────────────────────────────────────┘
                     总延迟 = INTMUL_DELAY + MODRED_DELAY
```

**延迟计算**:
- 整数乘法延迟：`INTMUL_DELAY = 3` 时钟周期
- 模约减延迟：`MODRED_DELAY = L_SIZE * 2 + 1` 时钟周期
- 总延迟：`3 + MODRED_DELAY` 时钟周期

---

### 2. intMult - 整数乘法器

**文件**: `intMult.v`

**功能**: 计算两个 `DATA_SIZE_ARB` 位整数的乘积，输出 `2*DATA_SIZE_ARB` 位结果

**设计原理**:

该模块采用分块乘法 + CSA 加法树的架构，将大位宽乘法分解为多个 16 位乘法，充分利用 FPGA 的 DSP 资源。

**工作流程**（3个时钟周期）:

#### 第1周期：分块乘法

```
┌─────────────────────────────────────────────────────┐
│  将 A 和 B 分解为 GENERIC 个 16 位块：              │
│                                                     │
│  A = A[GENERIC-1] | A[GENERIC-2] | ... | A[0]       │
│  B = B[GENERIC-1] | B[GENERIC-2] | ... | B[0]       │
│                                                     │
│  计算所有部分积（共 GENERIC × GENERIC 个）：        │
│  PP[i][j] = A[i] × B[j] << ((i+j) × 16)            │
└─────────────────────────────────────────────────────┘
```

- `GENERIC = 2^(DATA_SIZE_DEPTH - 4)` 表示需要多少个 16 位块
- 例如：当 `DATA_SIZE = 32` 时，`GENERIC = 2`，需要 4 个 DSP 乘法
- 使用 `(* use_dsp = "yes" *)` 综合属性确保使用 FPGA DSP 单元

#### 第2周期：CSA 加法树

```
┌─────────────────────────────────────────────────────┐
│  使用 CSA (进位保存加法器) 树结构压缩部分积：       │
│                                                     │
│  输入：GENERIC × GENERIC 个部分积                   │
│  输出：2 个中间结果 (C_out, S_out)                  │
│                                                     │
│  CSA 层数 = CSA_LEVEL = GENERIC × GENERIC - 2       │
│  每个 CSA 将 3 个数压缩为 2 个数（C 和 S）         │
└─────────────────────────────────────────────────────┘
```

CSA 树结构示意（以 4 个部分积为例）：

```
PP[0]  PP[1]  PP[2]  PP[3]
   \    |    /         |
    \   |   /          |
     CSA[0]            |
      /   \            |
     C0   S0           |
      \   |   \       /
       \  |    \     /
        CSA[1]  ────┘
         /   \
        C1   S1  ──→ 输出到下一周期
```

#### 第3周期：最终加法

```
┌─────────────────────────────────────────────────────┐
│  计算最终乘积：                                     │
│                                                     │
│  C = C_out + S_out                                  │
│                                                     │
│  输出 2*DATA_SIZE_ARB 位的完整乘积                  │
└─────────────────────────────────────────────────────┘
```

**特殊情况处理**:

当 `DATA_SIZE <= 16` 时（即数据位宽不超过 16 位），只需要 1 个 DSP 乘法单元（`GENERIC = 1`），此时：
- 只有 1 个部分积，无需 CSA 压缩
- `CSA_LEVEL = 0`（无 CSA 层）
- 直接输出 DSP 乘法结果作为最终乘积

---

### 3. CSA - 进位保存加法器

**文件**: `CSA.v`

**功能**: 将 3 个 `2*DATA_SIZE` 位的数压缩为 2 个数（进位 C 和和 S）

**设计原理**:

CSA 使用全加器（FA）并行处理每一位，避免进位传播延迟。

**工作原理**:

```
输入: x, y, z (各 2*DATA_SIZE 位)
输出: c (进位), s (和)

对于每一位 i：
  FA(x[i], y[i], z[i]) → (c_t[i], s_t[i])

输出处理：
  c[i+1] = c_t[i]  (进位左移一位)
  s[i] = s_t[i]
  c[0] = 0         (最低位进位为0)
```

**真值表**:

| x | y | z | c (进位) | s (和) |
|---|---|---|----------|--------|
| 0 | 0 | 0 | 0 | 0 |
| 0 | 0 | 1 | 0 | 1 |
| 0 | 1 | 0 | 0 | 1 |
| 0 | 1 | 1 | 1 | 0 |
| 1 | 0 | 0 | 0 | 1 |
| 1 | 0 | 1 | 1 | 0 |
| 1 | 1 | 0 | 1 | 0 |
| 1 | 1 | 1 | 1 | 1 |

**优势**:
- 无进位传播延迟，所有位并行计算
- 将 3 输入压缩为 2 输入，减少加法树深度
- 延迟仅为一个全加器延迟（组合逻辑）

---

### 4. FA - 全加器

**文件**: `FA.v`

**功能**: 计算三个 1 位输入的和

**实现**:

```verilog
assign {c, s} = x + y + z;
```

**接口**:

| 信号 | 方向 | 说明 |
|------|------|------|
| `x, y, z` | 输入 | 三个 1 位加数 |
| `c` | 输出 | 进位输出 |
| `s` | 输出 | 和输出 |

**逻辑表达式**:
- `s = x ⊕ y ⊕ z` (三输入异或)
- `c = (x & y) | (y & z) | (x & z)` (多数表决)

---

### 5. ModRed - 模约减器

**文件**: `ModRed.v`

**功能**: 将 `2*DATA_SIZE_ARB` 位的乘积约减到 `DATA_SIZE_ARB` 位（模 q）

**设计原理**:

利用 NTT 友好素数的特殊结构 `q = k × 2^W_SIZE + 1`，通过迭代约减算法高效计算模运算。

**工作流程**:

```
输入 P (2*DATA_SIZE_ARB 位)
        │
        ▼
┌───────────────────┐
│   ModRed_sub[0]   │  ──→  减少 (W_SIZE-1) 位
└───────────────────┘
        │
        ▼
┌───────────────────┐
│   ModRed_sub[1]   │  ──→  减少 (W_SIZE-1) 位
└───────────────────┘
        │
        ⋮ (共 L_SIZE 层)
        │
        ▼
┌───────────────────┐
│  ModRed_sub[L-1]  │  ──→  约减到 DATA_SIZE_ARB+2 位
└───────────────────┘
        │
        ▼
┌───────────────────┐
│   最终比较减法     │  ──→  如果 ≥ q 则减去 q
└───────────────────┘
        │
        ▼
输出 C (DATA_SIZE_ARB 位)
```

**迭代约减原理**:

每一层约减利用了以下数学关系：

```
设输入为 T1，分解为：T1 = T2H × 2^W_SIZE + T2L

其中：
- T2L = T1[W_SIZE-1:0]（低 W_SIZE 位）
- T2H = T1 >> W_SIZE（高位部分）

模约减的核心思想是利用模数 q 的特殊结构。
对于 NTT 友好素数，q 的低 W_SIZE 位接近 1。

设 q = qH × 2^W_SIZE + qL，其中 qL ≈ 1

则：2^W_SIZE ≡ (q - qL) / qH × (-1) + adjustment (mod q)

实际实现采用近似约减：
  T1 mod q ≈ qH × (-T2L) + T2H + CARRY

其中：
- (-T2L) 使用二进制补码表示
- CARRY 修正补码运算的误差
- 结果可能略大于 q，需要最终减法修正
```

---

### 6. ModRed_sub - 模约减子模块

**文件**: `ModRed_sub.v`

**功能**: 执行一层模约减操作，将输入位宽减少 `W_SIZE-1` 位

**参数**:

| 参数 | 说明 |
|------|------|
| `CURR_DATA` | 当前层输入数据位宽 |
| `NEXT_DATA` | 下一层输出数据位宽 |

**接口**:

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | 输入 | 1 | 时钟 |
| `reset` | 输入 | 1 | 复位 |
| `qH` | 输入 | DATA_SIZE_ARB - W_SIZE | 模数 q 的高位部分 |
| `T1` | 输入 | CURR_DATA | 当前层输入 |
| `C` | 输出 | NEXT_DATA | 约减后的输出 |

**工作流程**（2个时钟周期）:

#### 第1周期：乘法和数据准备

```verilog
// 组合逻辑部分
T2L = T1[W_SIZE-1:0];      // 取低 W_SIZE 位
T2  = -T2L;                 // 取补码（二进制补码）

// 时序逻辑部分（上升沿触发）
T2H   <= T1 >> W_SIZE;      // 高位部分（右移 W_SIZE 位）
CARRY <= (T2L[W_SIZE-1] | T2[W_SIZE-1]);  // 进位标志
MULT  <= qH * T2;           // DSP 乘法：qH × (-T2L)
```

**进位计算原理**:

```
CARRY = T2L[W_SIZE-1] | T2[W_SIZE-1]

进位标志用于修正补码运算：
- T2L[W_SIZE-1]：原始低位数据的最高位
- T2[W_SIZE-1]：补码后数据的最高位
- 当任一为 1 时，表示数值范围需要调整
- 这确保了约减过程中的数值正确性
```

#### 第2周期：加法

```verilog
C <= (MULT + T2H) + CARRY;
```

**数据流图**:

```
                T1 (CURR_DATA 位)
                      │
         ┌────────────┴────────────┐
         │                         │
    [W_SIZE-1:0]            [CURR_DATA-1:W_SIZE]
         │                         │
         ▼                         ▼
        T2L ─────────────────→   T2H
         │                         │
         ▼                         │
   -T2L (补码)                     │
         │                         │
         ▼                         │
      qH × T2 ─────→ MULT          │
         │             │           │
         │             ▼           ▼
         │       ┌─────────────────┐
         │       │ (MULT + T2H)    │
         │       └────────┬────────┘
         │                │
         └──→ CARRY ──────┤
                          ▼
                    C (NEXT_DATA 位)
```

---

### 7. 最终比较减法

**位置**: `ModRed.v` 第 54-73 行

**功能**: 确保最终结果小于模数 q

**实现**:

```verilog
// 扩展结果
C_ext  = C_reg[L_SIZE][DATA_SIZE_ARB+1:0];
// 尝试减去 q
C_temp = C_ext - q;

// 根据符号位判断
if (C_temp[DATA_SIZE_ARB+1])  // 如果结果为负（最高位为1）
    C <= C_ext;                // 输出原值
else
    C <= C_temp[DATA_SIZE_ARB-1:0];  // 输出减法结果
```

**原理**:

由于迭代约减可能产生略大于 q 的结果，需要最终检查：
- 如果 `C_ext >= q`，则输出 `C_ext - q`
- 如果 `C_ext < q`，则直接输出 `C_ext`

---

### 时序图

以 `L_SIZE = 2` 为例，模乘操作的完整时序：

```
时钟周期:  1     2     3     4     5     6     7     8
           │     │     │     │     │     │     │     │
intMult:   │DSP乘│ CSA │C+S加│     │     │     │     │
           │     │     │  法 │     │     │     │     │
           └─────┴─────┴──┬──┘     │     │     │     │
                          │ P      │     │     │     │
ModRed:                   ▼        │     │     │     │
  Sub[0]:                 │ 乘法   │加法 │     │     │
                          └────────┴──┬──┘     │     │
                                      │        │     │
  Sub[1]:                             │ 乘法   │加法 │
                                      └────────┴──┬──┘
                                                  │
  比较减法:                                       │最终│
                                                  └──┬─┘
                                                     │
输出 C:                                              ▼
```

**总延迟**: `INTMUL_DELAY + MODRED_DELAY = 3 + (2×2+1) = 8` 时钟周期

---

### 面积与性能权衡

| 参数 | 对面积的影响 | 对性能的影响 |
|------|-------------|-------------|
| `DATA_SIZE_ARB` ↑ | DSP 数量增加（见下文） | 延迟增加 (L_SIZE 增加) |
| `RING_SIZE` ↑ | W_SIZE 增加，可能减少 L_SIZE | 可能减少延迟 |
| `PE_NUMBER` ↑ | 面积线性增加 | 吞吐量线性增加 |

**DSP 数量计算**:

```
DATA_SIZE = 2^(clog2(DATA_SIZE_ARB))  // 向上取整到2的幂次方
DATA_SIZE_DEPTH = clog2(DATA_SIZE)
GENERIC = 2^(DATA_SIZE_DEPTH - 4) = DATA_SIZE / 16

DSP 数量 = GENERIC × GENERIC = (DATA_SIZE / 16)²

示例：
- DATA_SIZE_ARB = 14 → DATA_SIZE = 16 → GENERIC = 1 → 1 个 DSP
- DATA_SIZE_ARB = 17 → DATA_SIZE = 32 → GENERIC = 2 → 4 个 DSP
- DATA_SIZE_ARB = 33 → DATA_SIZE = 64 → GENERIC = 4 → 16 个 DSP
```

### 设计优化点

1. **DSP 复用**: 使用 `(* use_dsp = "yes" *)` 属性确保乘法映射到 FPGA DSP 单元
2. **CSA 树**: 减少加法延迟，避免长进位链
3. **流水线设计**: 每个子模块独立寄存，支持高频运行
4. **NTT 友好素数**: 利用特殊模数结构简化模约减运算
