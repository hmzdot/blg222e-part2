# BLG222E Computer Organization  
## Project 2  
**Due Date:** 25.05.2025, 23:59  

Design a hardwired control unit for the following architecture. Use the structure that you have designed in Part 4 of Project 1.

---

## INSTRUCTION FORMAT

The instructions are stored in memory in little-endian order. Since the RAM in Project 1 has an 8-bit output, the instruction register cannot be filled in one clock cycle. You can load MSB and LSB in 2 clock cycles.

- **T=0:** Load LSB of instruction from memory address A into IR[7-0].  
- **T=1:** Load MSB of instruction from address A+1 into IR[15-8].  
- **T=2 and onwards:** Instruction execution begins.

### 1. Instructions with address reference

OPCODE (6-bit) | RSEL (2-bit) | ADDRESS (8-bit)

### 2. Instructions without address reference

OPCODE (6-bit) | DSTREG (3-bit) | SREG1 (3-bit) | SREG2 (3-bit) | 0

---

## OPCODE Table

| HEX  | Symbol | Description |
|------|--------|-------------|
| 0x00 | BRA    | PC ← VALUE |
| 0x01 | BNE    | IF Z=0 THEN PC ← VALUE |
| 0x02 | BEQ    | IF Z=1 THEN PC ← VALUE |
| 0x03 | POPL   | SP ← SP + 1, Rx ← M[SP] (16-bit) |
| 0x04 | PSHL   | M[SP] ← Rx, SP ← SP – 1 (16-bit) |
| 0x05 | POPH   | SP ← SP + 1, Rx ← M[SP] (32-bit) |
| 0x06 | PSHH   | M[SP] ← Rx, SP ← SP – 1 (32-bit) |
| 0x07 | CALL   | M[SP] ← PC, SP ← SP – 1, PC ← VALUE (16-bit) |
| 0x08 | RET    | SP ← SP + 1, PC ← M[SP] (16-bit) |
| 0x09 | INC    | DSTREG ← SREG1 + 1 |
| 0x0A | DEC    | DSTREG ← SREG1 – 1 |
| 0x0B | LSL    | DSTREG ← LSL SREG1 |
| 0x0C | LSR    | DSTREG ← LSR SREG1 |
| 0x0D | ASR    | DSTREG ← ASR SREG1 |
| 0x0E | CSL    | DSTREG ← CSL SREG1 |
| 0x0F | CSR    | DSTREG ← CSR SREG1 |
| 0x10 | NOT    | DSTREG ← NOT SREG1 |
| 0x11 | AND    | DSTREG ← SREG1 AND SREG2* |
| 0x12 | ORR    | DSTREG ← SREG1 OR SREG2* |
| 0x13 | XOR    | DSTREG ← SREG1 XOR SREG2* |
| 0x14 | NAND   | DSTREG ← SREG1 NAND SREG2* |
| 0x15 | ADD    | DSTREG ← SREG1 + SREG2* |
| 0x16 | ADC    | DSTREG ← SREG1 + SREG2 + CARRY* |
| 0x17 | SUB    | DSTREG ← SREG1 - SREG2* |
| 0x18 | MOV    | DSTREG ← SREG1 |
| 0x19 | MOVL   | Rx[7:0] ← IMMEDIATE (8-bit) |
| 0x1A | MOVSH  | Rx[31-8] ← Rx[23-0]; Rx[7-0] ← IMMEDIATE |
| 0x1B | LDARL  | DSTREG ← M[AR] (16-bit) |
| 0x1C | LDARH  | DSTREG ← M[AR] (32-bit) |
| 0x1D | STAR   | M[AR] ← SREG1 |
| 0x1E | LDAL   | Rx ← M[ADDRESS] (16-bit) |
| 0x1F | LDAH   | Rx ← M[ADDRESS] (32-bit) |
| 0x20 | STA    | M[ADDRESS] ← Rx |
| 0x21 | LDDRL  | DR ← M[AR] (16-bit) |
| 0x22 | LDDRH  | DR ← M[AR] (32-bit) |
| 0x23 | STDR   | DSTREG ← DR |
| 0x24 | STRIM  | M[AR+OFFSET] ← Rx |

---

## Table 2: RSEL Table

| RSEL | REGISTER |
|------|----------|
| 00   | R1       |
| 01   | R2       |
| 10   | R3       |
| 11   | R4       |

## Table 3: Register Selection

| Code | Register |
|------|----------|
| 000  | PC       |
| 001  | SP       |
| 010  | AR       |
| 011  | AR       |
| 100  | R1       |
| 101  | R2       |
| 106  | R3       |
| 111  | R4       |

---

## SIMPLE EXAMPLE

PC starts at 0, so first instruction is from 0x00:

BRA  0x18        # Instruction at 0x00, jump to 0x18  
MOVL R1, 0x00    # Iteration counter  
MOVSH R1, 0x06  
MOVL R2, 0x00    # Total  
MOVL R3, 0xB0  
MOV AR, R3       # AR points to data at 0xB0  
LABEL:  
LDARH R4         # Load 32-bit value from M[AR] to R4  
ADD R2, R2, R4   # Accumulate to R2  
INC AR, AR  
DEC R1, R1  
BNE LABEL        # Repeat if R1 > 0  
INC AR, AR  
STAR R2          # Store total at 0xC9  

---

## Submission Instructions

* Submit Verilog HDL implementation as a **single zip file** to Ninova.
* **One member per group** submits, and must include their student ID.
* Include:

  * Verilog module files (.v)
  * Given simulation files (.v)
  * Report:

    * Group members
    * Control unit design details
    * Clock cycle counts for each instruction
    * Clock cycle count for example code
    * Task distribution
* Test using the provided `.bat` and simulation files.
* No partial credit; broken code gets **zero**.
* Ask questions on the **Message Board**, not via email.
