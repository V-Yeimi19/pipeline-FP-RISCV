# Programa de Prueba del Pipeline RISC-V con FP

## Instrucciones incluidas en `riscvtest.txt`

### TEST 1: Operaciones de Enteros Básicas
```asm
00500093    addi x1, x0, 5        # x1 = 5
00A00113    addi x2, x0, 10       # x2 = 10
002081B3    add  x3, x1, x2       # x3 = 5 + 10 = 15
40208233    sub  x4, x1, x2       # x4 = 5 - 10 = -5
```
**Verifica:** ALU de enteros (ADD, SUB), forwarding básico

---

### TEST 2: Load/Store de Enteros
```asm
00302023    sw   x3, 0(x0)        # MEM[0] = 15
00002303    lw   x6, 0(x0)        # x6 = MEM[0] = 15
```
**Verifica:** Memoria, load-use hazard detection

---

### TEST 3: Setup de Valores FP
```asm
3F800093    addi x1, x0, 0x3F800  # x1 = 0x3F800000 (1.0 en IEEE 754)
00102027    sw   x1, 0(x0)        # MEM[0] = 1.0

40000113    addi x2, x0, 0x4000   # x2 = 0x40000000 (2.0 en IEEE 754)
00102227    sw   x2, 4(x0)        # MEM[4] = 2.0
```
**Preparación:** Carga valores FP en memoria

---

### TEST 4: Operaciones de Punto Flotante
```asm
00002087    flw  f1, 0(x0)        # f1 = 1.0
00402107    flw  f2, 4(x0)        # f2 = 2.0

00208153    fadd.s f2, f1, f2     # f2 = 1.0 + 2.0 = 3.0
402101D3    fsub.s f3, f2, f2     # f3 = 3.0 - 3.0 = 0.0
02208253    fmul.s f4, f1, f2     # f4 = 1.0 * 3.0 = 3.0
022082D3    fdiv.s f5, f1, f2     # f5 = 1.0 / 3.0 = 0.333...

00202427    fsw  f4, 8(x0)        # MEM[8] = 3.0
```
**Verifica:**
- FLW/FSW (load/store FP)
- FADD, FSUB, FMUL, FDIV
- FP register file
- ALU FP con IEEE 754

---

### TEST 5: RAW Hazards y Forwarding
```asm
00A00093    addi x1, x0, 10       # x1 = 10
00108093    addi x1, x1, 1        # x1 = 11 (RAW hazard, requiere forwarding)
001080B3    add  x1, x1, x1       # x1 = 22 (doble RAW hazard)
```
**Verifica:** Forwarding desde EX/MEM y MEM/WB

---

### TEST 6: Control Hazards
```asm
00000463    beq  x0, x0, 4        # Branch tomado (saltar +4)
00000093    nop                   # (se descarta por flush)
00000093    nop                   # (se descarta por flush)
008000EF    jal  x1, 8            # Jump (saltar +8)
```
**Verifica:** Branch, Jump, flush de pipeline

---

## Resultados Esperados

### Registros de Enteros (después de 50 ciclos):
- `x1` = 0x00000016 (22 decimal)
- `x2` = 0x0000000A (10 decimal)
- `x3` = 0x0000000F (15 decimal)
- `x4` = 0xFFFFFFFB (-5 en complemento a 2)
- `x6` = 0x0000000F (15 decimal, cargado de memoria)

### Registros FP (después de 50 ciclos):
- `f1` = 0x3F800000 (1.0 en IEEE 754)
- `f2` = 0x40400000 (3.0 en IEEE 754)
- `f3` = 0x00000000 (0.0)
- `f4` = 0x40400000 (3.0)
- `f5` ≈ 0x3EAAAAAB (0.333... en IEEE 754)

### Memoria de Datos:
- `MEM[0]` = 0x3F800000 (1.0)
- `MEM[4]` = 0x40000000 (2.0)
- `MEM[8]` = 0x40400000 (3.0)

---

## Cómo Ejecutar la Simulación

```bash
# Con Icarus Verilog
iverilog -o sim -y . top.v testbench.v
vvp sim

```

## Señales a Observar en el Testbench

1. **Forwarding**: `ForwardAE`, `ForwardBE` deben activarse cuando hay hazards RAW
2. **Stalling**: `StallD` debe activarse en load-use hazards
3. **Flushing**: `FlushE`, `FlushD` deben activarse en branches/jumps tomados
4. **FP Operations**: `FPOpE` debe ser 1 durante operaciones FP
5. **RegWriteFP**: Debe escribir en `frf` cuando es 1
