[AES 256 GCM implementation]{.underline}

**Overview**

This document describes a synthesizable AES‑256 encryption core
integrated with GCM (Galois/Counter Mode) authentication. The
implementation is written in Verilog RTL with SystemVerilog testbenches.
It targets Xilinx 7‑Series/UltraScale devices and standard EDA flows
(Questa/Vivado). It incorporates AXI steaming bus protocol in

**Toolchain & Environment**

-   **Vivado**: 2024.1.2 (64-bit)

-   **Simulator**: QuestaSim 2024.1 (Feb 2024 build)

-   **Hardware (simulated)**: Kintex-7 FPGA, 100--150 MHz

-   **Host**: Windows 11 Pro

**Data Sizes**

-   Key Size: 256 bits

-   Block Size: 128 bits

-   Internal Buffer Capacity: 28 packets (each packet comprising 128
    bits)

**Repository Files**

  -----------------------------------------------------------------------
  File                                Description
  ----------------------------------- -----------------------------------
  Aesop's                             AES‑256 core wrapper integrating
                                      round pipeline and key schedule
                                      feed.

  Buffer.v                            Elastic buffering/FIFO style
                                      decoupling between stages.

  GCM_controller.v                    GCM controller builds counter
                                      blocks (CTR), aligns data to GHASH
                                      and calculates final tags

  ghash.v                             GHASH engine implementing
                                      GF(2\^128) multiply and reduction.

  Key_expansion_aes_256.v             AES‑256 key expansion to generate
                                      round keys.

  round1to12.v                        Pipelined AES round stages
                                      (SubBytes, ShiftRows, MixColumns,
                                      AddRoundKey).

  SBOX.v                              AES S‑Box (8×8 substitution).

  TB.sv                               Unit/system testbench for AES path.

  TB_GCM_controller.sv                Top‑level GCM testbench driving
                                      streaming payloads/AAD and checking
                                      timing.

  AES_256_pipelined.xlsx              Pipeline/latency planning notes
                                      (timing budget and stage mapping)
                                      used in AES encryption
  -----------------------------------------------------------------------

**Description of Test Benches**

1)  **TB.sv**\
    Simulates all possible combinations of the s_axis_tvalid signal to
    validate the behavior of the design under varying valid input
    patterns.

2)  **TB_GCM_controller.sv**\
    Simulates all possible combinations of the m_axis_tready signal to
    evaluate the design\'s response to different output backpressure
    conditions.

***Note:***\
*The current implementation does **not** include a combined testbench
where both s_axis_tvalid and m_axis_tready are varied simultaneously.
Such combined testing is yet to be performed.*

![A paper with a diagram AI-generated content may be
incorrect.](media/image1.jpeg){width="4.887652012248469in"
height="7.05834864391951in"}

**Test Configuration and Assumptions:**

This project is based on the assumption that the maximum payload size of
a single Ethernet packet is approximately **1400 bytes**. To encrypt the
full payload using AES-GCM with 128-bit (16-byte) blocks, approximately
**88 blocks** are required.

The testbench simulates the encryption process for **1 to 90 blocks** of
data per iteration. Additionally, a fixed preface of **6 packets** is
appended at the beginning of each test case, as mandated by the AES-GCM
protocol. This preface values conform to the specifications outlined in
**Test Case 16 of *gsm-spec2.pdf***.

**Preface packets are as under**

1)  LENA_LENC(128 bits):

    a.  The upper 64 bits (bits \[127:64\]) represent the length of the
        Additional Authenticated Data (AAD), in bits.

    b.  The lower 64 bits (bits \[63:0\]) represent the length of the
        plaintext or ciphertext, also in bits.

    c.  Value: 128\'h00000000000000A0_00000000000001E0

2)  KEY_LOW (128 bits):

    a.  Represents the lower 128 bits of the AES-256 encryption key.

    b.  Value: 128\'hFEFFE9928665731C_6D6A8F9467308308.

3)  KEY_HIGH (128 bits):

    a.  Represents the upper 128 bits of the AES-256 encryption key.

    b.  Value: 128\'hFEFFE9928665731C_6D6A8F9467308308.

4)  AAD_LOW (128 bits):

    a.  Represents the lower 128 bits of the Additional Authenticated
        Data (AAD).

    b.  Value: 128\'hFEEDFACEDEADBEEF_FEEDFACEDEADBEEF.

5)  AAD_HIGH (128 bits):

    a.  Represents the upper 128 bits of the Additional Authenticated
        Data (AAD).

    b.  Value: 128\'hABADDAD200000000_0000000000000000.

6)  IV (128 bits):

    a.  Represents the Initialization Vector (IV) used for AES-GCM
        encryption.

    b.  Value: 128\'h00000000CAFEBABE_FACEDBADDECAF888.

Code is written in a way that it accepts these 6 packets in 128 bits
aligned form before starting the actual payload.

1)  [Test Bench (TB.sv):]{.underline}

> This testbench evaluates the functionality of the design by simulating
> 90 packets per iteration, across a range of s_axis_tvalid pulse
> widths. Specifically, for each test iteration, the number of
> consecutive cycles during which s_axis_tvalid remains high is varied
> from 1 to 31. Correspondingly, the low phase of s_axis_tvalid is also
> swept from 1 to 31 cycles.
>
> Each iteration is verified against the following expected outputs:

-   Authentication Tag

-   First Encrypted Packet

-   Count of cycles during which m_axis_tvalid remains asserted

> Results are as under
>
> \# tvalid High cycles 1.....31: passed

2)  [Test Bench (TB_GCM_controller.sv):]{.underline}

This testbench evaluates the functionality of the design by simulating
90 packets per iteration, across a range of m_axis_tready pulse widths.
Specifically, for each test iteration, the number of consecutive cycles
during which m_axis_tready remains high is varied from 1 to 31.
Correspondingly, the low phase of m_axis_tready is also swept from 1 to
31 cycles.

Each iteration is verified against the following expected outputs:

• Authentication Tag

• First Encrypted Packet

• Count of cycles during which m_axis_tvalid remains asserted

Results are as follows

\# high_cycles = 1......31 Passed
