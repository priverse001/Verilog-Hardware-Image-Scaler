# Hardware Image Scaler in Verilog

[![Language: Verilog](https://img.shields.io/badge/Language-Verilog_2001-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Design: FSM Controlled](https://img.shields.io/badge/Architecture-FSM_Sequential-success.svg)](#architecture)
[![Arithmetic: Fixed--Point](https://img.shields.io/badge/Arithmetic-Fixed--Point_8--bit-orange.svg)](#mathematical-formulation)

A behaviorally verified **Hardware Image Scaler** designed in Verilog HDL, with a synthesizable FSM-controlled datapath. The core engine uses a **Finite State Machine (FSM)** architecture and **Bilinear Interpolation** with 8-bit fractional fixed-point arithmetic to resize digital images while minimizing hardware resource utilization. File I/O and memory initialization use simulation-only system tasks (`$readmemh`, `$fopen`) for testbench verification purposes.

---

## Key Features

- **Area-Optimized Sequential Architecture**: Processes images pixel-by-pixel using a Finite State Machine (FSM) rather than full-frame parallel replication, significantly reducing hardware footprint.
- **Bilinear Interpolation Engine**: Computes smooth color blends across a $2 \times 2$ pixel window ($I_{00}, I_{10}, I_{01}, I_{11}$) for high-fidelity image scaling.
- **Fixed-Point Arithmetic**: Avoids expensive floating-point hardware units by scaling coordinates with an 8-bit fractional shift (`<< 8` / `>>> 8`), achieving fast single-cycle division via truncation.
- **Channel-Wise Datapath Reuse**: Processes Red, Green, and Blue channels sequentially through a single shared interpolation block to conserve FPGA DSP slices and lookup tables (LUTs).

---

## Repository Structure

```text
Verilog-Hardware-Image-Scaler/
├── rtl/
│   └── image_scaler.v          # FSM-controlled RTL datapath (synthesizable core + simulation I/O)
├── tb/
│   └── tb_image_scaler.v       # Simulation testbench verifying scaler execution
├── .gitignore                  # Git ignore rules for Vivado and FPGA build files
└── README.md                   # Technical documentation and project overview
```

---

## System Architecture & FSM

The controller operates across seven distinct states to orchestrate memory fetch, coordinate conversion, horizontal/vertical interpolation, and boundary saturation:

```text
       +----------+
       |   IDLE   | <------------------------------------+
       +----------+                                      |
            |                                            |
      start | asserted                                   |
            v                                            |
    +---------------+        +---------------+           |
+-> |  CALC_COORDS  | -----> |  FETCH_DATA   |           |
|   +---------------+        +---------------+           |
|                                    |                   |
|                                    v                   |
|                            +---------------+           |
|                            |   INTERP_X    |           |
|                            +---------------+           |
|                                    |                   |
|                                    v                   |
|                            +---------------+           |
|                            |   INTERP_Y    |           |
|                            +---------------+           |
|                                    |                   |
|                                    v                   |
|                            +---------------+           |
+--------------------------- |  WRITE_PIXEL  |           |
  (Loop channels & pixels)   +---------------+           |
                                     |                   |
                  All pixels done    v                   |
                             +---------------+           |
                             |   DUMP_FILE   | ----------+
                             +---------------+
```

### FSM State Descriptions

| State | Description |
| :--- | :--- |
| **`IDLE`** | Waits for the `start` signal. When `start` is asserted, initializes output coordinate counters (`x_out`, `y_out`) and channel index (`ch`) to zero before transitioning. |
| **`CALC_COORDS`** | Multiplies `(x_out, y_out)` by the precomputed fixed-point scale factors (`scale_x`, `scale_y`) to determine input image coordinates. |
| **`FETCH_DATA`** | Extracts the integer coordinate `(x0, y0)` and fractional weights `(a, b)`, applies image boundary clamping, and reads the $2 \times 2$ pixel window from input memory. |
| **`INTERP_X`** | Performs horizontal bilinear interpolation across top and bottom pixel pairs using signed fixed-point arithmetic. |
| **`INTERP_Y`** | Performs vertical bilinear interpolation combining `interp_top` and `interp_bottom` with the vertical fractional weight `b`. |
| **`WRITE_PIXEL`** | Enforces `[0, 255]` color saturation clamping and writes the interpolated channel value into output memory. Advances the channel index (`ch`) or pixel coordinates. |
| **`DUMP_FILE`** | **Simulation-only state.** Uses `$fopen`/`$fdisplay` system tasks to dump output memory to `output_image.hex` for verification. These tasks are ignored by synthesis tools. |

---

## Mathematical Formulation

### 1. Fixed-Point Coordinate Scaling
To eliminate floating-point division hardware, scaling factors are precalculated with 8 fractional bits ($2^8 = 256$):

```math
S_x = \frac{W_{in} \times 256}{W_{out}}, \qquad S_y = \frac{H_{in} \times 256}{H_{out}}
```

For every output coordinate $(X_{out}, Y_{out})$, the corresponding fixed-point input coordinate is calculated as:

```math
X_{in} = X_{out} \times S_x, \qquad Y_{in} = Y_{out} \times S_y
```

- **Integer Coordinate Base**: `X0 = X_in[31:8]`, `Y0 = Y_in[31:8]`
- **Fractional Interpolation Weights**: `a = X_in[7:0]`, `b = Y_in[7:0]`

### 2. Bilinear Interpolation Equations

Given the $2 \times 2$ pixel neighborhood $(I_{00}, I_{10}, I_{01}, I_{11})$:

```math
I_{top} = I_{00} + \frac{a \cdot (I_{10} - I_{00})}{256}
```

```math
I_{bottom} = I_{01} + \frac{a \cdot (I_{11} - I_{01})}{256}
```

```math
I_{final} = I_{top} + \frac{b \cdot (I_{bottom} - I_{top})}{256}
```

In hardware, division by 256 is executed in zero clock cycles using an arithmetic right shift (`>>> 8`).

---

## Simulation & Running the Testbench

> **Note on Synthesizability**: The FSM control logic, bilinear interpolation datapath, fixed-point arithmetic, and boundary clamping are all **synthesizable RTL**. The `$readmemh`, `$fopen`, and `$fdisplay` system tasks used for image loading and output dumping are **simulation-only constructs** — they exist purely for behavioral verification and are not synthesized to hardware.

1. Place your input image hex dump named `input_image.hex` in the simulation working directory.
2. Compile and simulate using **Xilinx Vivado**, **ModelSim**, or **Icarus Verilog**:

```bash
# Using Icarus Verilog
iverilog -o sim_scaler rtl/image_scaler.v tb/tb_image_scaler.v
vvp sim_scaler
```

3. Upon completion of simulation, the resized image data will be generated in `output_image.hex`.
