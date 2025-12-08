# Processor: process_dsp_phy

| Property | Value |
|----------|-------|
| **Input Tier** | `raw` |
| **Output Tier** | `jldsp` |
| **Category** | `phy` |
| **Detector Types** | HPGe (ICPC), SiPM, PMT, Auxiliary (Pulser, Baseline, Muon) |

---

# 1 Input

<details>
<summary><b>1.1 Tier Data</b></summary>

| Tier | Description |
|------|-------------|
| `raw` | Raw waveform data from FlashCam DAQ |

  <details>
  <summary>1.1.1 HPGe Raw Data Keys</summary>

  | Key | Type | Description |
  |-----|------|-------------|
  | `waveform_presummed` | ArrayOfRDWaveforms | Presummed waveform data (compressed readout) |
  | `waveform_windowed` | ArrayOfRDWaveforms | Windowed waveform data (compressed readout) |
  | `presum_rate` | Vector | Presum rate for decompression |
  | `baseline` | Vector | Baseline from FlashCam |
  | `timestamp` | Vector | Timestamp from DAQ |
  | `eventnumber` | Vector | Event number from DAQ |
  | `daqenergy` | Vector | Energy from FlashCam |
  | `t_sat_lo` | Vector | Time of low saturation |
  | `t_sat_hi` | Vector | Time of high saturation |
  | `deadtime` | Vector | Deadtime from DAQ |

  </details>

  <details>
  <summary>1.1.2 SiPM Raw Data Keys</summary>

  | Key | Type | Description |
  |-----|------|-------------|
  | `waveform_bit_drop` | ArrayOfRDWaveforms | Bit-dropped waveform data (compressed readout) |
  | `baseline` | Vector | Baseline from FlashCam |
  | `timestamp` | Vector | Timestamp from DAQ |
  | `eventnumber` | Vector | Event number from DAQ |
  | `daqenergy` | Vector | Energy from FlashCam |

  </details>

  <details>
  <summary>1.1.3 PMT Raw Data Keys</summary>

  | Key | Type | Description |
  |-----|------|-------------|
  | `waveform` | ArrayOfRDWaveforms | Full waveform data (uncompressed readout) |
  | `baseline` | Vector | Baseline from FlashCam |
  | `timestamp` | Vector | Timestamp from DAQ |
  | `eventnumber` | Vector | Event number from DAQ |
  | `daqenergy` | Vector | Energy from FlashCam |
  | `channel` | Vector | Channel ID |

  </details>

  <details>
  <summary>1.1.4 Auxiliary Raw Data Keys</summary>

  | Key | Type | Description |
  |-----|------|-------------|
  | `waveform_presummed` | ArrayOfRDWaveforms | Presummed waveform data |
  | `waveform_windowed` | ArrayOfRDWaveforms | Windowed waveform data |
  | `presum_rate` | Vector | Presum rate |
  | `baseline` | Vector | Baseline from FlashCam |
  | `timestamp` | Vector | Timestamp from DAQ |
  | `eventnumber` | Vector | Event number from DAQ |
  | `daqenergy` | Vector | Energy from FlashCam |

  </details>

</details>

<details>
<summary><b>1.2 Configuration Files</b></summary>

| Config | Path | Description |
|--------|------|-------------|
| DSP Config | `dataprod_config(l200).dsp(filekey)` | DSP processing parameters for HPGe detectors |
| SiPM Config | `dataprod_config(l200).sipm(filekey)` | SiPM-specific DSP parameters |
| PMT Config | `dataprod_config(l200).pmt(filekey)` | PMT-specific DSP parameters |

</details>

<details>
<summary><b>1.3 Parameter Files</b></summary>

| Parameter | Source | Description |
|-----------|--------|-------------|
| Decay Time (tau) | `l200.par.rpars.pz(filekey)` | Detector decay time for pole-zero correction |
| Filter Optimization | `l200.par.rpars.fltopt(filekey)` | Optimized filter parameters (Trap, CUSP, ZAC) |
| A/E Optimization | `l200.par.rpars.aoeopt(filekey)` | Savitzky-Golay window length for current |
| SiPM Optimization | `l200.par.rpars.sipmopt(filekey)` | SiPM Savitzky-Golay parameters |
| ML QC Model | `get_mltrainfilename(l200, filekey)` | Trained SVM model for waveform QC |

