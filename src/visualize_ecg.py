"""
visualize_ecg.py  --  P17 QRS Detector and DDD Pacemaker Controller (Phase 1)

Loads a MIT-BIH ECG record via ecg_loader, plots the first N seconds with the
reference heartbeat annotations marked, and writes:

    results/stage1_ecg_reference.png     the annotated ECG plot
    results/stage1_metadata.json         machine-readable summary
    results/stage1_annotations.csv       table of annotations in the window

The reference annotations drawn here are GROUND TRUTH from the MIT-BIH
database -- they are NOT produced by any detector of ours.  No filtering or
QRS detection is performed in this phase.

Usage (from the project root, with the venv active):
    python src/visualize_ecg.py                # record 100, first 10 s
    python src/visualize_ecg.py --record 100 --seconds 10
"""

from __future__ import annotations

import argparse
import json
import os

import matplotlib
matplotlib.use("Agg")  # headless: render straight to a file, no GUI needed
import matplotlib.pyplot as plt
import pandas as pd

from ecg_loader import (
    BEAT_SYMBOLS,
    EXPECTED_FS_HZ,
    PREFERRED_CHANNEL,
    extract_segment,
    load_ecg_record,
)

# Project paths are resolved relative to this file, so the script works no
# matter which directory it is launched from.
SRC_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SRC_DIR)
DATA_DIR = os.path.join(PROJECT_ROOT, "data")
RESULTS_DIR = os.path.join(PROJECT_ROOT, "results")


def plot_segment(seg, out_png: str) -> None:
    """Draw the ECG window with reference beat/non-beat annotations marked."""
    beat_mask = seg.beat_mask
    nonbeat_mask = ~beat_mask

    fig, ax = plt.subplots(figsize=(13, 5))

    # 1) The ECG waveform itself.
    ax.plot(seg.time_s, seg.signal, color="#1f4e79", linewidth=0.9,
            label=f"ECG ({seg.channel_name})")

    # 2) Reference HEARTBEAT annotations (ground truth), drawn on the sample.
    if beat_mask.any():
        ax.scatter(seg.ann_time_s[beat_mask], seg.ann_amplitude[beat_mask],
                   marker="v", s=70, color="#c00000", zorder=5,
                   label="Reference beat (ground truth)")
        for t, a, s in zip(seg.ann_time_s[beat_mask],
                           seg.ann_amplitude[beat_mask],
                           [sym for sym, keep in zip(seg.ann_symbol, beat_mask) if keep]):
            # Preserve and show the original MIT-BIH symbol above each beat.
            ax.annotate(s, (t, a), textcoords="offset points", xytext=(0, 10),
                        ha="center", fontsize=9, color="#c00000", fontweight="bold")

    # 3) Any NON-beat annotations (rhythm/quality markers), shown distinctly.
    if nonbeat_mask.any():
        ax.scatter(seg.ann_time_s[nonbeat_mask], seg.ann_amplitude[nonbeat_mask],
                   marker="x", s=55, color="#7f7f7f", zorder=4,
                   label="Non-beat annotation")

    ax.set_title(
        f"MIT-BIH Record {seg.record_name} - lead {seg.channel_name} - "
        f"first {seg.duration_s:.1f} s with reference annotations",
        fontsize=12)
    ax.set_xlabel("Time (s)")
    ax.set_ylabel(f"ECG amplitude ({seg.units})")
    ax.set_xlim(seg.time_s[0], seg.time_s[-1])
    ax.grid(True, which="major", linestyle="-", alpha=0.35)
    ax.grid(True, which="minor", linestyle=":", alpha=0.20)
    ax.minorticks_on()
    ax.legend(loc="upper right", framealpha=0.9)

    fig.tight_layout()
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    fig.savefig(out_png, dpi=150)
    plt.close(fig)


