# dsp_icpc_compressed

Digital Signal Processing for HPGe (ICPC) detectors with compressed waveform readout.

| Property | Value |
|----------|-------|
| **Source** | `LegendDSP.jl/src/dsp_icpc.jl` |
| **Package** | `LegendDSP.jl` |
| **Input** | Compressed raw waveforms (presummed + windowed) |
| **Output** | TypedTables.Table with ~50 DSP parameters |

---

# 1 Function Signature

```julia
function dsp_icpc_compressed(
    data::Q, 
    config::DSPConfig, 
    τ::Quantity{T}, 
    pars_filter::PropDict; 
    f_evaluate_qc::Union{Function, Missing}=missing
) where {Q <: Table, T<:Real}
```

---

# 2 Input Parameters

<details>
<summary><b>2.1 data (Raw Table)</b></summary>

| Column | Type | Description |
|--------|------|-------------|
| `waveform_presummed` | ArrayOfRDWaveforms | Presummed waveform (128 ns/sample) |
| `waveform_windowed` | ArrayOfRDWaveforms | High-resolution window (16 ns/sample) |
| `presum_rate` | Vector | Presum rate (typically 8) |
| `baseline` | Vector | Baseline from FlashCam |
| `timestamp` | Vector | Timestamp from DAQ |
| `eventnumber` | Vector | Event number |
| `daqenergy` | Vector | Energy from FlashCam |
| `t_sat_lo` | Vector | Time of low saturation |
| `t_sat_hi` | Vector | Time of high saturation |
| `deadtime` | Vector | Deadtime |

</details>

<details>
<summary><b>2.2 config (DSPConfig)</b></summary>

| Parameter | Type | Default Value | Description |
|-----------|------|---------------|-------------|
| `bl_window` | Interval | 0..39 us | Baseline extraction window |
| `t0_threshold` | Float | 4.0 | Fixed threshold for t0 (ADC units) |
| `tail_window` | Interval | 70..110 us | Tail window for decay time |
| `inTraceCut_std_threshold` | Float | 5.0 | Pile-up threshold (in sigma) |
| `sg_flt_degree` | Int | 3 | Savitzky-Golay polynomial degree |
| `current_window` | Interval | 43..62 us | Window for current maximum |
| `qdrift_int_length` | Quantity | [2.5, 5.0] us | Q-drift integration range |
| `lq_int_length` | Quantity | [2.5, 5.0] us | LQ integration range |
| `flt_length_zac` | Quantity | 38 us | ZAC filter total length |
| `flt_length_cusp` | Quantity | 38 us | CUSP filter total length |

**Source:** `jldataprod/config/dsp/dsp_default_all.yaml`

</details>

<details>
<summary><b>2.3 tau (Decay Time)</b></summary>

| Parameter | Type | Default Value | Range | Description |
|-----------|------|---------------|-------|-------------|
| `tau` | `Quantity{T}` | 460.0 us | 200..800 us | Preamplifier decay time constant |

**Source:** `l200.par.rpars.pz(filekey)[det].tau`

**Default Config:** `jldataprod/config/dsp/dsp_default_all.yaml` (pz.default.tau)

**Physics:** The charge-sensitive preamplifier output decays exponentially with time constant tau due to the feedback RC circuit. This must be corrected (pole-zero correction) for accurate energy measurement.

</details>

<details>
<summary><b>2.4 pars_filter (Filter Optimization)</b></summary>

| Key | Subkeys | Default Values | Grid Range | Description |
|-----|---------|----------------|------------|-------------|
| `trap` | `rt`, `ft` | 5.0 us, 2.5 us | rt: 1-16 us, ft: 1-4 us | Trapezoidal filter parameters |
| `cusp` | `rt`, `ft` | 5.0 us, 2.5 us | rt: 1-16 us, ft: 1-4 us | CUSP filter parameters |
| `zac` | `rt`, `ft` | 5.0 us, 2.5 us | rt: 1-16 us, ft: 1-4 us | ZAC filter parameters |
| `sg` | `wl` | 100 ns | 30-350 ns (step 32ns) | Savitzky-Golay window length |

**Source:** Merged from `fltopt` (filter optimization) and `aoeopt` (A/E optimization)

**Default Config:** `jldataprod/config/dsp/dsp_default_all.yaml` (flt_defaults)

</details>

<details>
<summary><b>2.5 kwargs_pars (Processing Parameters)</b></summary>

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `sig_interpolation_length` | 700 ns | Window for signal amplitude interpolation |
| `sig_interpolation_order` | 3 | Polynomial order for signal interpolation |
| `int_interpolation_length` | 100 ns | Window for integral interpolation |
| `int_interpolation_order` | 3 | Polynomial order for integral interpolation |
| `fc_bit_depth` | 16 | FlashCam ADC bit depth |
| `t0_flt_pars` | [40, 100, 2000] ns | Trapezoidal filter parameters for t0 |
| `t0_mintot` | 1500 ns | Minimum time-over-threshold for t0 |
| `tx_mintot` | 32 ns | Minimum time-over-threshold for tX |
| `intrace_mintot` | 100 ns | Minimum time-over-threshold for pile-up |

**Source:** `jldataprod/config/dsp/dsp_default_all.yaml` (kwargs_pars)

</details>

---

# 3 Processing Pipeline