</details>

<details>
<summary><b>1.4 Channel Information</b></summary>

| System | Variable | Description |
|--------|----------|-------------|
| HPGe | `chinfo` | Germanium detectors (system=:geds) |
| SiPM | `chinfo_sipm` | Silicon photomultipliers (system=:spms) |
| PMT | `chinfo_pmts` | Photomultiplier tubes (system=:pmts) |
| Auxiliary | `dsp_config_pd.additional_channel` | Puls01, Bsln01, Muon01 |

</details>

---

# 2 Workflow

<details>
<summary><b>2.1 Detailed Workflow Steps</b></summary>

```
1. Initialize
   - Search filekeys on disk for period/run
   - Load channel info for HPGe, SiPM, PMT systems
   - Load DSP configs (dsp, sipm, pmt)
   
2. Load Parameters (global, all detectors)
   - pars_tau: all decay times
   - pars_fltoptimization: all filter parameters
   - pars_sipm: all SiPM parameters
   - Load or create QC ML classifier
   
3. For each FileKey (parallel via worker pool):
   a. Open raw file (read) and output file (create/modify)
   b. Process Auxiliary channels
   c. Process PMT detectors
   d. Process SiPM detectors
   e. Process HPGe detectors
   f. Save results to jldsp tier
   
4. Generate Report
```

</details>

<details>
<summary><b>2.2 Main Processing Functions</b></summary>

  <details>
  <summary>2.2.1 HPGe Detectors - <code>dsp_icpc_compressed()</code></summary>

  **Source:** `LegendDSP.jl/src/dsp_icpc.jl`

  **Function Call:**
  ```julia
  outdata_ch = dsp_icpc_compressed(
      raw_data[raw_key].raw[:],   # raw waveform data
      dsp_config_ch,               # DSP configuration
      detector_tau.τ,              # decay time
      detector_fltopt;             # filter parameters
      f_evaluate_qc=f_evaluate_qc  # QC classifier
  )
  ```

  **Detailed Documentation:** [analysis_functions/dsp_icpc_compressed.md](analysis_functions/dsp_icpc_compressed.md)

  </details>

  <details>
  <summary>2.2.2 SiPM Detectors - <code>dsp_sipm_compressed()</code></summary>

  **Source:** `LegendDSP.jl/src/dsp_sipm.jl`

  **Function Call:**
  ```julia
  outdata_ch = dsp_sipm_compressed(
      raw_data[raw_key].raw[:],
      dsp_meta_ch,
      detector_sipmopt
  )
  ```

  **Detailed Documentation:** [analysis_functions/dsp_sipm_compressed.md](analysis_functions/dsp_sipm_compressed.md)

  </details>

  <details>
  <summary>2.2.3 PMT Detectors - <code>dsp_pmts()</code></summary>

  **Source:** `LegendDSP.jl/src/dsp_pmts.jl`

  **Function Call:**
  ```julia
  outdata_ch = dsp_pmts(
      raw_data[raw_key].raw[:],
      dsp_meta_ch
  )
  ```

  **Detailed Documentation:** [analysis_functions/dsp_pmts.md](analysis_functions/dsp_pmts.md)

  </details>

  <details>
  <summary>2.2.4 Auxiliary Channels - <code>dsp_puls_compressed()</code></summary>

  **Source:** `LegendDSP.jl/src/dsp_puls.jl`

  **Function Call:**
  ```julia
  outdata_ch = getfield(LegendDSP, Symbol(config_name))(
      raw_data[raw_key].raw[:],
      dsp_config_ch
  )
  ```

  **Detailed Documentation:** [analysis_functions/dsp_puls_compressed.md](analysis_functions/dsp_puls_compressed.md)

  </details>

</details>

<details>
<summary><b>2.3 Parallel Processing</b></summary>

