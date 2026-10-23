"""Find where to cut a song so its strong hits line up with a cinematic's hit times.

usage: python -I beatfit.py <audio file> <length s> <hit1,hit2,...>
Prints the best start offsets (seconds into the file) and how well each hit lines up.
"""
import subprocess
import sys

import numpy as np

SR = 22050
HOP = 256          # ~11.6 ms
WIN = 1024
TOL = 0.07         # seconds either side of a hit


def load(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def onset_strength(x):
    n = 1 + (len(x) - WIN) // HOP
    frames = np.lib.stride_tricks.as_strided(x, shape=(n, WIN), strides=(x.strides[0] * HOP, x.strides[0]))
    spec = np.abs(np.fft.rfft(frames * np.hanning(WIN), axis=1))
    logspec = np.log1p(spec * 10.0)
    flux = np.maximum(0.0, np.diff(logspec, axis=0)).sum(axis=1)
    flux = np.concatenate([[0.0], flux])
    flux -= np.convolve(flux, np.ones(43) / 43, mode="same")   # remove the slow trend (~0.5 s)
    flux = np.maximum(flux, 0.0)
    return flux / (flux.max() + 1e-9)


def main():
    path, length, hits = sys.argv[1], float(sys.argv[2]), [float(h) for h in sys.argv[3].split(",")]
    x = load(path)
    dur = len(x) / SR
    env = onset_strength(x)
    fps = SR / HOP
    tol = int(TOL * fps)

    def score(off):
        vals = []
        for h in hits:
            c = int((off + h) * fps)
            seg = env[max(0, c - tol): c + tol + 1]
            vals.append(seg.max() if len(seg) else 0.0)
        return float(np.mean(vals)), vals

    last = dur - length
    print(f"file {dur:.2f} s, cinematic {length:.2f} s, {len(hits)} hits")
    if last < 0:
        print("file is SHORTER than the cinematic: the end will be silent")
        last = 0.0
    offs = np.arange(0.0, last + 1e-6, 0.01)
    scored = sorted(((score(o)[0], o) for o in offs), reverse=True)
    picked = []
    for s, o in scored:
        if all(abs(o - p) > 0.5 for _, p in picked):
            picked.append((s, o))
        if len(picked) == 5:
            break
    base = np.mean(env)
    print(f"average onset strength (chance level): {base:.2f}")
    for s, o in picked:
        _, vals = score(o)
        good = sum(v > 0.35 for v in vals)
        print(f"start {o:7.2f} s -> end {o + length:7.2f} s | match {s:.2f} | strong hits {good}/{len(hits)} | "
              + " ".join(f"{v:.1f}" for v in vals))


if __name__ == "__main__":
    main()
