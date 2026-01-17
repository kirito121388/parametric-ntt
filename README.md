# Parametric NTT/INTT Hardware

This repository provides the baseline version of Verilog code for parametric NTT/INTT hardware published in "<a href="https://ieeexplore.ieee.org/document/9171507">An Extensive Study of Flexible Design Methods for the Number Theoretic Transform</a>".

## Configuration Parameters

You have to set three parameters defined in `defines.v`:

### User-Configurable Parameters

* **`DATA_SIZE_ARB`** (K): Bit-size of coefficient modulus *q*
  * Constrained to values between 8-64 for practical implementations
  * Determines the precision of arithmetic operations
  * Example: For a 14-bit modulus, set to 14

* **`RING_SIZE`** (n): Degree of ring polynomial, namely *n* in *x^n+1*
  * Needs to be a power of 2 (e.g., 256, 512, 1024, 2048)
  * Determines the number of coefficients in the polynomial
  * Larger values increase security but require more hardware resources

* **`PE_NUMBER`** (B): Number of processing elements (*butterfly units*)
  * Needs to be a power of 2 (e.g., 1, 2, 4, 8, 16)
  * Must satisfy: `PE_NUMBER` ≤ `RING_SIZE`/2
  * Higher values increase throughput but consume more area
  * Trade-off between latency and area

### Auto-Computed Parameters

All other parameters in `defines.v` are automatically derived from the three user parameters above:

#### Integer Multiplication Parameters
* **`DATA_SIZE`**: DATA_SIZE_ARB rounded up to nearest power of 2
* **`DATA_SIZE_DEPTH`**: log₂(DATA_SIZE)
* **`GENERIC`**: CSA tree structure parameter = 2^(DATA_SIZE_DEPTH - 4)
* **`CSA_LEVEL`**: Number of Carry-Save Adder levels in the multiplier
* **`INTMUL_DELAY`**: Integer multiplier pipeline latency (3 cycles)

#### Modular Reduction Parameters (Barrett Reduction)
* **`RING_DEPTH`**: log₂(RING_SIZE)
* **`W_SIZE`**: Word size for multi-precision arithmetic = RING_DEPTH + 1
* **`L_SIZE`**: Number of words needed (conditional approximation of ⌈DATA_SIZE_ARB / W_SIZE⌉)
* **`MODRED_DELAY`**: Modular reduction pipeline latency = L_SIZE × 2 + 1

#### System Parameters
* **`PE_DEPTH`**: log₂(PE_NUMBER)
* **`STAGE_DELAY`**: NTT stage pipeline delay (5 cycles)
* **`R`**: Total bit-width for Barrett reduction = W_SIZE × L_SIZE

For detailed explanations of each parameter, see the comments in `defines.v`.

## Usage Notes

Other versions of the hardware generator and documentation will be available soon.

## Citation

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