def write_metadata(rec, seg, out_json: str) -> dict:
    """Write the Phase-1 metadata summary and return it as a dict."""
    counts = seg.symbol_counts()
    beat_symbols_present = sorted(s for s in counts if s in BEAT_SYMBOLS)
    nonbeat_symbols_present = sorted(s for s in counts if s not in BEAT_SYMBOLS)

    meta = {
        "record_number": rec.record_name,
        "sampling_frequency_hz": rec.fs,
        "expected_sampling_frequency_hz": EXPECTED_FS_HZ,
        "sampling_frequency_matches_expected": (rec.fs == EXPECTED_FS_HZ),
        "preferred_channel": PREFERRED_CHANNEL,
        "selected_channel": rec.channel_name,
        "selected_channel_index": rec.channel_index,
        "channel_fallback_used": (rec.channel_name != PREFERRED_CHANNEL),
        "all_channels": rec.all_channel_names,
        "recording_units": rec.units,
        "total_sample_count_full_record": rec.n_samples_total,
        "total_duration_full_record_s": round(rec.duration_s, 4),
        "displayed_start_s": round(seg.start_sample / rec.fs, 4),
        "displayed_duration_s": round(seg.duration_s, 4),
        "displayed_sample_count": seg.n_samples,
        "annotations_in_displayed_segment": len(seg.ann_symbol),
        "reference_beats_in_displayed_segment": seg.n_beats,
        "beat_symbols_present": beat_symbols_present,
        "nonbeat_symbols_present": nonbeat_symbols_present,
        "all_symbol_counts_in_segment": counts,
        "beat_symbol_definition_used": sorted(BEAT_SYMBOLS),
        "note": ("Annotations are MIT-BIH reference (ground-truth) labels, "
                 "not detector output. Only symbols in "
                 "'beat_symbol_definition_used' are counted as heartbeats."),
    }

    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as fh:
        json.dump(meta, fh, indent=2)
    return meta


def write_annotation_table(seg, out_csv: str) -> None:
    """Save every annotation in the window as a CSV (uses pandas)."""
    df = pd.DataFrame({
        "abs_sample": seg.ann_sample_abs,
        "rel_sample": seg.ann_sample_rel,
        "time_s": seg.ann_time_s,
        "amplitude": seg.ann_amplitude,
        "symbol": seg.ann_symbol,
        "is_reference_beat": seg.beat_mask,
    })
    os.makedirs(os.path.dirname(out_csv), exist_ok=True)
    df.to_csv(out_csv, index=False)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Phase 1: load and visualize a MIT-BIH ECG record.")
    parser.add_argument("--record", default="100",
                        help="MIT-BIH record name (default: 100)")
    parser.add_argument("--seconds", type=float, default=10.0,
                        help="Seconds to display from the start (default: 10)")
    args = parser.parse_args()

    print(f"[1/4] Loading MIT-BIH record {args.record} ...")
    rec = load_ecg_record(args.record, data_dir=DATA_DIR)
    print(f"      fs = {rec.fs} Hz | channels = {rec.all_channel_names} | "
          f"selected = '{rec.channel_name}' | units = {rec.units} | "
          f"total samples = {rec.n_samples_total}")

    if rec.fs != EXPECTED_FS_HZ:
        print(f"      WARNING: sampling frequency {rec.fs} Hz != expected "
              f"{EXPECTED_FS_HZ} Hz")
    if rec.channel_name != PREFERRED_CHANNEL:
        print(f"      NOTE: preferred channel '{PREFERRED_CHANNEL}' not found; "
              f"fell back to '{rec.channel_name}'")

    print(f"[2/4] Extracting first {args.seconds:.1f} s ...")
    seg = extract_segment(rec, 0.0, args.seconds)
    print(f"      {seg.n_samples} samples | {len(seg.ann_symbol)} annotations | "
          f"{seg.n_beats} reference beats | symbols = {seg.symbol_counts()}")

    png = os.path.join(RESULTS_DIR, "stage1_ecg_reference.png")
    meta_json = os.path.join(RESULTS_DIR, "stage1_metadata.json")
    csv = os.path.join(RESULTS_DIR, "stage1_annotations.csv")

    print(f"[3/4] Plotting -> {png}")
    plot_segment(seg, png)

    print(f"[4/4] Writing metadata -> {meta_json} and {csv}")
    meta = write_metadata(rec, seg, meta_json)
    write_annotation_table(seg, csv)

    print("\n--- Phase 1 summary ---")
    print(json.dumps(meta, indent=2))
    print("\nDone. Open results/stage1_ecg_reference.png to inspect the plot.")


if __name__ == "__main__":
    main()
