"""Original Scrapbound score: 140 BPM, 48 bars, three phase-aligned loop stems.

All waveforms, percussion, notes and arrangement are generated here. No borrowed
recording, MIDI file, sample pack, model or network service is used. The offline
output is the runtime asset; this script is never run during gameplay.
"""
from pathlib import Path
import json
import math
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/v03/music'
REPORT = ROOT / 'captures/v03'
SR, BPM, BARS = 44100, 140, 48
BEAT = 60 / BPM
N = int(round(BARS * 4 * BEAT * SR))
RNG = np.random.default_rng(73019)
STEMS = {n: np.zeros((N, 2), dtype=np.float32) for n in ('clockwork', 'drive', 'overdrive')}
EVENTS = []


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def time_axis(d):
    return np.arange(round(d * SR), dtype=np.float32) / SR


def filter_noise(x, lo=100, hi=8000):
    f = np.fft.rfftfreq(len(x), 1 / SR)
    shape = (1 - np.exp(-(f / lo) ** 4)) * np.exp(-(f / hi) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * shape, len(x)).astype(np.float32)


def edge(x, attack=.003, release=.008):
    a, r = min(len(x), int(SR * attack)), min(len(x), int(SR * release))
    x[:a] *= np.linspace(0, 1, a)
    x[-r:] *= np.linspace(1, 0, r)
    return x


def tone(kind, midi, duration, velocity=1):
    t, f = time_axis(duration), hz(midi)
    if kind == 'box':
        # Rounded struck tines, slight inharmonic overtones, felt hammer noise.
        x = np.zeros_like(t)
        for ratio, amp, decay in [(1, .72, 2.0), (2.006, .22, 4.6), (2.99, .12, 6.4), (4.13, .052, 12.0)]:
            x += amp * np.sin(2*np.pi*f*ratio*t) * np.exp(-t*decay)
        x += filter_noise(RNG.normal(0, .055, len(t)), 1700, 5800)*np.exp(-t*95)
        return edge(x, .0025, .04) * velocity
    if kind == 'pad':
        x = np.zeros_like(t)
        for h in range(1, 8):
            x += (np.sin(2*np.pi*f*h*.9991*t+.35*h) + np.sin(2*np.pi*f*h*1.0009*t-.31*h)) / (h**2.0)
        env = np.minimum(1, t/.14)*np.minimum(1, (duration-t)/.26)
        return x * env * .16 * velocity
    if kind == 'bass':
        phase = 2*np.pi*f*t + .022*np.sin(2*np.pi*4.8*t)
        x = np.sin(phase)*.7 + np.sin(phase*2)*.22*np.exp(-t*3)
        for h in range(3, 8):
            x += np.sin(phase*h)*(.10/h)*np.exp(-t*(3+h))
        x = np.tanh(x*1.65)/1.25
        return edge(x*np.exp(-t*1.4), .005, .028) * velocity
    if kind == 'pluck':
        phase = 2*np.pi*f*t
        x = sum(np.sin(phase*h + .13*h) / h**1.15 * np.exp(-t*(2.9+h*.70)) for h in range(1, 10))
        x = np.tanh(x*1.45)*.66
        return edge(x, .004, .035) * velocity
    if kind == 'guitar':
        # Two detuned, band-limited picked strings through gentle saturation.
        x = np.zeros_like(t)
        for detune in [.998, 1.002]:
            phase = 2*np.pi*f*detune*t
            for h in range(1, 15):
                x += np.sin(phase*h) * np.exp(-t*(1.7+h*.55)) / h**1.3
        x = np.tanh(x*2.5)*.50
        return edge(x, .004, .045) * velocity
    raise ValueError(kind)


