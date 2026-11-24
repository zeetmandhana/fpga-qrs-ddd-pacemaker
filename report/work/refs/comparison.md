# P17 report: research comparison data

Checked 2026-11-20. Citation keys refer to `references.md` in this folder.

Key to the "Source" column:

- **FT**: read in the paper's full text.
- **ABS**: read in the abstract only.
- **SEC**: taken from a later paper that tabulates the work. The citing paper is named.
- **DER**: derived by us with simple arithmetic from a table that was read in full.

`n/r` means the paper does not report the value. `n/v` means not verified (the full text was not available to check).

Definitions used everywhere: Se = TP/(TP+FN), +P = TP/(TP+FP).

---

## (a) Published QRS detectors evaluated on MIT-BIH

| Method [key] | Se (%) | +P (%) | Records / beats used | Match tolerance | Source |
|---|---|---|---|---|---|
| Pan & Tompkins 1985, as published [pan1985] | abstract: detects 99.3 % of QRS complexes (see note 1). Table I gives Se 99.76 | Table I gives 99.56 | All 48 records, whole 24 h, 116,137 beats; FP 507, FN 277; "failed detection" 784 beats = 0.675 % | Not stated. Detector pulses were compared visually with the annotation-track pulses on an oscilloscope/chart recorder | FT (Table I); Se/+P are DER |
| Pan & Tompkins 1985, **our five records only** (100, 101, 106, 208, 234) | 99.84 | 99.88 | 11,874 beats; FP 14, FN 19 (record 208 alone: FP 4, FN 14) | As above | DER from FT Table I |
| Hamilton & Tompkins 1986 [hamilton1986] | 99.69 | 99.77 | MIT/BIH database. 109,267 beats, FP 248, FN 340 per Di Marco 2011 Table 4 | n/v | ABS (Se, +P); SEC [dimarco2011] (counts) |
| Hamilton-Tompkins re-implemented by Arzeno et al. 2008 [arzeno2008] | 99.68 | 99.63 | 48 records, ventricular-flutter episodes of record 207 excluded; TP 109,099, FP 405, FN 354 | Not specified in the paper | ABS + author manuscript |
| Li, Zheng & Tai 1995, wavelet [li1995] | abstract: "above 99.8 %" detection rate; 99.89 per SEC | 99.94 per SEC | 104,182 beats (FP 65, FN 112) per [dimarco2011]. Records 214 and 215 excluded per [elgendi2013] | n/v | ABS; SEC |
| Martínez et al. 2004, wavelet delineator [martinez2004] | abstract: Se and +P both over 99.8 %; 99.80 per SEC | 99.86 per SEC | First lead; 109,428 beats (FP 153, FN 220); ventricular-flutter segments of record 207 excluded (per [dimarco2011]). Abstract also gives 99.66 / 99.56 % over more than 980,000 beats across all its validation databases | n/v | ABS; SEC [dimarco2011], [elgendi2013] |
| Elgendi 2013, two moving averages + knowledge-based thresholds [elgendi2013] | 99.78 | 99.87 | All 48 records, 109,985 beats, nothing excluded, first channel. **MIT-BIH was also the parameter-optimisation (training) set** | Not stated (searched the full text) | FT (Tables 2-3) |
| Di Marco & Chiari 2011, 32-bit integer online wavelet [dimarco2011] | 99.77 | 99.86 | First channel, 109,010 beats, FP 148, FN 252; ventricular-flutter segments of record 207 excluded | 150 ms, citing ANSI/AAMI EC57:1998 | FT |
| Cvikl, Jager & Žemva 2007, delay-coordinate mapping (FPGA) [cvikl2007] | 99.82 | 99.82 | First channel of all 48 records, full length; 109,494 beats, FP 200, FN 200. The algorithm was **developed on** MIT-BIH (resampled to 250 Hz) | Not stated | FT (Table 1) |
| Cvikl 2007, **our five records only** | 99.87 | 99.94 | 11,873 beats; TP 11,857, FP 7, FN 16 (record 208: FP 3, FN 13) | Not stated | DER from FT Table 1 |
| Chen et al. 2020, exponential transform + PD-controlled threshold [chen2020], software | 99.90 | 99.92 | 109,496 beats (record-207 flutter excluded). With the whole database (109,966 beats): 99.80 / 99.92 | **300 ms** (the authors' own definition) | FT |
| Chen et al. 2020, **our five records only** (software, per-record Table 2) | 99.92 | 99.95 | 11,873 beats; TP 11,864, FP 6, FN 9 (record 208: FP 3, FN 9) | 300 ms | DER from FT |
| **This work: hardware, bit-exact integer** | **99.55** | **99.92** | Whole records 100, 101, 106, 208, 234; 11,873 beats; TP 11,820, FP 9, FN 53 | ±150 ms | measured (given) |
| **This work: floating-point reference** | 99.13 | 99.86 | Same five records | ±150 ms | measured (given) |

Notes:

1. **The 99.3 % in Pan & Tompkins is not a sensitivity.** Table I reports "failed detection" as (FP + FN) / total beats = 784 / 116,137 = 0.675 %. The paper's summary says the detector missed or mis-detected only 0.675 % of beats, and 100 − 0.675 = 99.3. Our figure on the same measure is (9 + 53) / 11,873 = 0.52 % failed, which is 99.48 %. For P&T on the same five records it is 33 / 11,874 = 0.28 %, which is 99.72 %.
2. Elgendi re-ran Pan-Tompkins himself (thresholding code taken from DigiScope) on all 109,985 beats and got Se 90.95 % / +P 99.56 % (his Table 3). Published Pan-Tompkins results depend heavily on the implementation details.
3. Tolerance windows differ (150 ms vs 300 ms vs unstated), and so do the beat sets and annotation versions. P&T's 1980-era tape gives 11,874 beats for our five records, while the current annotations give 11,873. The rows are only roughly comparable. The fairest comparisons are the three "our five records only" rows.
4. On the same five records, three published detectors (P&T 1985, Cvikl 2007, Chen 2020) report Se of 99.84 to 99.92 %. That is higher than our 99.55 %. Our +P of 99.92 % is in their range (99.88 to 99.95 %). In all three published tables, **record 208 causes most of the false negatives** (14 of 19, 13 of 16 and 9 of 9 FN respectively). It is worth checking our per-record FN breakdown against this.

---

## (b) FPGA / ASIC QRS-detector implementations

Resource units differ by vendor and generation and are not directly comparable. A Cyclone LC is roughly a 4-input LUT plus a flip-flop. A Cyclone V ALM is an adaptive, fracturable 8-input cell. A Xilinx 6/7-series LUT is a 6-input LUT.

| Work [key] | Device | Algorithm | Logic | FF | DSP / mult. | Memory | Clock | Power | Accuracy reported | Source |
|---|---|---|---|---|---|---|---|---|---|---|
| **This work: HLS filter chain** | Xilinx Zynq-7010 xc7z010clg400-1 (Zybo Z7-10) | P&T band-pass, derivative, squaring, MWI (integer) | 571 LUT (3.2 % of 17,600) | 563 (1.6 % of 35,200) | 3 DSP | 0 BRAM | 130 MHz achievable (post-route) | 0.355 W, whole-board SoC, Vivado vectorless estimate (not detector-only) | Se 99.55 / +P 99.92, 5 records, ±150 ms | measured (given); device totals from [zybo] |
| **This work: RTL decision stage** | same | Adaptive dual thresholds, search-back, T-wave check, refractory | 2,533 LUT (14.4 %) | 1,723 (4.9 %) | not given | not given | n/a | (included above) | (detector total) | measured (given) |
| Cvikl et al. 2007 [cvikl2007] | Xilinx Virtex-II XC2V3000 | Modified delay-coordinate (phase-space area) mapping | About 17 % of the device, including the communication logic (a soft-core microcontroller and serial interface) | n/r | n/r | n/r | 82 MHz estimated; run at 5 MHz in tests | n/r | Se 99.82 / +P 99.82, MIT-BIH, 48 records, 109,494 beats | FT |
| Stojanović et al. 2011 [stojanovic2011] | Altera Cyclone EP1C12Q240 | Integer (S-transform) wavelet, 4 levels, zero-crossing detection | 651 LC of 5,980 (about 11 %) | n/r | n/r (adders and shifters, no multipliers needed) | n/r | 27.23 MHz max | n/r | About 95.2 % average accuracy, defined as 1 − (FP+FN)/N, on 105,200 beats from 10 **own recordings (not MIT-BIH)** | FT |
| Chen et al. 2020 [chen2020] | Intel/Altera Cyclone V 5CSEMA5F31C6 | Exponential transform + PD-controlled adaptive threshold (includes floating-point to integer conversion) | 22,332 ALM (70 %) | n/r | 87 DSP blocks (100 %) | 262,144 memory bits (6 %) | 50 MHz processing (data read at 500 kHz); about 1.3 s per 30-min record | n/r | Hardware: Se 99.85 / +P 99.93 on 109,496 beats (TP 109,326, FP 73, FN 170); 300 ms window | FT |
| Madiraju et al. 2018, arXiv preprint [madiraju2018] | Xilinx Virtex-6, stated as XC6VLX240T (see note) | Pan-Tompkins + ECG feature extractor (System Generator, hardware co-simulation) | 4,324 LUT | 1,540 | 125 DSP48E1 | n/r | 14.762 MHz max | n/r | No Se / +P reported | FT |
| Meddah et al. 2020 [meddah2020] | Xilinx Spartan-3E (Nexys 2 board), VHDL, ISE 14.2 | Pan-Tompkins-inspired | n/v | n/v | n/v | n/v | n/v | n/v | Overall accuracy 97.6 %, Se 97.3 % (MIT-BIH; record set not given in abstract) | ABS |
| Meddah et al. 2019 [meddah2019] | Nexys-4 kit (Xilinx System Generator) | Pan-Tompkins with a centred-derivative / intermediate-value peak locator | n/v | n/v | n/v | n/v | n/v | n/v | Validated on all 48 MIT-BIH records; no figures in abstract | ABS |
| Huang, Wang & Chen 2012 [huang2012] | ASIC, 0.18 µm CMOS | "modified state-of-the-art" QRS algorithm (not named in abstract) | 0.68 mm² core | - | - | - | n/v | **2.21 µW** | Se 95.65 / +P 99.36, MIT/BIH; ±6 ms timing accuracy (title) | ABS |
| Ieong et al. 2012 [ieong2012] | ASIC, 0.35 µm CMOS | Scale-3 quadratic-spline wavelet (symmetric FIR) + modulus-maxima recognition, 2 FSMs | n/v | - | - | - | "300-Hz processor" | **0.83 µW** | Se 99.31 / +P 99.70, all MIT-BIH recordings | ABS |

Notes on (b):

- Madiraju 2018: the utilisation table's "available" column (46,560 LUT, 93,120 registers, 288 DSP48E1) is smaller than an XC6VLX240T. The paper is therefore internally inconsistent about which Virtex-6 part was used. Its numbers also include a feature extractor and not just the detector, and it is not peer reviewed. Use it with care, or leave it out.
- Kovačević et al. 2014 [kovacevic2014] (abstract only) optimised FPGA Pan-Tompkins and Balda detectors for power. They report relative savings only: about 71 % lower power and about 91 % lower chip occupancy. There are no absolute numbers to tabulate.
- Only the two ASICs report power. None of the FPGA papers read report power, so our 0.355 W board-level estimate has no direct FPGA counterpart.
- Our detector (571 + 2,533 = 3,104 LUT, 3 DSP, 0 BRAM) is much smaller in DSP use than Chen 2020 (87 DSP) and Madiraju 2018 (125 DSP). It is larger in logic than Stojanović 2011 (651 LC), but that design is a wavelet-only detector with about 95 % accuracy on non-standard data.

---

## (c) Pacemaker modelling and verification: related work

**Jiang, Pajic, Moarref, Alur & Mangharam, TACAS 2012 [jiang2012tacas]** (full text read)

- **What they built:** timed-automata models in UPPAAL of a dual-chamber (DDD) pacemaker. The models follow Boston Scientific's specification and technical guide.
- **The heart model:** the pacemaker is closed in a loop with a non-deterministic heart model that can produce any atrial/ventricular event timing, so the closed-loop state space covers every heart rate.
- **Basic safety properties verified:**
  - Lower-rate limit: the interval between ventricular events never exceeds T_LRI. This is written as an `A[]` invariant over a monitor automaton.
  - Upper-rate limit: a ventricular pace never comes sooner than T_URI after a ventricular event.
  - The basic DDD model satisfies both.
- **Pacemaker-mediated tachycardia (PMT):** they then treat PMT as an "unsafe transition", where a healthy heart is driven into tachycardia by the device. They model two clinical cases and check that the corresponding correction algorithms work. One is the atrial-tachycardia mode switch for supraventricular tachycardia. The other is Boston Scientific's endless-loop-tachycardia detection.
- **Limitation:** they verified one instance of the model with nominal parameters.
- **Relevance:** this is the closest precedent for our closed-loop DDD controller, the PMT interrupt, and the CTL properties.

**Jiang, Pajic & Mangharam, Proc. IEEE 2012 [jiang2012procieee]** (abstract only)

- **Motivation:** they cite device recalls in which firmware was a major cause.
- **What they built:** a real-time Virtual Heart Model (VHM) that reproduces normal and arrhythmic conduction, plus a method to turn heart and device timing into timed automata for formal checks and testing.
- **What they tested:** they validate the VHM on common arrhythmias. In a closed-loop, model-based test environment they test basic pacemaker functions: rate maintenance, AV synchrony, and PMT.
- **Emphasis:** testing and verification with the patient in the loop. This is the closed-loop idea our heart model follows.

**Boston Scientific, PACEMAKER System Specification, 2007 [bsc2007]** (full document read, 35 pages)

- **What it is:** the requirements document for a previous-generation pacemaker, released for academic and formal-methods use. It became the reference problem for the McMaster SQRL / Software Certification Consortium pacemaker challenge. It is a specification, not a verification paper.
- **Mode code:** Table 2 defines the bradycardia mode letters. Position I is the chamber paced, II the chamber sensed, III the response to sensing (O/T/I/D, where it calls D "tracked"), and the optional IV is rate modulation.
- **Timing parameters:** LRL, URL, fixed and dynamic AV delay, VRP, ARP, PVARP and PVARP extension, hysteresis, rate smoothing, and ATR mode switching.
- **Programmable ranges and nominal values (Table 7), useful for our APB range checks:**

  | Parameter | Range | Nominal | Tolerance |
  |---|---|---|---|
  | LRL | 30-175 ppm (5 ppm steps from 30-50, 1 ppm from 50-90, 5 ppm from 90-175) | 60 ppm | ±8 ms |
  | URL | 50-175 ppm, 5 ppm steps | 120 ppm | |
  | Fixed AV delay | 70-300 ms, 10 ms steps | 150 ms | |
  | VRP | 150-500 ms | 320 ms | |
  | ARP | 150-500 ms | 250 ms | |
  | PVARP | 150-500 ms | 250 ms | |
  | PVARP extension | off or 50-400 ms | | |

  Mode list includes DDD, and DDD is the nominal mode.

**Macedo, Larsen & Fitzgerald, FM 2008 [macedo2008]** (abstract only)

- **What they built:** a formal model of the same 2007 pacemaker challenge in VDM. They build it incrementally, starting from abstract system-level functional and timing specifications and adding architecture, concurrency and timing detail step by step.
- **How they validated it:** mainly by scenario-based tests and analysis of timed traces, not by exhaustive model checking.
- **Why it matters for us:** it is the stepwise-refinement counterpart to the UPPAAL and NuSMV style of checking that we use.

**DDD meaning** [bernstein2002, bsc2007]: D-D-D means both chambers are paced, both are sensed, and the response to sensing is dual: a sense inhibits a pending pace in that chamber, and an atrial sense tracks to a ventricular pace after the programmed AV delay unless a ventricular sense comes first (spec §3.5.3-3.5.4). The 2002 NBG revision kept these three positions. It redefined position IV (rate modulation only) and position V (multisite pacing).

---

## (d) Pan-Tompkins in our own words [pan1985]

Pan and Tompkins built a real-time QRS detector that runs entirely in integer arithmetic on an 8-bit microprocessor (Z80/NSC800 assembly). The ECG is sampled at 200 Hz.

The processing chain is:

1. **Band-pass filter.** An integer low-pass and an integer high-pass filter in cascade, built from pole-zero cancellation so that the coefficients are integers.
   - The low-pass is H(z) = (1 − z^-6)^2 / (1 − z^-1)^2: cutoff about 11 Hz, gain 36, delay 6 samples.
   - The high-pass is described as an all-pass delay minus a first-order (32-sample moving-average) low-pass: cutoff about 5 Hz, gain 32, delay 16 samples.
   - Together they give a 3 dB pass band of roughly 5 to 12 Hz, against a design goal of 5 to 15 Hz.
2. **Derivative.** A five-point derivative, (1/8T)(−z^-2 − 2z^-1 + 2z + z^2), linear up to about 30 Hz, delay 2 samples.
3. **Squaring.** Point-by-point squaring, which makes every sample positive and emphasises steep slopes.
4. **Moving-window integration.** The window is 30 samples (150 ms at 200 Hz), chosen to be about the width of the widest QRS. The rising edge of the integrator output marks the QRS.
5. **Adaptive decision.**
   - **Two threshold pairs.** One pair runs on the integrator output and one on the band-passed signal. In each pair the high threshold is NPK + 0.25(SPK − NPK) and the low threshold is half of that.
   - **Peak estimates.** Each peak updates a running signal-peak estimate (SPK) or noise-peak estimate (NPK) with weights 1/8 new, 7/8 old.
   - **Two RR averages.** One is the mean of the last 8 RR intervals. The other is the mean of the last 8 RR intervals that fell within 92 to 116 % of the current average.
   - **Search-back.** If no QRS is found within 166 % of the RR average, the largest peak between the two thresholds is accepted. SPK is then updated with weight 1/4.
   - **Irregular rhythm.** For irregular rhythms both thresholds are halved.
   - **Refractory period.** After a beat there is a 200 ms refractory period.
   - **T-wave check.** A candidate between 200 and 360 ms after the last beat is called a T wave if its maximum slope is less than half that of the previous QRS.
   - **Learning phases.** About 2 s of learning sets the initial thresholds, and two beats set the initial RR averages.

The filter delays stated in the paper add up to 6 + 16 + 2 = 24 samples, which is 120 ms at 200 Hz, before the 150 ms integration window.

**Headline claim.** On the 24-hour MIT/BIH arrhythmia database the abstract says the algorithm "correctly detects 99.3 percent of the QRS complexes". The results table shows that this is 100 % minus a 0.675 % failed-detection rate: 507 FP + 277 FN over 116,137 beats. It is not a sensitivity. From the same table, Se = 99.76 % and +P = 99.56 %.

**Caution for the report.** The paper describes the high-pass as "delay of 16 minus a 32-sample moving average". Writing that description out gives H(z) = (−1 + 32z^-16 − 32z^-17 + z^-32) / (32(1 − z^-1)), or the same without the 1/32 if the paper's gain of 32 is kept. The printed Eqs. (4) and (6) show a (1 + z^-1) denominator, which does not agree with the paper's own description. State which form our HLS code uses rather than copying Eq. (4).

---

## (e) Our numbers for the comparison rows (as measured, supplied by the project)

- **Detector accuracy, hardware (bit-exact integer):** Se 99.55 %, +P 99.92 %. TP 11,820, FP 9, FN 53 on whole records 100, 101, 106, 208 and 234, with ±150 ms tolerance.
  - On Pan-Tompkins' own measure, failed detection is 0.52 %, i.e. "99.48 %".
- **Floating-point reference:** Se 99.13 %, +P 99.86 % on the same records.
- **Resources on xc7z010 (Zybo Z7-10: 17,600 LUT, 35,200 FF):**
  - HLS filter chain: 571 LUT (3.2 %), 563 FF (1.6 %), 3 DSP, 0 BRAM, post-route, 130 MHz achievable.
  - RTL decision stage: 2,533 LUT (14.4 %), 1,723 FF (4.9 %).
  - Detector total: 3,104 LUT (17.6 %), 2,286 FF (6.5 %).
- **Power:** 0.355 W for the whole-board SoC (Vivado vectorless estimate; not a detector-only or measured figure).
- **Detection latency:** about 210 ms. For context, Pan-Tompkins' filter delay alone is 120 ms at 200 Hz, before the integration window and the decision.

---

## What could not be verified

- **Hamilton & Tompkins 1986:** full text not available. The beat count and FP/FN are from Di Marco 2011 Table 4, and the tolerance is unknown.
- **Martínez 2004 and Li 1995:** only the abstracts were read. The exact MIT-BIH counts and record exclusions come from Di Marco 2011 and Elgendi 2013.
- **Huang 2012 and Ieong 2012 ASICs:** abstract only. The Huang full text is behind a bot check that I did not try to pass.
- **Meddah 2019/2020 and Kovačević 2014:** no resource numbers in their abstracts, and the full texts are paywalled.
- **Elgendi 2013 and Cvikl 2007:** no matching tolerance is stated in either paper.
- **Arzeno 2008:** the table values came through a page summariser. They were checked for internal consistency but not seen directly.
- **ANSI/AAMI EC57:** the standard itself was not read. The 150 ms rule is cited through Di Marco 2011.
