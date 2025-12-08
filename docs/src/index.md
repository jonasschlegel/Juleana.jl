# Juleana.jl

Juleana.jl is the Julia-based data production framework for the LEGEND-200 experiment.

## Overview

This package provides:
- **Data Processing Pipelines**: DSP, Hit, Event tier processing
- **Calibration Routines**: Energy calibration, A/E optimization, PSD cuts
- **Quality Control**: ML-based waveform classification, data validation

## Documentation Structure

### Processors

Each processor has dedicated documentation:

| Processor | Tier | Description |
|-----------|------|-------------|
| [process_dsp_phy](@ref process_dsp_phy) | raw → jldsp | Digital Signal Processing for physics data |

### Analysis Functions

Detailed documentation for the analysis functions called by processors:

| Function | Package | Description |
|----------|---------|-------------|
| [dsp_icpc_compressed](@ref dsp_icpc_compressed) | LegendDSP.jl | HPGe detector DSP |

## Quick Links

- [API Reference](@ref api)
- [Processor: process_dsp_phy](process_dsp_phy/processor_flow.md)
- [Function: dsp_icpc_compressed](process_dsp_phy/analysis_functions/dsp_icpc_compressed.md)