<details>
<summary><b>Stage 1: Data Extraction and Decoding</b></summary>

```julia
wvfs_pre = decode_data(data.waveform_presummed)
wvfs_wdw = decode_data(data.waveform_windowed)
presum_rate_value = only(unique(presum_rate))
```

**Technical Details:**
- `wvfs_pre`: Presummed waveform with 128 ns/sample (8 samples of 16 ns averaged)
- `wvfs_wdw`: High-resolution windowed waveform with 16 ns/sample
- The windowed waveform captures the rising edge with full time resolution
- `decode_data()` decompresses the LH5 compressed format

</details>

<details>
<summary><b>Stage 2: Saturation Detection</b></summary>

```julia
bit_depth = config.kwargs_pars.fc_bit_depth  # 16 bit
sat_low, sat_high = 0, (2^bit_depth - bit_depth) * first(presum_rate_value)
sat_stats = saturation.(wvfs_pre, sat_low, sat_high)
```

   <details>
   <summary><i>Sub-Function: saturation()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `LegendDSP.jl/src/dsp_routines.jl` |
   | **Purpose** | Detect ADC saturation at low (0) and high (16368 * presum_rate) limits |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `wvf` | RDWaveform | Input waveform |
   | `sat_low` | Int | Low saturation threshold (typically 0) |
   | `sat_high` | Int | High saturation threshold |

   **Algorithm:**

   The function iterates through all samples to detect saturation events where the ADC reaches its limits. Saturation occurs when the detector signal exceeds the dynamic range of the digitizer.

   ```julia
   for each sample in waveform:
       if sample <= sat_low:
           count_low += 1
           consecutive_low += 1
       else:
           max_consecutive_low = max(max_consecutive_low, consecutive_low)
           consecutive_low = 0
       
       if sample >= sat_high:
           count_high += 1
           consecutive_high += 1
       else:
           max_consecutive_high = max(max_consecutive_high, consecutive_high)
           consecutive_high = 0
   ```

   The algorithm tracks both the total number of saturated samples and the maximum number of consecutive saturated samples. Consecutive saturation is more severe as it indicates complete signal loss during that period, while isolated saturated samples may be recoverable through interpolation.

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `.low` | Int | Total samples at low saturation |
   | `.high` | Int | Total samples at high saturation |
   | `.max_cons_low` | Int | Max consecutive low-saturated samples |
   | `.max_cons_high` | Int | Max consecutive high-saturated samples |

   </details>

</details>

<details>
<summary><b>Stage 3: Baseline Extraction and Subtraction</b></summary>

```julia
bl_stats = signalstats.(wvfs_pre, leftendpoint(bl_window), rightendpoint(bl_window))
wvfs_pre = shift_waveform.(wvfs_pre, -bl_stats.mean)
wvfs_wdw = shift_waveform.(wvfs_wdw, -bl_stats.mean ./ presum_rate_value)
```

   <details>
   <summary><i>Sub-Function: signalstats()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `RadiationDetectorDSP.jl/src/signalstats.jl` |
   | **Purpose** | Calculate statistical properties of signal in a specified time window |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `wvf` | RDWaveform | Input waveform |
   | `t_start` | Quantity | Start of analysis window |
   | `t_stop` | Quantity | End of analysis window |

   **Algorithm:**

   The function calculates baseline statistics using a single-pass algorithm that computes mean, standard deviation, and linear trend simultaneously. This is efficient because it only requires one iteration through the data.

   For each sample `y[i]` at time `x[i]` in the window, the algorithm accumulates:

   ```julia
   n = number of samples in window
   sum_x = sum(x[i])           # sum of time values
   sum_y = sum(y[i])           # sum of signal values
   sum_xx = sum(x[i]^2)        # sum of squared times
   sum_yy = sum(y[i]^2)        # sum of squared signals
   sum_xy = sum(x[i] * y[i])   # sum of products
   ```

   From these accumulated values, the statistics are calculated:

   ```julia
   mean_x = sum_x / n
   mean_y = sum_y / n
   
   # Variance using computational formula
   var_x = sum_xx/n - mean_x^2
   var_y = sum_yy/n - mean_y^2
   
   # Covariance for linear fit
   cov_xy = sum_xy/n - mean_x * mean_y
   
   # Linear regression
   slope = cov_xy / var_x
   offset = mean_y - slope * mean_x
   
   # Standard deviation
   sigma = sqrt(var_y)
   ```

   The mean represents the DC offset (pedestal) from the electronics that must be subtracted. The sigma quantifies the electronic noise level, which is important for energy resolution. The slope and offset characterize any baseline drift during the pre-trigger window, which could indicate leakage current or temperature effects.

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `.mean` | Float | Mean baseline value (ADC units) |
   | `.sigma` | Float | Baseline noise RMS (ADC units) |
   | `.slope` | Float | Baseline drift rate (ADC/time) |
   | `.offset` | Float | Baseline intercept at t=0 |

   </details>

   <details>
   <summary><i>Sub-Function: shift_waveform()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `LegendDSP.jl/src/dsp_routines.jl` |
   | **Purpose** | Subtract baseline offset from waveform to center signal at zero |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `wvf` | RDWaveform | Input waveform |
   | `offset` | Float | Value to subtract |

   **Algorithm:**

   Simple element-wise subtraction of the offset from all samples:

   ```julia
   wvf_shifted.signal = wvf.signal .- offset
   ```

   For the windowed waveform, the baseline is divided by `presum_rate` because the presummed baseline is the sum of 8 samples (each 16 ns), while the windowed waveform has individual 16 ns samples.

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `wvf_shifted` | RDWaveform | Baseline-subtracted waveform |

   </details>

