"""Pick the most cinematic window of a song for a fixed-length fight cinematic (choreography is re-timed to it later).

usage: python -I pickwin.py <audio> <length s>
Score per window: loudness + hit activity, a strong hit 2-3.5 s in (first impact), a strong hit length-5.5 to
length-4.0 s in (19.5-21.0 s for 25 s: the last freeze impact; its ramp still needs 0.5-1.55 s of slow motion after the
hit, then the 3-4 s normal-speed tail of spec A1-D8) and steady beats. Prints the top windows and their hit times.
"""
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from beatfit import load, onset_strength, SR, HOP  # noqa: E402


def main():
    path, length = sys.argv[1], float(sys.argv[2])
    x = load(path)
    dur = len(x) / SR
    env = onset_strength(x)
    fps = SR / HOP
    n = len(env)
    rms = np.sqrt(np.convolve(x.astype(np.float64) ** 2, np.ones(HOP) / HOP, mode="same")[::HOP][:n] + 1e-12)
    loud = rms / (rms.max() + 1e-9)
    ac = np.correlate(env - env.mean(), env - env.mean(), mode="full")[n - 1:]
    lags = np.arange(len(ac)) / fps
    m = (lags > 60 / 180) & (lags < 60 / 60)
    beat = lags[m][np.argmax(ac[m])]
    w = int(length * fps)

    def peak(a, b):
        seg = env[a:b]
        return float(seg.max()) if len(seg) else 0.0

    cands = []
    for s in range(0, max(1, n - w), int(0.25 * fps)):
        e = s + w
        act = float(np.mean(env[s:e]))
        ld = float(np.mean(loud[s:e]))
        first = peak(s + int(2.0 * fps), s + int(3.5 * fps))
        last = peak(s + int(max(length - 5.5, 0.0) * fps), s + int(max(length - 4.0, 0.0) * fps))
        quiet_start = float(np.mean(loud[s:s + int(1.0 * fps)]))
        score = 2.0 * ld + 6.0 * act + 0.6 * first + 0.6 * last + 0.3 * quiet_start
        cands.append((score, s / fps, ld, act, first, last))
    cands.sort(reverse=True)
    picked = []
    for c in cands:
        if all(abs(c[1] - p[1]) > 8.0 for p in picked):
            picked.append(c)
        if len(picked) == 3:
            break
    print(f"{path.rsplit('/', 1)[-1]}: {dur:.1f} s, tempo ~{60 / beat:.0f} bpm")
    for score, st, ld, act, first, last in picked:
        a, b = int(st * fps), int(st * fps) + w
        hits = [i for i in range(a + 1, b - 1) if env[i] > 0.35 and env[i] >= env[i - 1] and env[i] >= env[i + 1]]
        kept = []
        for i in hits:
            if not kept or (i - kept[-1]) / fps > 0.25:
                kept.append(i)
        ht = " ".join(f"{(i - a) / fps:.2f}" for i in kept[:24])
        print(f"  start {int(st // 60)}:{st % 60:05.2f} ({st:.2f} s) | score {score:.2f} loud {ld:.2f} "
              f"first {first:.2f} last {last:.2f}\n    hits (s into cut): {ht}")


if __name__ == "__main__":
    main()
