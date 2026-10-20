import wave
import math
import struct
import random
import os

OUT_DIR = r"C:\Users\nguye\.gemini\antigravity-ide\scratch\fptu-godot4-simulator\assets\audio"
os.makedirs(OUT_DIR, exist_ok=True)
SAMPLE_RATE = 44100

def write_wav(filename, samples, sample_rate=SAMPLE_RATE):
    filepath = os.path.join(OUT_DIR, filename)
    with wave.open(filepath, "w") as wav_file:
        wav_file.setnchannels(1) # Mono
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        packed_data = bytearray()
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            val = int(clamped * 32760.0)
            packed_data.extend(struct.pack("<h", val))
        wav_file.writeframes(packed_data)
    print(f"Generated {filename} ({len(samples)} samples)")

# 1. 4-Stroke Motorcycle Engine Loop (Honda Wave / Exciter idle rumble)
def make_engine_loop():
    duration = 0.5
    num_samples = int(duration * SAMPLE_RATE)
    periods = 14
    freq = periods / duration # 28 Hz
    samples = []
    
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        phase = 2.0 * math.pi * freq * t
        
        # 4-stroke firing pulse
        pulse = math.sin(phase) + 0.65 * math.sin(2.0 * phase) + 0.45 * math.sin(3.0 * phase) + 0.3 * math.sin(4.0 * phase)
        metallic = 0.15 * math.sin(16.0 * phase) * math.exp(-3.0 * (math.fmod(phase, math.pi * 2) / (math.pi * 2)))
        rumble = 0.25 * math.sin(2.0 * math.pi * 65.0 * t)
        noise = (random.random() * 2.0 - 1.0) * 0.08
        
        s = 0.65 * pulse + metallic + rumble + noise
        samples.append(s)
        
    write_wav("bike_engine_loop.wav", samples)

# 2. Dual-Tone Motorcycle Horn (Bim bim!)
def make_horn():
    duration = 0.38
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    f1 = 425.0
    f2 = 515.0
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = 1.0
        if t < 0.02:
            env = t / 0.02
        elif t > duration - 0.04:
            env = (duration - t) / 0.04
            
        s1 = math.sin(2.0 * math.pi * f1 * t) + 0.35 * math.sin(2.0 * math.pi * f1 * 2 * t)
        s2 = math.sin(2.0 * math.pi * f2 * t) + 0.35 * math.sin(2.0 * math.pi * f2 * 2 * t)
        s = (s1 + s2) * 0.45 * env
        samples.append(s)
    write_wav("bike_horn.wav", samples)

# 3. High Speed Wind Rush Loop
def make_wind_loop():
    duration = 1.0
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    last_val = 0.0
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        white = random.random() * 2.0 - 1.0
        last_val = last_val * 0.94 + white * 0.06
        gust = 0.8 + 0.2 * math.sin(2.0 * math.pi * 3.5 * t)
        samples.append(last_val * 1.8 * gust)
    write_wav("wind_rush_loop.wav", samples)

# 4. Tire Skid / Drift Screech
def make_tire_skid():
    duration = 0.6
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (t / duration)) ** 0.5
        scrub = math.sin(2.0 * math.pi * (780.0 + random.random() * 120.0) * t)
        noise = (random.random() * 2.0 - 1.0) * 0.6
        s = (scrub * 0.5 + noise * 0.5) * env * 0.55
        samples.append(s)
    write_wav("tire_skid.wav", samples)

# 5. Crash / Bump Thud
def make_crash_bump():
    duration = 0.45
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-12.0 * t)
        thud = math.sin(2.0 * math.pi * (65.0 - 30.0 * t) * t)
        ping = math.sin(2.0 * math.pi * 310.0 * t) * math.exp(-25.0 * t)
        noise = (random.random() * 2.0 - 1.0) * math.exp(-18.0 * t) * 0.6
        s = (thud * 0.7 + ping * 0.3 + noise) * env * 0.85
        samples.append(s)
    write_wav("crash_bump.wav", samples)

# 6. Checkpoint Chime (Zone announcement bell)
def make_checkpoint_chime():
    duration = 0.75
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    tones = [(0.0, 1046.5), (0.12, 1318.5), (0.24, 1567.9)]
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        s = 0.0
        for start_t, freq in tones:
            if t >= start_t:
                dt = t - start_t
                env = math.exp(-8.0 * dt)
                s += math.sin(2.0 * math.pi * freq * dt) * env * 0.28
        samples.append(s)
    write_wav("checkpoint_bell.wav", samples)

# 7. Absent Alarm (Low ominous bell / warning buzzer)
def make_absent_alarm():
    duration = 1.8
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-2.2 * t)
        b1 = math.sin(2.0 * math.pi * 130.8 * t)
        b2 = math.sin(2.0 * math.pi * 138.6 * t) * 0.85
        b3 = math.sin(2.0 * math.pi * 261.6 * t) * 0.4
        s = (b1 + b2 + b3) * 0.45 * env
        samples.append(s)
    write_wav("absent_gameover.wav", samples)

# 8. Victory Fanfare (Crossing FPTU finish line)
def make_victory_fanfare():
    duration = 2.4
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    notes = [
        (0.00, 0.18, 392.0),
        (0.20, 0.18, 523.2),
        (0.40, 0.18, 659.3),
        (0.60, 0.35, 784.0),
        (1.00, 1.20, 1046.5)
    ]
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        s = 0.0
        for start_t, dur, freq in notes:
            if start_t <= t < start_t + dur + 0.4:
                dt = t - start_t
                env = 1.0
                if dt < 0.02:
                    env = dt / 0.02
                else:
                    env = math.exp(-3.5 * (dt - 0.02))
                harm = math.sin(2.0 * math.pi * freq * dt) + 0.4 * math.sin(2.0 * math.pi * freq * 2 * dt)
                s += harm * env * 0.28
        samples.append(s)
    write_wav("victory_fanfare.wav", samples)

# 9. Slipstream Charge & Boost Sound
def make_slipstream_boost():
    duration = 0.8
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        f = 250.0 + 700.0 * (t / duration) ** 2
        env = math.sin(math.pi * (t / duration))
        s = math.sin(2.0 * math.pi * f * t) * env * 0.4
        samples.append(s)
    write_wav("slipstream_boost.wav", samples)

if __name__ == "__main__":
    make_engine_loop()
    make_horn()
    make_wind_loop()
    make_tire_skid()
    make_crash_bump()
    make_checkpoint_chime()
    make_absent_alarm()
    make_victory_fanfare()
    make_slipstream_boost()
    print("ALL AUDIO ASSETS GENERATED SUCCESSFULLY!")