</details>

<details>
<summary><b>Stage 4: Quality Classification (optional)</b></summary>

```julia
qc_labels = if !ismissing(f_evaluate_qc)
    get_qc_classifier_compressed(wvfs_pre, f_evaluate_qc)
else
    zeros(length(wvfs_pre))
end
```

   <details>
   <summary><i>Sub-Function: get_qc_classifier_compressed()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `LegendDSP.jl/src/ml_routines.jl` |
   | **Purpose** | ML-based waveform quality classification to identify problematic waveforms |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `wvfs` | ArrayOfRDWaveforms | Input waveforms |
   | `f_evaluate_qc` | Function | Pre-trained SVM classifier function |

   **Algorithm:**

   The function applies a pre-trained Support Vector Machine (SVM) classifier to each waveform. The classifier was trained on labeled examples of good and bad waveforms to learn distinguishing features.

   First, features are extracted from each waveform, typically including shape characteristics like rise time ratios, baseline stability, and derivative patterns. These features are normalized and passed to the SVM.

   The SVM finds an optimal hyperplane in feature space that separates good from bad waveforms. The decision function computes:

   ```
   decision = sign(sum(alpha_i * y_i * K(x, x_i)) + b)
   ```

   where K is the kernel function (typically RBF), alpha_i are learned weights, and x_i are support vectors from training.

   **Output:**
   | Value | Description |
   |-------|-------------|
   | `0` | Good waveform - proceed with normal processing |
   | `1` | Bad waveform - noise, pile-up, discharge, or other artifact |

   </details>

</details>

<details>
<summary><b>Stage 5: Decay Time Extraction (before PZ)</b></summary>

```julia
tail_stats = tailstats.(wvfs_pre, leftendpoint(tail_window), rightendpoint(tail_window))
```

   <details>
   <summary><i>Sub-Function: tailstats()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `LegendDSP.jl/src/dsp_routines.jl` |
   | **Purpose** | Extract preamplifier decay time constant from waveform tail |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `wvf` | RDWaveform | Input waveform (before PZ correction) |
   | `t_start` | Quantity | Start of tail window (e.g., 50 us) |
   | `t_stop` | Quantity | End of tail window (e.g., 90 us) |

   **Algorithm:**

   The preamplifier output decays exponentially after the signal pulse according to:

   ```
   y(t) = A * exp(-t/tau) + C
   ```

   where A is the initial amplitude, tau is the decay time constant, and C is any residual offset. To extract tau, we linearize by taking the natural logarithm:

   ```
   ln(y - C) = ln(A) - t/tau
   ```

   This transforms the exponential decay into a linear relationship where the slope is -1/tau.

   The algorithm performs a linear regression on ln(signal) vs time:

   ```julia
   # Sample the tail region
   y_tail = wvf.signal[t_start:t_stop]
   t_tail = time_axis[t_start:t_stop]
   
   # Linearize (assuming C is small or already subtracted)
   log_y = log.(y_tail)
   
   # Linear fit: log_y = a + b * t, where b = -1/tau
   slope, intercept = linear_fit(t_tail, log_y)
   
   tau = -1 / slope
   ```

   Additionally, the mean and sigma of the tail are computed to assess tail quality. A flat tail (low sigma) after PZ correction indicates good pole-zero matching.

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `.tau` | Quantity | Extracted decay time constant |
   | `.mean` | Float | Mean of tail signal |
   | `.sigma` | Float | Standard deviation of tail |

   </details>

</details>

<details>
<summary><b>Stage 6: Pole-Zero Correction</b></summary>

```julia
deconv_flt = InvCRFilter(tau)
wvfs_pre = deconv_flt.(wvfs_pre)
wvfs_wdw = deconv_flt.(wvfs_wdw)
```

   <details>
   <summary><i>Sub-Function: InvCRFilter(tau)</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `RadiationDetectorDSP.jl/src/circuit_filters.jl` |
   | **Purpose** | Deconvolve preamplifier RC response to create flat-topped pulses |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `tau` | Quantity | Preamplifier decay time constant |

   **Algorithm:**

   The charge-sensitive preamplifier has an RC feedback circuit that causes the output to decay exponentially. In the frequency domain, this is a high-pass CR filter with transfer function:

   ```
   H(s) = s*tau / (1 + s*tau)
   ```

   To recover the original step-like charge signal, we apply the inverse filter:

   ```
   H_inv(s) = (1 + s*tau) / (s*tau) = 1/(s*tau) + 1
   ```

   In the digital domain, this becomes a first-order IIR (Infinite Impulse Response) filter. The implementation uses the bilinear transform with sampling period dt:

   ```julia
   CR = tau / dt  # normalized time constant in samples
   k = 1 + 1/CR   # filter coefficient
   ```

   The difference equation is:

   ```julia
   y[n] = k * x[n] + (1-k) * x[n-1] + y[n-1]
   ```

   which can be rewritten as:

   ```julia
   y[n] = k * x[n] - (k-1) * x[n-1] + y[n-1]
   ```

   The filter is implemented using FirstOrderIIR with coefficients:
   - Numerator (b): [k, -(k-1)] = [k, 1-k]
   - Denominator (a): [-1]

   The effect on the waveform is to transform the exponentially decaying tail into a flat plateau at the energy level:

   ```
   Before PZ:              After PZ:
        ____                    ________
       /    \                  |        |
      /      \____        -->  |        |____
   __/             \___      __|
   ```

   Without PZ correction, energy filters would underestimate the energy due to ballistic deficit (the signal decays before the filter completes integration).

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `wvf_pz` | RDWaveform | PZ-corrected waveform with flat plateau |

   </details>

