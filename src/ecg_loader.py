"""
ecg_loader.py  --  P17 QRS Detector and DDD Pacemaker Controller (Phase 1)

Reusable loader for MIT-BIH Arrhythmia Database ECG records from PhysioNet,
using the WFDB Python library.

SCOPE OF THIS MODULE
--------------------
This module ONLY downloads, loads and structures the raw ECG data and its
reference (ground-truth) annotations.  It deliberately performs:
    * NO filtering          (no band-pass / high-pass / derivative)
    * NO squaring / integration
    * NO peak detection / QRS detection
    * NO pacemaker timing logic
Those belong to later phases.  The original floating-point ECG samples are
preserved unchanged.

The EcgRecord / EcgSegment objects returned here are designed so that the
Pan-Tompkins QRS detector built in Phase 2 can reuse this loader directly.

IMPORTANT ON ANNOTATIONS
------------------------
The annotations loaded here are *reference* labels supplied by expert
cardiologists in the MIT-BIH database.  They are GROUND TRUTH, not the output
of any detector we have written.  They exist so that, later, we can score our
own QRS detector against them (sensitivity / positive predictivity).
"""

from __future__ import annotations

import os
import time
from dataclasses import dataclass, field

import numpy as np
import requests
import wfdb

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# PhysioNet database slug for the MIT-BIH Arrhythmia Database.
MITDB_PN_DIR = "mitdb"

# File base URL for the MIT-BIH Arrhythmia Database v1.0.0.
# We use PhysioNet's AWS S3 open-data mirror: on this network the direct
# physionet.org route is ~4 KB/s and drops mid-transfer (IncompleteRead),
# whereas the S3 mirror is fast and reliable. Files are byte-identical (the
# SHA256 are verified against PhysioNet's published SHA256SUMS).
MITDB_BASE_URL = "https://physionet-open.s3.amazonaws.com/mitdb/1.0.0"

# Files that make up one record: header, signal data, reference annotations.
RECORD_EXTENSIONS = ("hea", "dat", "atr")

# Bits per sample for the WFDB signal storage formats we might encounter.
# Used to compute the exact expected .dat size from the header, so a corrupt
# or truncated cached signal file is detected and re-downloaded.
_FMT_BITS = {
    "8": 8, "80": 8, "16": 16, "61": 16, "160": 16,
    "212": 12, "310": 10, "311": 10, "24": 24, "32": 32,
}

# The ECG specification for this project fixes the replay/sampling rate.
EXPECTED_FS_HZ = 360

# Preferred ECG lead.  MIT-BIH record 100 has leads 'MLII' and 'V5'; the
# Pan-Tompkins algorithm is classically tuned on the MLII (modified lead II)
# channel, so we select it when present.
PREFERRED_CHANNEL = "MLII"

# ---------------------------------------------------------------------------
# MIT-BIH beat annotation symbols
# ---------------------------------------------------------------------------
# A subset of MIT-BIH annotation symbols mark an actual heartbeat (a QRS
# complex).  These are the labels used as ground truth when scoring a QRS
# detector (MIT-BIH / ANSI-AAMI EC57 conventions).  Every other symbol
# (e.g. '+', '~', '|', '[', ']', '!', '"', 'x') annotates a rhythm change,
# a signal-quality change or some other non-beat event and is NOT counted
# as a heartbeat.
#
# Symbol : meaning
#   N  Normal beat                          r  R-on-T premature ventricular
#   L  Left bundle branch block beat        F  Fusion of ventric. and normal
#   R  Right bundle branch block beat       e  Atrial escape beat
#   B  Bundle branch block beat (unspec.)   j  Nodal (junctional) escape beat
#   A  Atrial premature beat                n  Supraventricular escape beat
#   a  Aberrated atrial premature beat      E  Ventricular escape beat
#   J  Nodal (junctional) premature beat    /  Paced beat
#   S  Supraventricular premature beat      f  Fusion of paced and normal
#   V  Premature ventricular contraction    Q  Unclassifiable beat
#                                           ?  Beat not classified (learning)
BEAT_SYMBOLS = frozenset(
    ["N", "L", "R", "B", "A", "a", "J", "S", "V",
     "r", "F", "e", "j", "n", "E", "/", "f", "Q", "?"]
)


# ---------------------------------------------------------------------------
# Data containers
# ---------------------------------------------------------------------------