def drum(kind, velocity=1):
    duration = {'kick': .35, 'snare': .28, 'hat': .075, 'openhat': .24, 'clack': .09, 'tom': .21, 'crash': 1.5}[kind]
    t = time_axis(duration)
    noise = RNG.normal(0, 1, len(t)).astype(np.float32)
    if kind == 'kick':
        phase = 2*np.pi*(49*t + 105*.016*(1-np.exp(-t/.016)))
        x = np.sin(phase)*np.exp(-t*12.5) + filter_noise(noise, 650, 5200)*np.exp(-t*160)*.13
        x = np.tanh(x*1.4)*.91
    elif kind == 'snare':
        body = (np.sin(2*np.pi*178*t)*.47 + np.sin(2*np.pi*293*t)*.18)*np.exp(-t*25)
        snap = filter_noise(noise, 1150, 7800)*np.exp(-t*23)*.62
        # Tiny repeat excites the spring wires; prevents a flat white-noise hiss.
        snap += np.roll(snap, 241)*.13
        x = np.tanh((body+snap)*1.3)*.90
    elif kind in ('hat', 'openhat', 'crash'):
        metallic = sum(np.sin(2*np.pi*f*t) for f in [3481, 4237, 5123, 6371, 7963])*.055
        x = (filter_noise(noise, 4300, 10800)*.29 + metallic)
        decay = {'hat': 62, 'openhat': 16, 'crash': 3.6}[kind]
        x *= np.exp(-t*decay)
    elif kind == 'clack':
        x = (np.sin(2*np.pi*931*t)*.35 + np.sin(2*np.pi*1537*t)*.18)*np.exp(-t*82)
        x += filter_noise(noise, 1700, 5800)*np.exp(-t*125)*.19
    else:
        phase = 2*np.pi*(94*t + 57*.032*(1-np.exp(-t/.032)))
        x = np.sin(phase)*np.exp(-t*19)*.65 + filter_noise(noise, 600, 4700)*np.exp(-t*75)*.11
    return edge(x, .001, .008) * velocity


def add(stem, beat, x, gain=1, pan=0, human_ms=0):
    start = round((beat * BEAT + human_ms*.001) * SR) % N
    x = np.asarray(x, dtype=np.float32) * gain
    # Constant-power pan. Low frequencies stay centred; stereo ambience is added later.
    p = np.array([math.cos((pan+1)*math.pi/4), math.sin((pan+1)*math.pi/4)], dtype=np.float32)
    value = x[:, None] * p[None, :]
    a = min(len(x), N-start)
    STEMS[stem][start:start+a] += value[:a]
    if a < len(x):
        STEMS[stem][:len(x)-a] += value[a:]


def note(stem, kind, bar, beat, pitch, length, gain, pan=0):
    add(stem, bar*4+beat, tone(kind, pitch, length*BEAT), gain, pan)
    EVENTS.append({'stem': stem, 'instrument': kind, 'bar': bar+1, 'beat': beat, 'midi': pitch, 'beats': length})


# Minor-key harmony moves from resolve through lift, breathes, then builds home.
DM, BB, FF, CC, GM, AA = (38, [62,65,69]), (34,[62,65,70]), (41,[60,65,69]), (36,[60,64,67]), (31,[62,67,70]), (33,[61,64,69])
HARMONY = ([DM, DM, BB, BB, FF, FF, CC, AA]*4 + [GM, GM, BB, BB, DM, DM, AA, AA] + [DM, BB, FF, CC, GM, BB, AA, AA])
MOTIF = [
    [(0,74,1.3), (1.5,77,.6), (2.5,81,.7), (3.5,77,.45)],
    [(.5,76,.8), (1.5,74,.8), (3,69,.85)],
    [(0,74,1.4), (1.5,77,.7), (2.75,82,.6)],
    [(.5,81,.7), (1.5,77,.7), (3,74,.8)],
    [(0,77,1.2), (1.5,81,.8), (2.75,84,.8)],
    [(.5,81,.75), (1.75,79,.6), (3,77,.8)],
    [(0,76,1.3), (1.5,79,.8), (2.75,72,.8)],
    [(.5,73,.65), (1.5,76,.65), (2.5,81,.6), (3.5,73,.45)],
]
KICKS = [[0,1.75,2.5], [0,.75,2,3.5], [0,1.5,2.75], [0,.75,2.5,3.25]]


