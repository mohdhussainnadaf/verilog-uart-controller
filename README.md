# Configurable Multi-Module UART Controller

An industrial-grade, synthesizable Verilog implementation of a UART controller featuring dynamic baud rate generation, clock domain crossing (CDC) synchronization, dual circular FIFOs, and an automated verification testbench.

## Architecture
- **Baud Rate Generator:** 16-bit programmable counter generating $16\times$ oversampling ticks.
- **RX Synchronizer:** 2-flip-flop synchronizer on the asynchronous `rx` input to prevent metastability.
- **TX/RX FSMs:** Moore/Mealy finite state machines handling start/data/stop bit timing.
- **Circular FIFOs:** 16-entry ring buffers for decoupled transmit and receive buffering.

## Verification
Simulated using Icarus Verilog (`iverilog`) and `vvp`. Tested via automated serial loopback for data values `0xA5` and `0x3C`.