@dataclass
class EcgRecord:
    """A full MIT-BIH record: one selected ECG channel plus its annotations."""
    record_name: str
    fs: float                         # sampling frequency (Hz)
    signal: np.ndarray                # selected channel, physical units, float
    channel_name: str                 # name of the selected channel
    channel_index: int                # its column index in the raw record
    all_channel_names: list[str]      # every channel present in the record
    units: str                        # physical unit of 'signal' (e.g. 'mV')
    n_samples_total: int              # total samples in the full record
    ann_sample: np.ndarray            # annotation sample indices (full record)
    ann_symbol: list[str]             # annotation symbols, preserved verbatim

    @property
    def duration_s(self) -> float:
        return self.n_samples_total / self.fs


@dataclass
class EcgSegment:
    """A time window extracted from an EcgRecord, with aligned annotations."""
    record_name: str
    fs: float
    channel_name: str
    units: str
    start_sample: int
    end_sample: int                   # exclusive
    time_s: np.ndarray                # absolute time of each sample (s)
    signal: np.ndarray                # ECG amplitude for this window
    ann_sample_abs: np.ndarray        # absolute sample index of each annotation
    ann_sample_rel: np.ndarray        # index relative to start_sample
    ann_time_s: np.ndarray            # absolute time of each annotation (s)
    ann_amplitude: np.ndarray         # ECG value at each annotation sample
    ann_symbol: list[str]             # symbols for annotations in this window

    @property
    def n_samples(self) -> int:
        return int(self.signal.shape[0])

    @property
    def duration_s(self) -> float:
        return self.n_samples / self.fs

    @property
    def beat_mask(self) -> np.ndarray:
        """Boolean mask: True where the annotation symbol is a heartbeat."""
        return np.array([s in BEAT_SYMBOLS for s in self.ann_symbol], dtype=bool)

    @property
    def n_beats(self) -> int:
        return int(self.beat_mask.sum())

    def symbol_counts(self) -> dict[str, int]:
        """Count of each annotation symbol present in this window."""
        counts: dict[str, int] = {}
        for s in self.ann_symbol:
            counts[s] = counts.get(s, 0) + 1
        return counts


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

def _remote_size(url: str, timeout: float = 30.0) -> int | None:
    """Return the file's size in bytes from the server, or None if unknown.

    Tries a HEAD request first, then a 1-byte Range probe (whose Content-Range
    header reports the full size). Knowing the exact total up front lets us
    accept a download only when it matches *exactly*.
    """
    try:
        resp = requests.head(url, timeout=timeout, allow_redirects=True)
        if resp.status_code == 200 and resp.headers.get("Content-Length"):
            return int(resp.headers["Content-Length"])
    except Exception:
        pass
    try:
        with requests.get(url, headers={"Range": "bytes=0-0"}, stream=True,
                          timeout=timeout) as resp:
            cr = resp.headers.get("Content-Range")
            if cr and "/" in cr:
                return int(cr.rsplit("/", 1)[-1])
    except Exception:
        pass
    return None