def compose():
    for bar in range(BARS):
        root, chord = HARMONY[bar]
        breakdown = 32 <= bar < 36
        lift = 16 <= bar < 32 or bar >= 40
        phrase_end = bar % 8 == 7
        # Base: warmly voiced felt-string harmony and a recurring music-box theme.
        for ci, pitch in enumerate(chord):
            note('clockwork', 'pad', bar, 0, pitch-12, 4.35, .30, [-.43,.35,.03][ci])
        melody = MOTIF[bar % 8]
        if 32 <= bar < 40:
            melody = [(0, chord[1]+12, 2.2), (2.5, chord[0]+12, 1.4)]
        for beat, pitch, length in melody:
            if bar >= 40 and beat == 0:
                note('clockwork','box',bar,beat,pitch-12,2.4,.14,-.25)
            note('clockwork','box',bar,beat,pitch,max(1.7,length*1.65),.31 if lift else .27, .12*math.sin(bar))
        # Quiet wooden clock teeth stitch the setting to the musical groove.
        for beat in [.5,1.5,2.5,3.5]:
            add('clockwork', bar*4+beat, drum('clack', .28), .16, -.52 if beat < 2 else .52)
        # Driving syncopated bass, deliberately leaving space around the snare.
        bass_pattern = [(0,.62,0),(.75,.39,0),(1.5,.38,12),(2,.62,0),(2.75,.38,7),(3.5,.39,12)]
        if breakdown:
            bass_pattern = [(0,1.6,0),(2.5,.8,7)]
        for beat, length, offset in bass_pattern:
            note('drive','bass',bar,beat,root+offset,length,.60)
        # Mildly swung breakbeat. Alternate ghosts and phrase fills prevent a metronome loop.
        for beat in (KICKS[bar%4] if not breakdown else [0,2.5]):
            add('drive',bar*4+beat,drum('kick'),.83)
        for beat in ([1,3] if not breakdown else [3]):
            add('drive',bar*4+beat,drum('snare'),.59, .02, 3)
        if not breakdown:
            for beat in ([2.75,3.75] if bar%2 else [.75,2.5]):
                add('drive',bar*4+beat,drum('snare', .31),.39,-.12, 6)
        for eighth in range(8):
            if breakdown and eighth % 2 == 0:
                continue
            pos = eighth*.5 + (.025 if eighth%2 else 0)
            add('drive',bar*4+pos,drum('hat', .64 if eighth%2==0 else .90), .28, .32, RNG.uniform(-3,3))
        if bar%2==1 and not breakdown:
            add('drive',bar*4+3.5,drum('openhat'),.25,.36)
        # Offbeat filtered chord plucks give motion without fighting the melody.
        for beat in ([.5,2.5] if not lift else [.5,1.75,2.5,3.5]):
            for ci,pitch in enumerate(chord):
                note('drive','pluck',bar,beat,pitch-12,.42,.085, [-.65,.60,-.16][ci])
        # High energy layer: low power chords, tom fills and a replying picked motif.
        if not breakdown:
            for beat in [0,1.5,2.75]:
                for pitch, pan in [(root+12,-.58),(root+19,.58)]:
                    note('overdrive','guitar',bar,beat,pitch,.60,.14,pan)
            for beat,pitch in [(1.75,chord[0]+12),(2.25,chord[1]+12),(3.5,chord[2]+12)]:
                if lift or bar%2:
                    note('overdrive','pluck',bar,beat,pitch,.65,.115,-.24)
            for beat in [1,3]:
                add('overdrive',bar*4+beat,drum('snare'),.21,-.08, 7)
        if bar%8==0:
            add('drive',bar*4,drum('crash'),.27,-.31)
        if phrase_end:
            for i,beat in enumerate([2.5,2.75,3.25,3.5,3.75]):
                add('overdrive',bar*4+beat,drum('tom' if i%2==0 else 'snare'),.30+i*.04,(i-2)*.22)
            for beat in [3.25,3.5,3.75]:
                add('drive',bar*4+beat,drum('hat'),.20,.28)
        if bar in [15,31,39,47]:
            # Shaped reverse-cymbal pickup, including the end-to-start handoff.
            x = drum('crash')[::-1].copy()
            add('overdrive',bar*4+.5,x,.16,.18)


def circular_delay(x, delays):
    y = x.copy()
    for beats, gain, cross in delays:
        z = np.roll(x, round(beats*BEAT*SR), axis=0)
        if cross:
            z = z[:,::-1]
        y += z*gain
    return y


def circular_eq(x, hp, lp):
    # Periodic filters preserve the loop; there is no tail abruptly cut at EOF.
    freqs = np.fft.rfftfreq(N,1/SR)
    shape = (1-np.exp(-(freqs/hp)**4))*np.exp(-(freqs/lp)**6)
    return np.fft.irfft(np.fft.rfft(x,axis=0)*shape[:,None],n=N,axis=0).astype(np.float32)