</details>

<details>
<summary><b>Stage 7: Timing Extraction</b></summary>

```julia
t0 = get_t0(wvfs_wdw, t0_threshold; flt_pars=config.kwargs_pars.t0_flt_pars, mintot=config.kwargs_pars.t0_mintot)
t10 = get_threshold(wvfs_wdw, wvf_max_wdw .* 0.1; mintot=config.kwargs_pars.tx_mintot)
t50 = get_threshold(wvfs_wdw, wvf_max_wdw .* 0.5; mintot=config.kwargs_pars.tx_mintot)
t80 = get_threshold(wvfs_wdw, wvf_max_wdw .* 0.8; mintot=config.kwargs_pars.tx_mintot)
t90 = get_threshold(wvfs_wdw, wvf_max_wdw .* 0.9; mintot=config.kwargs_pars.tx_mintot)
t99 = get_threshold(wvfs_wdw, wvf_max_wdw .* 0.99; mintot=config.kwargs_pars.tx_mintot)

drift_time = uconvert.(u"ns", t90 - t0)
```

   <details>
   <summary><i>Sub-Function: get_t0()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `LegendDSP.jl/src/dsp_routines.jl` |
   | **Purpose** | Detect signal onset time using filtered threshold crossing |

   **Input:**
   | Parameter | Type | Default | Description |
   |-----------|------|---------|-------------|
   | `wvfs` | ArrayOfRDWaveforms | - | PZ-corrected waveforms |
   | `threshold` | Float | 4.0 | Fixed threshold (ADC units) |
   | `flt_pars` | Vector{Time} | [40ns, 100ns, 2000ns] | Trap filter parameters |
   | `mintot` | Time | 1500ns | Minimum time-over-threshold |

   **Algorithm:**

   Finding t0 (signal onset) is critical because all timing parameters reference this point. The raw waveform is noisy, so a filter is applied first to enhance the rising edge.

   Step 1: Apply asymmetric trapezoidal filter to enhance the rising edge while suppressing noise:

   ```julia
   flt = TrapezoidalChargeFilter(flt_pars[1], flt_pars[2], flt_pars[3])
   # Default: TrapezoidalChargeFilter(40ns, 100ns, 2000ns)
   wvf_filtered = flt(wvf)
   ```

   The asymmetric design (short rise, longer averaging) provides good timing precision while averaging out high-frequency noise.

   Step 2: Find threshold crossing with minimum time-over-threshold requirement:

   ```julia
   intersect_result = Intersect(threshold, mintot)(wvf_filtered)
   ```

   The mintot parameter (1500 ns) ensures the signal stays above threshold for a minimum time, rejecting noise spikes that briefly cross threshold.

   Step 3: Linear interpolation for sub-sample precision:

   ```julia
   # Find index i where signal crosses threshold
   t0 = t[i-1] + (threshold - y[i-1]) * (t[i] - t[i-1]) / (y[i] - y[i-1])
   ```

   This gives timing precision better than the 16 ns sampling period.

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `t0` | Vector{Quantity} | Signal onset times in microseconds |

   </details>

   <details>
   <summary><i>Sub-Function: get_threshold()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `LegendDSP.jl/src/dsp_routines.jl` |
   | **Purpose** | Find time when waveform crosses a specified threshold level |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `wvfs` | ArrayOfRDWaveforms | Input waveforms |
   | `threshold` | Vector{Float} | Threshold per waveform (e.g., 0.5 * max) |
   | `mintot` | Time | Minimum time-over-threshold |

   **Algorithm:**

   Unlike get_t0 which uses a fixed threshold, get_threshold uses amplitude-relative thresholds (e.g., 10%, 50%, 90% of maximum). This makes the timing robust against amplitude variations.

   ```julia
   for each waveform, threshold pair:
       intersect_result = Intersect(threshold, mintot)(wvf)
       t_cross = intersect_result.x
   ```

   The mintot requirement prevents false triggers on noise fluctuations.

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `t_cross` | Vector{Quantity} | Threshold crossing times |

   **Physics Application:**
   - `t10`: Start of charge collection (10% level)
   - `t50`: Used for filter timing alignment
   - `t90`: End of main drift period
   - `drift_time = t90 - t0`: Total charge collection time, sensitive to event location

   </details>

   <details>
   <summary><i>Sub-Function: Intersect()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `RadiationDetectorDSP.jl/src/intersect.jl` |
   | **Purpose** | Find intersection of signal with threshold, with minimum time-over-threshold |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `threshold` | Float | Threshold level to detect |
   | `mintot` | Time | Minimum time signal must stay above threshold |

   **Algorithm:**

   This filter is designed to be GPU-friendly (branch-free) while robustly detecting threshold crossings. The mintot parameter is crucial for noise rejection.

   The algorithm scans through samples, tracking how long the signal has been above threshold:

   ```julia
   y_high_counter = 0        # samples above threshold
   candidate_position = 0    # potential crossing point
   intersect_position = 0    # confirmed crossing point

   for i in 1:length(signal)
       y_is_high = signal[i] >= threshold
       first_high = (y_high_counter == 0)
       
       # Record candidate when signal first goes high
       if y_is_high && first_high
           candidate_position = i
       end
       
       # Update counter
       if y_is_high
           y_high_counter += 1
       else
           y_high_counter = 0  # reset on low
       end
       
       # Confirm crossing when signal stays high for mintot
       if y_high_counter == min_samples_over_thresh
           intersect_position = candidate_position
       end
   end
   ```

   Once the crossing sample is found, linear interpolation gives sub-sample precision:

   ```julia
   # y[i-1] < threshold <= y[i]
   x_intersect = x[i-1] + (threshold - y[i-1]) * dt / (y[i] - y[i-1])
   ```

   This assumes the signal changes linearly between samples, which is valid for the 16 ns sampling of the windowed waveform.

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `.x` | Quantity | Precise crossing time |
   | `.multiplicity` | Int | Number of crossings (1 = clean signal) |

   </details>