| Level | Unit | Description |
|-------|------|-------------|
| Parallel | FileKey | Each worker processes one raw file |
| Sequential | Detector | Detectors processed in loops within each file |

</details>

---

# 3 Output

<details>
<summary><b>3.1 Tier Data</b></summary>

| Tier | Description |
|------|-------------|
| `jldsp` | DSP-processed data, one group per detector |

<details>
<summary><b>3.1.1 HPGe Output (dsp_icpc_compressed)</b></summary>

<details>
<summary>3.1.1.1 Baseline Parameters</summary>

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `blmean` | Float | ADC | Baseline mean |
| `blsigma` | Float | ADC | Baseline standard deviation |
| `blslope` | Float | ADC/sample | Baseline slope |
| `bloffset` | Float | ADC | Baseline offset |

</details>

<details>
<summary>3.1.1.2 Tail Parameters</summary>

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `tailmean` | Float | ADC | Tail mean after PZ correction |
| `tailsigma` | Float | ADC | Tail sigma after PZ correction |
| `tailslope` | Float | ADC/sample | Tail slope |
| `tailoffset` | Float | ADC | Tail offset |
| `tail_tau` | Float | us | Extracted decay time |
| `tail_mean` | Float | ADC | Tail mean before PZ |
| `tail_sigma` | Float | ADC | Tail sigma before PZ |

</details>

<details>
<summary>3.1.1.3 Timing Parameters</summary>

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `t0` | Float | us | Signal onset time |
| `t10` | Float | us | Time at 10% of maximum |
| `t50` | Float | us | Time at 50% of maximum |
| `t50_pre` | Float | us | t50 on presummed waveform |
| `t80` | Float | us | Time at 80% of maximum |
| `t90` | Float | us | Time at 90% of maximum |
| `t99` | Float | us | Time at 99% of maximum |
| `t50_current` | Float | us | Current rise to 50% |
| `drift_time` | Float | ns | Drift time (t90 - t0) |
| `t0_inv` | Float | us | t0 of inverted waveform |

</details>

<details>
<summary>3.1.1.4 Energy Parameters (Robust)</summary>

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `e_max` | Float | ADC | Waveform maximum (windowed) |
| `e_min` | Float | ADC | Waveform minimum (windowed) |
| `e_max_pre` | Float | ADC | Maximum (presummed) |
| `e_min_pre` | Float | ADC | Minimum (presummed) |
| `e_10410` | Float | ADC | Trap energy (10us/4us) |
| `e_535` | Float | ADC | Trap energy (5us/3us) |
| `e_313` | Float | ADC | Trap energy (3us/1us) |
| `e_10410_inv` | Float | ADC | Inverted Trap (10-4-10) |
| `e_313_inv` | Float | ADC | Inverted Trap (3-1-3) |

</details>

<details>
<summary>3.1.1.5 Energy Parameters (Optimized)</summary>

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `e_trap` | Float | ADC | Optimized Trap energy |
| `e_cusp` | Float | ADC | Optimized CUSP energy |
| `e_zac` | Float | ADC | Optimized ZAC energy |
| `e_trap_max` | Float | ADC | Trap filter maximum |
| `e_cusp_max` | Float | ADC | CUSP filter maximum |
| `e_zac_max` | Float | ADC | ZAC filter maximum |
| `t_trap_max` | Float | us | Time of Trap max |
| `t_cusp_max` | Float | us | Time of CUSP max |
| `t_zac_max` | Float | us | Time of ZAC max |

</details>

<details>
<summary>3.1.1.6 Current / A/E Parameters</summary>

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `a_sg` | Float | ADC/sample | Current (optimized SG) |
| `a_60` | Float | ADC/sample | Current (60ns SG) |
| `a_100` | Float | ADC/sample | Current (100ns SG) |
| `a_raw` | Float | ADC/sample | Raw derivative max |

</details>

<details>
<summary>3.1.1.7 Pulse Shape Parameters</summary>

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `qdrift` | Float | ADC*sample | Q-drift parameter |
| `lq` | Float | ADC*sample | Late charge (LQ) |