def write_wav(path,x):
    with wave.open(str(path),'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR)
        # Deterministic triangular dither below the audibility threshold.
        d=(RNG.uniform(-.5,.5,x.shape)+RNG.uniform(-.5,.5,x.shape))/32768
        w.writeframes((np.clip(x+d,-.999969,.999969)*32767).astype('<i2').tobytes())


def metrics(x):
    diff=np.diff(x,axis=0)
    seam=np.abs(x[0]-x[-1])
    return {'samples':len(x),'seconds':len(x)/SR,'peak_dbfs':round(20*np.log10(max(float(np.max(np.abs(x))),1e-9)),3),
            'rms_dbfs':round(20*np.log10(max(float(np.sqrt(np.mean(x*x))),1e-9)),3),
            'clipped_samples':int(np.count_nonzero(np.abs(x)>=1)),
            'seam_step':seam.tolist(),'max_adjacent_step':np.max(np.abs(diff),axis=0).tolist(),
            'dc_offset':np.mean(x,axis=0).tolist()}


def main():
    OUT.mkdir(parents=True,exist_ok=True);REPORT.mkdir(parents=True,exist_ok=True)
    compose()
    STEMS['clockwork']=circular_eq(circular_delay(STEMS['clockwork'],[(.75,.19,True),(1.5,.09,False),(2.25,.045,True)]),120,7300)
    STEMS['drive']=circular_eq(circular_delay(STEMS['drive'],[(.075,.042,True),(.15,.025,False)]),30,10500)
    STEMS['overdrive']=circular_eq(circular_delay(STEMS['overdrive'],[(.5,.14,True),(.75,.07,False)]),125,8000)
    # Music-box remains legible under the mechanical drums. Drive carries the sub.
    for name,target in [('clockwork',.073),('drive',.135),('overdrive',.065)]:
        x=STEMS[name]
        x*=target/np.sqrt(np.mean(x*x))
    mix=sum(STEMS.values())
    # Shared smooth gain control keeps phase/relative level intact across stems.
    peak=np.max(np.abs(mix),axis=1)
    gain=np.minimum(1,.73/np.maximum(peak,1e-7))
    gain=np.minimum(gain,np.roll(gain,-1))
    # 15 ms look-ahead maximum detector followed by 45 ms smoothing.
    for distance in [2,4,8,16,32,64,128,256]:
        gain=np.minimum(gain,np.roll(gain,-distance))
    k=1985
    extended=np.concatenate([gain[-k:],gain,gain[:k]])
    cumulative=np.concatenate([[0.0],np.cumsum(extended,dtype=np.float64)])
    smooth=(cumulative[k:]-cumulative[:-k])/k
    smooth=smooth[k//2:k//2+N]
    gain=np.minimum(smooth,.86/np.maximum(peak,1e-7))
    for name in STEMS:
        STEMS[name]*=gain[:,None]
    report={'title':'发条不眠 / Clockwork After Hours','bpm':BPM,'meter':'4/4','key':'D minor','bars':BARS,'sample_rate':SR,
            'source':'Original composition and procedural synthesis; no external recordings or pretrained music model.',
            'form':'1–16 theme; 17–32 reply/lift; 33–40 half-time bridge; 41–48 full return and turnaround.',
            'loop_method':'Exact integer beat grid, periodic tail folding, circular ambience/filters, aligned stems.',
            'stems':{}}
    for name,x in STEMS.items():
        wav=OUT/(name+'.wav')
        write_wav(wav,x)
        report['stems'][name]=metrics(x)
    full=sum(STEMS.values())
    write_wav(OUT/'full_mix.wav',full)
    subprocess.run(['/opt/homebrew/bin/ffmpeg','-v','error','-y','-i',str(OUT/'full_mix.wav'),'-c:a','libmp3lame','-q:a','2',str(OUT/'发条不眠.mp3')],check=True)
    report['full_mix']=metrics(full)
    (OUT/'score.json').write_text(json.dumps({'bpm':BPM,'bars':BARS,'events':EVENTS},ensure_ascii=False,indent=2))
    (REPORT/'music-analysis.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