def _download_file(url: str, dest: str, max_attempts: int = 80,
                   timeout: float = 30.0, chunk_size: int = 1 << 16) -> None:
    """Download one file robustly, with HTTP Range *resume* and EXACT-size check.

    Streams to a <dest>.part temp file. If the connection drops mid-transfer
    (the IncompleteRead / ChunkedEncodingError seen on flaky links), the next
    attempt resumes from the bytes already on disk via a Range request instead
    of starting over, so progress accumulates across drops.

    The download is accepted only when the temp file's size matches the server's
    reported size EXACTLY. A partial that is too large (e.g. corrupted by a
    previous concurrent writer) is discarded and re-fetched from scratch. The
    final file appears only on an exact match, so a bad transfer never becomes
    a corrupt cache entry.
    """
    tmp = dest + ".part"
    total = _remote_size(url, timeout)  # exact expected size, if the server says
    last_exc: Exception | None = None

    # Drop any existing partial that cannot be a valid prefix of the real file.
    if (total is not None and os.path.exists(tmp)
            and os.path.getsize(tmp) > total):
        os.remove(tmp)

    for attempt in range(1, max_attempts + 1):
        have = os.path.getsize(tmp) if os.path.exists(tmp) else 0
        if total is not None and have == total:
            break  # already complete -> finalize after the loop
        if total is not None and have > total:
            os.remove(tmp)  # corrupt/oversized -> restart cleanly
            have = 0

        headers = {"Range": f"bytes={have}-"} if have else {}
        try:
            with requests.get(url, headers=headers, stream=True,
                              timeout=timeout) as resp:
                if resp.status_code == 200 and have:
                    have = 0  # server ignored Range -> restart file
                elif resp.status_code not in (200, 206):
                    resp.raise_for_status()

                content_range = resp.headers.get("Content-Range")
                if total is None and content_range and "/" in content_range:
                    total = int(content_range.rsplit("/", 1)[-1])
                elif total is None and resp.headers.get("Content-Length"):
                    total = have + int(resp.headers["Content-Length"])

                with open(tmp, "ab" if have else "wb") as fh:
                    for block in resp.iter_content(chunk_size=chunk_size):
                        if block:
                            fh.write(block)

            have = os.path.getsize(tmp)
            if total is None or have == total:
                break  # finished (or size unknown and stream ended cleanly)
            print(f"      {os.path.basename(dest)}: {have}/{total} bytes - "
                  f"resuming (attempt {attempt}/{max_attempts}) ...", flush=True)
        except Exception as exc:
            last_exc = exc
            saved = os.path.getsize(tmp) if os.path.exists(tmp) else 0
            tot = total if total is not None else "?"
            print(f"      {os.path.basename(dest)}: attempt {attempt}/"
                  f"{max_attempts} dropped at {saved}/{tot} bytes "
                  f"({type(exc).__name__}); resuming ...", flush=True)
            time.sleep(min(attempt, 5))

    final = os.path.getsize(tmp) if os.path.exists(tmp) else 0
    if os.path.exists(tmp) and (total is None or final == total):
        os.replace(tmp, dest)   # atomic: only an exact-size file lands at dest
        return
    raise RuntimeError(
        f"Failed to download {url} after {max_attempts} attempts "
        f"(have {final} of {total} bytes). Last error: {last_exc!r}")


def _expected_dat_bytes(prefix: str) -> int | None:
    """Exact expected size (bytes) of <prefix>.dat from its header, or None.

    Derived from sig_len x n_sig x bits-per-sample. Returns None when the format
    is mixed or unknown, in which case we skip the size check rather than guess.
    """
    try:
        hdr = wfdb.rdheader(prefix)
    except Exception:
        return None
    formats = {str(f) for f in hdr.fmt}
    if len(formats) != 1:
        return None  # mixed per-signal formats -> cannot size-check simply
    bits = _FMT_BITS.get(next(iter(formats)))
    if bits is None:
        return None
    total_bits = int(hdr.sig_len) * int(hdr.n_sig) * bits
    return (total_bits + 7) // 8


def ensure_record_local(record_name: str, data_dir: str) -> str:
    """Make sure a VALID <record>.hea/.dat/.atr exist locally; download if not.

    Missing files are fetched. The signal file is then integrity-checked: its
    size must match what the header implies for the record's sample count and
    format. A cached .dat of the wrong size (e.g. corrupted by an interrupted
    or concurrent download) is deleted and re-downloaded, so the cache is
    self-healing. Reruns with a valid cache work offline. Raises a clear
    RuntimeError on failure.
    """
    os.makedirs(data_dir, exist_ok=True)
    prefix = os.path.join(data_dir, record_name)

    missing = [
        ext for ext in RECORD_EXTENSIONS
        if not (os.path.exists(f"{prefix}.{ext}")
                and os.path.getsize(f"{prefix}.{ext}") > 0)
    ]
    for ext in missing:
        url = f"{MITDB_BASE_URL}/{record_name}.{ext}"
        dest = f"{prefix}.{ext}"
        print(f"      downloading {record_name}.{ext} from PhysioNet ...", flush=True)
        try:
            _download_file(url, dest)
        except Exception as exc:
            raise RuntimeError(
                f"Could not download MIT-BIH record '{record_name}' "
                f"({ext} file) into '{data_dir}'. Check your internet "
                f"connection / PhysioNet access. Underlying error: {exc!r}"
            ) from exc

    # Integrity check: the .dat size must equal what the header implies.
    dat = f"{prefix}.dat"
    expected = _expected_dat_bytes(prefix)
    if expected is not None and os.path.exists(dat) \
            and os.path.getsize(dat) != expected:
        actual = os.path.getsize(dat)
        print(f"      {record_name}.dat is {actual} bytes but the header implies "
              f"{expected}; the cached file is invalid, re-downloading ...",
              flush=True)
        os.remove(dat)
        _download_file(f"{MITDB_BASE_URL}/{record_name}.dat", dat)
        if os.path.getsize(dat) != expected:
            raise RuntimeError(
                f"{record_name}.dat is {os.path.getsize(dat)} bytes after "
                f"re-download, expected {expected}. The file may be corrupt "
                f"or the connection keeps truncating it.")

    return prefix


