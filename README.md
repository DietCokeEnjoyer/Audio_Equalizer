## Audio Equalizer
13 band FPGA Audio Equalizer developed over the course of a semester, broken up into four projects, all written in System Verilog:
- AXI4Lite Manager and Supporter busses
- FIR Filter
- Serial Peripheral Interface (SPI)
- Complete 13-band Audio Equalizer

# AXI4Lite Busses
These buses were developed to facilitate communication between the FPGA board's MicroBlaze processor and other components we would develop. They were also used for communication between components in the final equalizer.

# FIR Filter
A configurable FIR filter. The sample rate and number of taps can be modified in the source code, while the coefficient values can be changed on the fly.

# SPI
Created to transmit data to and from serial peripherals, in our case a DAC and ADC. One system verilog design was used for both cases, with the number of bits transmitted configured at runtime to suit the use case.

# 13-band Audio Equalizer
An FPGA audio equalizer that uses an ADC and a DAC to facilitate input and output. The 13 frequency band attenuations are adjustable through a Labview slider GUI, with these attenuations sent to the FPGA via a C driver program. It uses a 100kHz sample rate, 50kHz per channel.