</details>

<details>
<summary><b>Stage 8: Pulse Shape Parameters (Q-drift, LQ)</b></summary>

```julia
qdrift = get_qdrift(wvfs_wdw, t0, qdrift_int_length; pol_power=3, sign_est_length=100u"ns")
lq = get_qdrift(wvfs_wdw, t80, lq_int_length; pol_power=3, sign_est_length=100u"ns")
```

   <details>
   <summary><i>Sub-Function: get_qdrift()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `LegendDSP.jl/src/dsp_routines.jl` |
   | **Purpose** | Calculate integrated charge in specific time regions for pulse shape discrimination |

   **Input:**
   | Parameter | Type | Default | Description |
   |-----------|------|---------|-------------|
   | `wvfs` | ArrayOfRDWaveforms | - | PZ-corrected waveforms |
   | `t_start` | Vector{Quantity} | - | Start time (t0 or t80) |
   | `int_length` | Quantity | - | Integration length |
   | `pol_power` | Int | 3 | Polynomial interpolation order |
   | `sign_est_length` | Quantity | 100ns | Interpolation window |

   **Algorithm:**

   This function calculates the integrated charge in a time window, which is sensitive to the charge collection dynamics in the detector.

   Step 1: Create integrated waveform using cumulative sum:

   ```julia
   integrator = IntegratorFilter(1)
   wvf_integrated = integrator(wvf)
   # wvf_integrated[n] = sum(wvf[1:n]) * dt
   ```

   Step 2: Define integration boundaries relative to t_start:

   ```julia
   t1 = t_start
   t2 = t_start + delta_t_first   # intermediate point
   t3 = t_start + delta_t_last    # end of integration
   ```

   Step 3: Use polynomial interpolation for precise amplitude at boundaries:

   ```julia
   estimator = SignalEstimator(PolynomialDNI(pol_power, sign_est_length))
   
   int_value_1 = estimator(wvf_integrated, t1)
   int_value_2 = estimator(wvf_integrated, t2)
   int_value_3 = estimator(wvf_integrated, t3)
   ```

   The PolynomialDNI (Digital to Numeric Interpolation) fits a polynomial of degree `pol_power` to samples within `sign_est_length` and evaluates at the exact time point.

   Step 4: Calculate charge difference:

   ```julia
   area_early = int_value_2 - int_value_1
   area_late = int_value_3 - int_value_2
   qdrift = area_late - area_early
   ```

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `qdrift` | Vector{Float} | Charge drift parameter |

   **Physics - Q-drift:**
   Q-drift (integration from t0) measures the charge collection rate. Single-site events (SSE) have more uniform charge collection, while multi-site events (MSE) have charge arriving from different locations at different times.

   **Physics - LQ (Late Charge):**
   LQ (integration from t80) is sensitive to slow charge collection that occurs after the main signal. Surface events (alpha contamination) have slower final charge collection, giving different LQ values compared to bulk events.

   </details>

</details>

<details>
<summary><b>Stage 9: Energy Reconstruction (Fixed Parameters)</b></summary>

