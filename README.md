# Pipeline RISC-V con Soporte de Punto Flotante

Pipeline RISC-V de 5 etapas con soporte completo para operaciones de enteros y punto flotante (IEEE 754).

## Testing - Testbench Unificado

El proyecto incluye un **testbench unificado** (`testbench_unified.v`) que ejecuta automáticamente:

1. ✅ **Tests unitarios de ALU de enteros** (6 pruebas)
2. ✅ **Tests unitarios de ALU de punto flotante** (7 pruebas)
3. ✅ **Simulación del pipeline completo** (50 ciclos con debug detallado)

### Compilar y Ejecutar

```bash
# Compilar
iverilog -o test testbench_unified.v alu_int.v alu_fp.v \
  controller.v maindec.v aludec.v datapath.v \
  regfile.v regfile_fp.v pipeline_registers.v hazard_unit.v \
  riscvpipeline.v top.v imem.v dmem.v \
  extend.v mux2.v mux3.v flopr.v adder.v

# Ejecutar
vvp test
```

### Salida del Testbench

El testbench muestra **salida formateada** con símbolos Unicode para fácil lectura:

```
████████████████████████████████████████████████████████████
██   TESTBENCH UNIFICADO - PIPELINE RISC-V FP             ██
████████████████████████████████████████████████████████████

PARTE 1: Tests Unitarios - ALU Enteros
  [Test 1] INT ADD: 10 + 20 = 30 ✓ PASS
  [Test 2] INT SUB: 50 - 15 = 35 ✓ PASS
  ...

PARTE 2: Tests Unitarios - ALU Punto Flotante
  [Test 7] FP ADD: 2.0 + 3.0 = 5.0 ✓ PASS
  [Test 8] FP SUB: 5.0 - 2.0 = 3.0 ✓ PASS
  ...

RESUMEN: 13/13 PASADAS ★★★

PARTE 3: Pipeline Completo (50 ciclos)

┌────────────────────────────────────────────┐
│ CICLO 1
├────────────────────────────────────────────┤
│ PC: 0x00000000  Instr: 0x00000013
│ INT Regs: x1=0x... x2=0x... x3=0x...
│ FP  Regs: f0=0x... f1=0x... f2=0x...
│ Control: RegW=1 FPOp=0 ALUCtrl=000
│ Hazards: FwdA=00 Stall=0 Flush=0
│ ALU: A=0x... B=0x... R=0x... (FP=0)
└────────────────────────────────────────────┘
```

### Información Mostrada por Ciclo

Para cada ciclo del pipeline, se muestra:

- **PC e Instrucción**: Dirección y código actual
- **Memoria**: MemWrite, DataAdr, WriteData
- **Registros INT**: x1-x5 en hexadecimal
- **Registros FP**: f0-f4 en hexadecimal
- **Control**: RegWrite, RegWriteFP, FPOp, ALUControl
- **Pipeline**: Estado de etapas E/M/W (Rd, RegWrite, FPOp)
- **Hazards**: Forwarding, Stalling, Flushing
- **ALU**: Operandos A/B, Resultado, tipo (INT/FP)

## Características del Pipeline

- 5 etapas: Fetch → Decode → Execute → Memory → Writeback
- ALU de enteros: ADD, SUB, AND, OR, XOR, SLT, SLL, SRL
- ALU FP: FADD, FSUB, FMUL, FDIV (IEEE 754 single precision)
- Register files separados (32 registros INT x 32 registros FP)
- Hazard detection y data forwarding
- Branch prediction y control hazard handling

## Estructura de Archivos

```
├── alu_int.v              # ALU de enteros
├── alu_fp.v               # ALU de punto flotante (autocontenida)
├── testbench_unified.v    # Testbench unificado ★
├── controller.v           # Control del pipeline
├── datapath.v             # Datapath con ambas ALUs
├── riscvpipeline.v        # Top level del pipeline
└── README.md              # Este archivo
```

## Instrucciones Soportadas

### Operaciones de Enteros
```
ADD, SUB, AND, OR, XOR, SLT, SLL, SRL
LW, SW, BEQ, JAL
```

### Operaciones de Punto Flotante
```
FADD.S  fd, fs1, fs2    # fd = fs1 + fs2
FSUB.S  fd, fs1, fs2    # fd = fs1 - fs2
FMUL.S  fd, fs1, fs2    # fd = fs1 × fs2
FDIV.S  fd, fs1, fs2    # fd = fs1 ÷ fs2
FLW     fd, offset(rs1) # Load FP
FSW     fs2, offset(rs1)# Store FP
```

## Formato IEEE 754 - Referencia Rápida

| Valor | Hexadecimal | Binario (S Exp Mant) |
|-------|-------------|----------------------|
| 0.0   | 0x00000000  | 0 00000000 00000000000000000000000 |
| 1.0   | 0x3F800000  | 0 01111111 00000000000000000000000 |
| 2.0   | 0x40000000  | 0 10000000 00000000000000000000000 |
| 3.0   | 0x40400000  | 0 10000000 10000000000000000000000 |
| 5.0   | 0x40A00000  | 0 10000001 01000000000000000000000 |
| 6.0   | 0x40C00000  | 0 10000001 10000000000000000000000 |
| +Inf  | 0x7F800000  | 0 11111111 00000000000000000000000 |

## Debug y Depuración

El testbench genera un archivo VCD para visualización en GTKWave:

```bash
gtkwave testbench_unified.vcd &
```

Señales importantes para debug:
- `dut.PC` - Program Counter
- `dut.Instr` - Instrucción actual
- `dut.rvpipeline.dp.ALUResultE` - Resultado de ALU
- `dut.rvpipeline.dp.FPOpE` - Bandera de operación FP
- `dut.rvpipeline.dp.ForwardAE/ForwardBE` - Forwarding activo

## Proyecto Académico

Universidad de Ingeniería y Tecnología (UTEC)
Curso: Arquitectura de Computadores
Ciclo académico: 2025-2
