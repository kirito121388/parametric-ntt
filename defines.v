/*
Copyright 2020, Ahmet Can Mert <ahmetcanmert@sabanciuniv.edu>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

`timescale 1 ns / 1 ps

// ------------------------------------------------
// User parameters (CONFIGURE THESE)
// ------------------------------------------------
// These are the three main parameters that users need to configure
// for their specific NTT/INTT hardware requirements.

// `DATA_SIZE_ARB (K): Arbitrary data size in bits
//   - Represents the bit-size of the coefficient modulus q
//   - Constrained to values between 8-64 bits for practical implementations
//   - This determines the precision of arithmetic operations
//   - Example: For a 14-bit modulus, set to 14
`define DATA_SIZE_ARB   14

// `RING_SIZE (n): Ring polynomial degree
//   - Degree of the ring polynomial in x^n+1
//   - Must be a power of 2 (e.g., 256, 512, 1024, 2048)
//   - Determines the number of coefficients in the polynomial
//   - Larger values increase security but require more resources
`define RING_SIZE       512

// `PE_NUMBER (B): Number of Processing Elements (butterfly units)
//   - Number of parallel butterfly units for computation
//   - Must be a power of 2 (e.g., 1, 2, 4, 8, 16)
//   - Must satisfy: PE_NUMBER <= RING_SIZE/2
//     (Each butterfly processes 2 inputs, so maximum parallelism is RING_SIZE/2)
//   - Higher values increase throughput but consume more area
`define PE_NUMBER       1

// ------------------------------------------------
// Parameters for integer multiplication (AUTO-COMPUTED)
// ------------------------------------------------
// These parameters are automatically derived from DATA_SIZE_ARB
// and configure the integer multiplier architecture.

// `DATA_SIZE: Rounded-up power-of-2 data size
//   - Rounds DATA_SIZE_ARB up to the nearest power of 2
//   - Used for simplifying hardware design and addressing
//   - Example: If DATA_SIZE_ARB=14, then DATA_SIZE=16
`define DATA_SIZE       (1 << ($clog2(`DATA_SIZE_ARB)))

// `DATA_SIZE_DEPTH: Log2 of DATA_SIZE
//   - Calculates log2(DATA_SIZE)
//   - Used for determining hierarchy depth in multiplier tree
//   - Example: If DATA_SIZE=16, then DATA_SIZE_DEPTH=4
`define DATA_SIZE_DEPTH ($clog2(`DATA_SIZE))

// `GENERIC: Generic parameter for CSA tree structure
//   - Computed as 2^(DATA_SIZE_DEPTH - 4)
//   - Used to determine the structure of Carry-Save Adder (CSA) tree
//   - Helps organize partial products in the multiplier
`define GENERIC         (1 << (`DATA_SIZE_DEPTH - 4))

// `CSA_LEVEL: Number of CSA levels in multiplier
//   - For DATA_SIZE > 16: GENERIC*GENERIC-2 levels
//   - For DATA_SIZE <= 16: 0 (uses simpler multiplication)
//   - Determines the depth of the CSA tree for partial product reduction
`define CSA_LEVEL       ((`DATA_SIZE > 16) ? (`GENERIC*`GENERIC-2) : 0)

// `INTMUL_DELAY: Integer multiplication pipeline delay
//   - Fixed at 3 clock cycles
//   - Represents the latency of the integer multiplier pipeline
//   - Used for timing analysis and pipeline synchronization
`define INTMUL_DELAY    3

// ------------------------------------------------
// Parameters for modular reduction (AUTO-COMPUTED)
// ------------------------------------------------
// Works for K (DATA_SIZE_ARB) between 8-bit to 64-bit
// (Practical range: 9-64 bits for optimal Barrett reduction performance)
// These parameters configure the Barrett modular reduction unit.

// `RING_DEPTH: Log2 of RING_SIZE
//   - Calculates log2(RING_SIZE)
//   - Used for address generation and indexing
//   - Example: If RING_SIZE=512, then RING_DEPTH=9
`define RING_DEPTH      ($clog2(`RING_SIZE))

// `W_SIZE: Word size for Barrett reduction
//   - Computed as RING_DEPTH + 1
//   - Represents the bit-width of each word in multi-word arithmetic
//   - Used to split large numbers into manageable chunks
//   - Example: If RING_DEPTH=9, then W_SIZE=10
`define W_SIZE          ((`RING_DEPTH)+1)

// `L_SIZE: Number of words for Barrett reduction
//   - Calculates how many W_SIZE words are needed to represent DATA_SIZE_ARB bits
//   - Implements conditional approximation of ceil(DATA_SIZE_ARB / W_SIZE) via nested ternary
//   - Returns value from 1 to 8 (upper bound of 8) based on comparison thresholds
//   - Used to determine the multi-precision arithmetic structure
//   - Example: If DATA_SIZE_ARB=14 and W_SIZE=10, then L_SIZE=2
`define L_SIZE          ((`DATA_SIZE_ARB > `W_SIZE) ? ((`DATA_SIZE_ARB > (`W_SIZE * 2)) ? ((`DATA_SIZE_ARB > (`W_SIZE * 3)) ? ((`DATA_SIZE_ARB > (`W_SIZE * 4)) ? ((`DATA_SIZE_ARB > (`W_SIZE * 5)) ? ((`DATA_SIZE_ARB > (`W_SIZE * 6)) ? ((`DATA_SIZE_ARB > (`W_SIZE * 7)) ? 8 : 7) : 6) : 5) : 4) : 3) : 2) : 1)

// Alternative formulations (commented out, kept for reference):
// `define W_SIZE       ($rtoi((`RING_DEPTH)+1))
// `define L_SIZE       ($rtoi($ceil((`DATA_SIZE_ARB*1.0)/(`W_SIZE*1.0))))

// `MODRED_DELAY: Modular reduction pipeline delay
//   - Computed as L_SIZE * 2 + 1 clock cycles
//   - Represents the latency of the modular reduction pipeline
//   - Increases with L_SIZE as more words require more processing stages
//   - Example: If L_SIZE=2, then MODRED_DELAY=5
`define MODRED_DELAY    ((`L_SIZE)*2 + 1)

// ------------------------------------------------
// System parameters (AUTO-COMPUTED)
// ------------------------------------------------
// These parameters define overall system timing and configuration.

// `PE_DEPTH: Log2 of PE_NUMBER
//   - Calculates log2(PE_NUMBER)
//   - Used for PE addressing and control logic
//   - Example: If PE_NUMBER=1, then PE_DEPTH=0
`define PE_DEPTH        ($clog2(`PE_NUMBER))

// `STAGE_DELAY: NTT stage pipeline delay
//   - Fixed at 5 clock cycles per NTT stage
//   - Represents the latency through one butterfly stage
//   - Used for overall NTT timing calculations
`define STAGE_DELAY     5

// `R: Total bit-width for Barrett reduction
//   - Computed as W_SIZE * L_SIZE
//   - Represents the total number of bits used in multi-word representation
//   - Should be >= DATA_SIZE_ARB to ensure sufficient precision
//   - Example: If W_SIZE=10 and L_SIZE=2, then R=20
`define R               ($rtoi(`W_SIZE * `L_SIZE))

// ------------------------------------------------