```julia
uflt_10410 = TrapezoidalChargeFilter(10u"us", 4u"us")
e_10410 = maximum.((uflt_10410.(wvfs_pre)).signal)

uflt_535 = TrapezoidalChargeFilter(5u"us", 3u"us")
e_535 = maximum.((uflt_535.(wvfs_pre)).signal)

uflt_313 = TrapezoidalChargeFilter(3u"us", 1u"us")
e_313 = maximum.((uflt_313.(wvfs_pre)).signal)
```

   <details>
   <summary><i>Sub-Function: TrapezoidalChargeFilter()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `RadiationDetectorDSP.jl/src/trapezoidal_filter.jl` |
   | **Purpose** | Shape waveform into trapezoid for optimal energy measurement |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `rise_time` | Quantity | Filter rise time (L) |
   | `flat_top` | Quantity | Filter flat-top time (G) |

   **Algorithm:**

   The trapezoidal filter is the standard energy filter in gamma spectroscopy. It transforms a step input into a trapezoidal output, with the flat-top height proportional to the step amplitude (energy).

   The filter is implemented as the difference of two moving averages:

   ```julia
   # Moving average of length L
   MA(x, L) = (1/L) * sum(x[n-L+1:n])
   
   # Trapezoidal filter
   y[n] = MA(x, L)[n] - MA(x, L)[n - L - G]
   ```

   Equivalently, in terms of delay and difference operators:

   ```julia
   y[n] = (1/L) * sum(x[n-i] - x[n-L-G-i] for i in 0:L-1)
   ```

   The filter response to a step input (charge signal) is:

   ```
   Input (step):        Output (trapezoid):
                               ___________
   ___|‾‾‾‾‾‾‾‾‾        -->   /           \
                             /             \
                        ____/               \____
                            |<L>|<-G->|<L>|
   ```

   The flat-top region occurs L to L+G samples after the step edge. Energy is extracted from this flat region.

   **Filter Variants:**

   | Name | Rise (L) | Flat-top (G) | Total | Use Case |
   |------|----------|--------------|-------|----------|
   | `e_10410` | 10 us | 4 us | 24 us | Best resolution - maximum noise averaging |
   | `e_535` | 5 us | 3 us | 13 us | Medium - balance of resolution and rate |
   | `e_313` | 3 us | 1 us | 7 us | High rate - pile-up tolerant |

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `e_trap` | Float | Maximum of filtered waveform (energy) |

   **Physics:**
   - Longer rise time averages more samples, reducing statistical noise
   - Longer flat-top corrects for ballistic deficit (signal variation during collection)
   - Trade-off: longer filters are more susceptible to pile-up

   </details>

</details>

<details>
<summary><b>Stage 10: Energy Reconstruction (Optimized Parameters)</b></summary>

```julia
signal_estimator = SignalEstimator(PolynomialDNI(config.kwargs_pars.sig_interpolation_order, 
                                                  config.kwargs_pars.sig_interpolation_length))

uflt_trap_rtft = TrapezoidalChargeFilter(trap_rt, trap_ft)
wvfs_flt = uflt_trap_rtft.(wvfs_pre)
e_trap = signal_estimator.(wvfs_flt, t50_pre .+ (trap_rt + trap_ft/2))
```

   <details>
   <summary><i>Sub-Function: SignalEstimator with PolynomialDNI</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `RadiationDetectorDSP.jl/src/signal_estimator.jl` |
   | **Purpose** | Sub-sample amplitude estimation using polynomial interpolation |

   **Input:**
   | Parameter | Type | Typical | Description |
   |-----------|------|---------|-------------|
   | `order` | Int | 3 | Polynomial degree |
   | `length` | Quantity | 100ns | Interpolation window |

   **Algorithm:**

   While `maximum()` gives the largest sample value, it is limited to the discrete sampling grid. PolynomialDNI (Digital to Numeric Interpolation) provides sub-sample precision by fitting a polynomial and evaluating at the optimal time.

   Step 1: Select samples around the evaluation time t:

   ```julia
   window_start = t - length/2
   window_end = t + length/2
   samples = wvf[window_start:window_end]
   times = time_axis[window_start:window_end]
   ```

   Step 2: Fit polynomial of specified order:

   ```julia
   # For order=3 (cubic): p(x) = a0 + a1*x + a2*x^2 + a3*x^3
   coefficients = polynomial_fit(times, samples, order)
   ```

   The fit uses least-squares regression to find coefficients that minimize the sum of squared residuals.

   Step 3: Evaluate polynomial at precise time:

   ```julia
   amplitude = evaluate_polynomial(coefficients, t)
   ```

   **Optimal Evaluation Time:**

   The energy is evaluated at `t50_pre + trap_rt + trap_ft/2`, which corresponds to:
   - `t50_pre`: 50% rise time on presummed waveform
   - `trap_rt`: Rise time of trapezoidal filter
   - `trap_ft/2`: Middle of flat-top

   This places the evaluation in the center of the flat-top region, where the filter output is most stable.

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `amplitude` | Float | Interpolated amplitude at evaluation time |

   </details>

   <details>
   <summary><i>Sub-Function: CUSPChargeFilter()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `RadiationDetectorDSP.jl/src/cusp_filter.jl` |
   | **Purpose** | CUSP-shaped energy filter optimized for 1/f noise |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `rt` | Quantity | Rise time |
   | `ft` | Quantity | Flat-top time |
   | `tau` | Quantity | Time constant (set very large) |
   | `length` | Quantity | Total filter length |

   **Algorithm:**

   The CUSP filter has a cusp-shaped weighting function that gives higher weight to samples near the center and lower weight to samples at the edges:

   ```
   Trapezoidal:       CUSP:
        _____              /\
       /     \            /  \
      /       \          /    \
   __/         \__    __/      \__
   ```

   This shape is optimal for suppressing 1/f (pink) noise, which is common in semiconductor detectors. The mathematical form involves exponential weighting:

   ```julia
   weight(t) = exp(-|t - t_center| / tau_eff)
   ```

   In implementation, tau is set very large (10^7 us) to effectively disable the CR component, making it a pure cusp shaper.

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `e_cusp` | Float | CUSP filter energy |

   </details>

   <details>
   <summary><i>Sub-Function: ZACChargeFilter()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `RadiationDetectorDSP.jl/src/zac_filter.jl` |
   | **Purpose** | Zero Area Cusp filter for robust baseline handling |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `rt` | Quantity | Rise time |
   | `ft` | Quantity | Flat-top time |
   | `tau` | Quantity | Time constant |
   | `length` | Quantity | Total filter length |

   **Algorithm:**

   The ZAC (Zero Area Cusp) filter is a variant of CUSP with an additional constraint: the filter weights sum to zero. This zero-area property ensures perfect baseline restoration.

   ```
   Constraint: integral(weight(t)) dt = 0
   ```

   This means any DC offset in the input is completely removed from the output. The filter shape has positive weights in the center and negative weights at the edges:

   ```
         /\
        /  \
   ____/    \____
      \      /
       \    /
        \__/
   ```

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `e_zac` | Float | ZAC filter energy |

   **Advantage over CUSP:**
   Better performance when baseline is unstable or drifting, at slight cost to optimal noise performance.

   </details>