</details>

<details>
<summary>3.1.1.8 Quality Parameters</summary>

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `qc_label` | Int | - | QC label (0=good, 1=bad) |
| `inTrace_intersect` | Float | us | Pile-up position |
| `inTrace_n` | Int | - | Pile-up multiplicity |

</details>

<details>
<summary>3.1.1.9 Saturation Parameters</summary>

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `n_sat_low` | Int | - | Samples at low saturation |
| `n_sat_high` | Int | - | Samples at high saturation |
| `n_sat_low_cons` | Int | - | Consecutive low sat |
| `n_sat_high_cons` | Int | - | Consecutive high sat |
| `t_sat_lo` | Float | us | Time of low saturation |
| `t_sat_hi` | Float | us | Time of high saturation |

</details>

<details>
<summary>3.1.1.10 DAQ Parameters</summary>

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `blfc` | Float | ADC | FlashCam baseline |
| `timestamp` | Int | - | DAQ timestamp |
| `eventID_fadc` | Int | - | Event ID |
| `e_fc` | Float | ADC | FlashCam energy |
| `deadtime` | Float | - | Deadtime |

</details>

</details>

  <details>
  <summary>3.1.2 SiPM Output (dsp_sipm_compressed)</summary>

  | Column | Type | Unit | Description |
  |--------|------|------|-------------|
  | `blfc` | Float | ADC | FlashCam baseline |
  | `timestamp` | Int | - | Timestamp |
  | `eventID_fadc` | Int | - | Event ID |
  | `e_fc` | Float | ADC | FlashCam energy |
  | `t_max` | Float | us | Time of maximum |
  | `t_min` | Float | us | Time of minimum |
  | `e_max` | Float | ADC | Maximum |
  | `e_min` | Float | ADC | Minimum |
  | `blmean` | Float | ADC | Baseline mean |
  | `blsigma` | Float | ADC | Baseline sigma |
  | `threshold` | Float | ADC | Trigger threshold |
  | `trig_pos` | VectorOfVectors | us | Trigger positions |
  | `trig_max` | VectorOfVectors | ADC | Trigger maxima |

  </details>

  <details>
  <summary>3.1.3 PMT Output (dsp_pmts)</summary>

  | Column | Type | Unit | Description |
  |--------|------|------|-------------|
  | `timestamp` | Int | - | Timestamp |
  | `eventID_fadc` | Int | - | Event ID |
  | `e_fc` | Float | ADC | FlashCam energy |
  | `channel` | Int | - | Channel ID |
  | `pulse_height` | Float | ADC | Pulse height |
  | `trig_mult` | Int | - | Trigger multiplicity |
  | `bl_mean` | Float | ADC | Baseline mean |
  | `bl_sigma` | Float | ADC | Baseline sigma |

  </details>

  <details>
  <summary>3.1.4 Auxiliary Output (dsp_puls_compressed)</summary>

  | Column | Type | Unit | Description |
  |--------|------|------|-------------|
  | `blmean` | Float | ADC | Baseline mean |
  | `blsigma` | Float | ADC | Baseline sigma |
  | `t50` | Float | us | Time at 50% |
  | `e_max` | Float | ADC | Maximum |
  | `e_10410` | Float | ADC | Trap energy |
  | `timestamp` | Int | - | Timestamp |

  </details>

</details>

<details>
<summary><b>3.2 Reports</b></summary>

| Output | Path | Description |
|--------|------|-------------|
| Processing Report | `get_rreportfilename(l200, filekey, :dsp_phy)` | Processing summary |

</details>

---

# 4 kwargs Parameters

<details>
<summary><b>4.1 All Parameters</b></summary>

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `reprocess` | Bool | false | Reprocess existing data |
| `timeout` | Int | 0 | Timeout per filekey (seconds) |
| `max_wvfs` | Int | 10000 | Max waveforms per detector |
| `use_partition_filter` | Bool | false | Use ppars instead of rpars |
| `use_dsp_config_defaults` | Bool | false | Use default parameters |

</details>