def load_ecg_record(
    record_name: str = "100",
    data_dir: str = "data",
    preferred_channel: str = PREFERRED_CHANNEL,
) -> EcgRecord:
    """Load a full MIT-BIH record and its reference annotations.

    Reads the *actual* sampling frequency and channel list from the record
    (nothing is hard-coded or fabricated).  Selects `preferred_channel` if it
    exists; otherwise falls back to the first channel and the caller can see
    the mismatch via `EcgRecord.channel_name`.
    """
    prefix = ensure_record_local(record_name, data_dir)

    # physical=True -> p_signal holds calibrated floating-point mV values.
    record = wfdb.rdrecord(prefix)
    annotation = wfdb.rdann(prefix, "atr")

    channel_names = list(record.sig_name)
    if preferred_channel in channel_names:
        channel_index = channel_names.index(preferred_channel)
    else:
        channel_index = 0  # documented fallback to the first available channel

    signal = np.asarray(record.p_signal[:, channel_index], dtype=float)
    units = record.units[channel_index]

    return EcgRecord(
        record_name=record_name,
        fs=float(record.fs),
        signal=signal,
        channel_name=channel_names[channel_index],
        channel_index=channel_index,
        all_channel_names=channel_names,
        units=units,
        n_samples_total=int(record.sig_len),
        ann_sample=np.asarray(annotation.sample, dtype=np.int64),
        ann_symbol=list(annotation.symbol),
    )


def extract_segment(
    record: EcgRecord,
    start_s: float = 0.0,
    duration_s: float = 10.0,
) -> EcgSegment:
    """Extract a [start_s, start_s + duration_s) window with aligned annotations.

    The ECG samples are copied verbatim (no processing).  Annotations whose
    sample index falls inside the window are kept, with their original symbols
    preserved and their amplitude read from the ECG at that exact sample -- so
    a marker drawn at (ann_time, ann_amplitude) sits on the real sample.
    """
    fs = record.fs
    start_sample = int(round(start_s * fs))
    end_sample = int(round((start_s + duration_s) * fs))
    # Clamp to the record so we never index out of range or invent samples.
    start_sample = max(0, min(start_sample, record.n_samples_total))
    end_sample = max(start_sample, min(end_sample, record.n_samples_total))

    seg_signal = record.signal[start_sample:end_sample]
    sample_index = np.arange(start_sample, end_sample, dtype=np.int64)
    time_s = sample_index / fs

    in_window = (record.ann_sample >= start_sample) & (record.ann_sample < end_sample)
    ann_abs = record.ann_sample[in_window]
    ann_sym = [sym for sym, keep in zip(record.ann_symbol, in_window) if keep]
    ann_rel = ann_abs - start_sample
    ann_amp = record.signal[ann_abs] if ann_abs.size else np.array([], dtype=float)
    ann_time = ann_abs / fs

    return EcgSegment(
        record_name=record.record_name,
        fs=fs,
        channel_name=record.channel_name,
        units=record.units,
        start_sample=start_sample,
        end_sample=end_sample,
        time_s=time_s,
        signal=seg_signal,
        ann_sample_abs=ann_abs,
        ann_sample_rel=ann_rel,
        ann_time_s=ann_time,
        ann_amplitude=ann_amp,
        ann_symbol=ann_sym,
    )


# ---------------------------------------------------------------------------
# Manual smoke test:  python src/ecg_loader.py
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    rec = load_ecg_record("100", data_dir="data")
    print(f"Record {rec.record_name}: fs={rec.fs} Hz, channels={rec.all_channel_names}")
    print(f"Selected channel '{rec.channel_name}' (index {rec.channel_index}), "
          f"units={rec.units}, total samples={rec.n_samples_total} "
          f"({rec.duration_s:.1f} s)")
    seg = extract_segment(rec, 0.0, 10.0)
    print(f"First {seg.duration_s:.1f} s: {seg.n_samples} samples, "
          f"{len(seg.ann_symbol)} annotations, {seg.n_beats} reference beats")
    print(f"Symbol counts in window: {seg.symbol_counts()}")