</details>

<details>
<summary><b>Stage 11: Current Signal Extraction (A/E)</b></summary>

```julia
a_raw = get_wvf_maximum.(DerivativeFilter(1).(wvfs_wdw), leftendpoint(current_window), rightendpoint(current_window))
a_sg = get_wvf_maximum.(SavitzkyGolayFilter(sg_wl, sg_flt_degree, 1).(wvfs_wdw), ...)
a_60 = get_wvf_maximum.(SavitzkyGolayFilter(60u"ns", sg_flt_degree, 1).(wvfs_wdw), ...)
a_100 = get_wvf_maximum.(SavitzkyGolayFilter(100u"ns", sg_flt_degree, 1).(wvfs_wdw), ...)
```

   <details>
   <summary><i>Sub-Function: SavitzkyGolayFilter()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `RadiationDetectorDSP.jl/src/sg_filter.jl` |
   | **Purpose** | Compute smoothed derivative for current signal extraction |

   **Input:**
   | Parameter | Type | Typical | Description |
   |-----------|------|---------|-------------|
   | `window_length` | Quantity | 60-150 ns | Smoothing window |
   | `degree` | Int | 2 | Polynomial degree |
   | `derivative` | Int | 1 | Derivative order |

   **Algorithm:**

   The Savitzky-Golay filter computes a smoothed derivative by fitting a polynomial to a local window and evaluating the derivative of that polynomial. This is much more robust than simple finite differences.

   For each point, the algorithm:

   Step 1: Extract samples in window centered on current point:

   ```julia
   window_samples = signal[i - half_width : i + half_width]
   ```

   Step 2: Fit polynomial of specified degree:

   ```julia
   # For degree=2: p(x) = a0 + a1*x + a2*x^2
   coefficients = least_squares_fit(window_samples)
   ```

   Step 3: Evaluate derivative at center:

   ```julia
   # First derivative: p'(x) = a1 + 2*a2*x
   # At center (x=0): p'(0) = a1
   derivative_value = coefficients[1]  # a1 coefficient
   ```

   This is equivalent to convolution with pre-computed Savitzky-Golay coefficients, which is computationally efficient.

   **Noise Reduction:**

   Simple differentiation amplifies high-frequency noise. The SG filter's polynomial smoothing acts as a low-pass filter while preserving the signal shape:

   ```
   Noise amplification:    SG filter:
   
   Raw derivative          Smooth derivative
       /\/\/\                   /\
      /      \                 /  \
   __/        \__           __/    \__
   ```

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `current_signal` | RDWaveform | Smoothed first derivative |

   </details>

   <details>
   <summary><i>Sub-Function: DerivativeFilter()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `RadiationDetectorDSP.jl/src/derivative_filter.jl` |
   | **Purpose** | Simple numerical derivative |

   **Input:**
   | Parameter | Type | Description |
   |-----------|------|-------------|
   | `order` | Int | Derivative order (1 = first derivative) |

   **Algorithm:**

   Simple finite difference approximation:

   ```julia
   y[n] = (x[n] - x[n-1]) / dt
   ```

   This gives the raw derivative without smoothing. Used as `a_raw` for comparison with smoothed versions.

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `derivative` | RDWaveform | Numerical derivative |

   </details>

   <details>
   <summary><i>Physics: A/E Parameter</i></summary>

   | Property | Value |
   |----------|-------|
   | **Purpose** | Pulse shape discrimination between single-site and multi-site events |

   **Current Signal:**

   The current signal I(t) represents the instantaneous charge collection rate:

   ```
   I(t) = dQ/dt = C * dV/dt
   ```

   where Q is charge, V is voltage (waveform), and C is the detector capacitance.

   **A/E Discrimination:**

   The A/E parameter is the ratio of current amplitude (A) to energy (E):

   ```
   A/E = max(I(t)) / E
   ```

   **Physics Basis:**

   - **Single-site events (SSE):** Energy deposited at one location. Charge drifts from one point, creating a sharp, high current peak.

   - **Multi-site events (MSE):** Energy deposited at multiple locations (Compton scattering). Charges drift from different distances, spreading the current over time.

   ```
   SSE:                 MSE:
   Sharp peak           Broad peak
       |                  /\
       |                 /  \
    /\ |              /\/    \/\
   /  \|__          _/          \_
   
   High A/E           Low A/E
   ```

   **Application:**

   For neutrinoless double-beta decay (0vbb) search:
   - Signal (0vbb): Single-site, high A/E
   - Background (gamma): Often multi-site, low A/E
   - A/E cut removes ~90% of gamma background

   </details>

</details>

<details>
<summary><b>Stage 12: Pile-up Detection</b></summary>

```julia
wvfs_sgflt_deriv = SavitzkyGolayFilter(sg_wl * presum_rate_value / 2, sg_flt_degree, 1).(wvfs_pre)
inTrace_pileUp = get_intracePileUp(wvfs_sgflt_deriv, inTraceCut_std_threshold, bl_window; mintot=...)
```

   <details>
   <summary><i>Sub-Function: get_intracePileUp()</i></summary>

   | Property | Value |
   |----------|-------|
   | **Source** | `LegendDSP.jl/src/dsp_routines.jl` |
   | **Purpose** | Detect additional pulses within the waveform trace |

   **Input:**
   | Parameter | Type | Typical | Description |
   |-----------|------|---------|-------------|
   | `wvfs_deriv` | ArrayOfRDWaveforms | - | Derivative waveforms |
   | `threshold_sigma` | Float | 3.0 | Threshold in units of sigma |
   | `bl_window` | Interval | 0..2 us | Window for noise estimation |
   | `mintot` | Time | - | Minimum time-over-threshold |

   **Algorithm:**

   Pile-up occurs when a second pulse arrives before the first one has fully decayed. This corrupts the energy measurement and must be detected.

   Step 1: Calculate noise level from baseline region:

   ```julia
   bl_samples = wvf_deriv[bl_window]
   sigma = std(bl_samples)
   threshold = sigma * threshold_sigma  # e.g., 3*sigma
   ```

   Step 2: Reverse the derivative waveform:

   ```julia
   wvf_reversed = reverse(wvf_deriv)
   ```

   Reversing is done because we want to find pulses that occur AFTER the main pulse. The Intersect filter finds the first crossing, so reversing makes it find later events first.

   Step 3: Find threshold crossings using Intersect:

   ```julia
   crossings = Intersect(threshold, mintot)(wvf_reversed)
   ```

   Step 4: Map positions back to original time axis:

   ```julia
   pile_up_time = total_time - crossings.x
   ```

   **Output:**
   | Field | Type | Description |
   |-------|------|-------------|
   | `.intersect` | Vector{Quantity} | Position of pile-up pulse |
   | `.n` | Vector{Int} | Multiplicity (0 = no pile-up) |

   **Usage:**

   Events with `n > 0` should be flagged or rejected in energy analysis, as the measured energy will be the sum of multiple events.

   </details>

</details>

<details>
<summary><b>Stage 13: DC Tagging (Inverted Waveform Analysis)</b></summary>

```julia
wvfs_pre = multiply_waveform.(wvfs_pre, -1.0)
wvfs_wdw = multiply_waveform.(wvfs_wdw, -1.0)

e_10410_max_inv = maximum.(uflt_10410.(wvfs_pre).signal)
e_313_max_inv = maximum.(uflt_313.(wvfs_pre).signal)
t0_inv = get_t0(wvfs_wdw, t0_threshold; mintot=...)
```

   <details>
   <summary><i>Physics: Delayed Charge (DC) Events</i></summary>

   | Property | Value |
   |----------|-------|
   | **Purpose** | Identify events with charge trapping and delayed release |

   **What are DC events?**

   In HPGe detectors, charge carriers (electrons and holes) can be temporarily trapped at crystal defects or impurities. This trapped charge is released after a delay ranging from microseconds to milliseconds.

   **Waveform Signature:**

   DC events show a characteristic "pre-pulse" before the main signal:

   ```
   Normal Event:          DC Event:
         ____                  ____
        /    |                /    |
       /     |               /     |
      /      |____          /      |____
   __/                   __/
                            ^
                      Pre-pulse from 
                      delayed charge
   ```

   The pre-pulse appears because charge released from a previous event arrives during the baseline period of the current event.

   **Detection Method:**

   Step 1: Invert the waveform by multiplying by -1:

   ```julia
   wvf_inverted = wvf * (-1)
   ```

   Step 2: Apply energy filters to inverted waveform:

   ```julia
   e_inv = maximum(trap_filter(wvf_inverted))
   ```

   Step 3: Significant inverted energy indicates pre-pulse:

   ```
   Original:              Inverted:
        ____                   ____
       /    |                 |    \
   ___/     |____   -->   ____|     \_____
      v                        ^
   Pre-pulse            Becomes positive peak
   (negative)           (measurable energy)
   ```

   **Output Parameters:**
   - `e_10410_inv`: Inverted energy with long filter
   - `e_313_inv`: Inverted energy with short filter
   - `t0_inv`: Onset time of inverted signal

   **Usage:**

   Events with significant `e_inv > threshold` are flagged as potential DC events and may require special handling or rejection.

   </details>

</details>

---

# 4 Output Table

**Returns:** `TypedTables.Table` with all extracted parameters.

See [processor_flow.md](../processor_flow.md#311-hpge-output-dsp_icpc_compressed) for complete column documentation.
