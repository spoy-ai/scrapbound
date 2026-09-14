"""Original short bottle-cap saw effects; NumPy synthesis, no external samples.

Only writes assets/v04/audio/. Run offline; the game loads the rendered WAVs.
The same seed reproduces each layered sound, along with a measurable QA report.
"""
from pathlib import Path
import json
import math
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/v04/audio'
SR = 44100
RNG = np.random.default_rng(904713)


def axis(seconds):
    return np.arange(round(seconds*SR), dtype=np.float64)/SR


def noise(n, lo, hi):
    x = RNG.normal(0, 1, n)
    f = np.fft.rfftfreq(n, 1/SR)
    # Rounded spectral limits keep the clicks detailed without brittle hiss.
    shape = (1-np.exp(-(f/max(lo,1))**4))*np.exp(-(f/hi)**6)
    y = np.fft.irfft(np.fft.rfft(x)*shape,n)
    return y/max(float(np.sqrt(np.mean(y*y))),1e-8)


def fade(x, attack=.0015, release=.023):
    n, r = min(len(x), round(attack*SR)), min(len(x), round(release*SR))
    x[:n] *= np.linspace(0,1,n)**.65
    x[-r:] *= np.linspace(1,0,r)**1.5
    x[0] = 0
    x[-1] = 0
    return x


def glide(t, start_hz, end_hz, bend):
    # Analytic integrated frequency prevents the pitch warble of f(t)*t.
    return 2*np.pi*(end_hz*t + (start_hz-end_hz)*bend*(1-np.exp(-t/bend)))


def ring(t, at, freq, strength, decay=50):
    s = np.maximum(t-at,0)
    return np.where(t>=at,np.sin(2*np.pi*freq*s)*np.exp(-s*decay)*np.minimum(s*2200,1)*strength,0)


def spatial(mid, width=.07, motion=0):
    # Almost-mono transients retain force; a short, quiet reflection creates width.
    side = (np.roll(mid,37)-np.roll(mid,91))*width
    side[:91] = 0
    pan = np.linspace(-motion,motion,len(mid))
    x = np.column_stack([mid*np.cos((pan+1)*np.pi/4)+side,
                         mid*np.sin((pan+1)*np.pi/4)-side])
    for i in range(2):
        fade(x[:,i],.001,.020)
    return x


def swing(seconds, reverse=False, heavy=False):
    t = axis(seconds)
    peak_at = .069 if heavy else (.049 if reverse else .040)
    width = .039 if heavy else .029
    air_env = np.exp(-.5*((t-peak_at)/width)**2)
    # Passing air has a chesty lower layer and a very brief edge, not a long motor whine.
    air = noise(len(t),220,4600 if heavy else 5400)*air_env*.20
    body = noise(len(t),90,1100)*air_env*(.29 if heavy else .17)
    phase = glide(t,790 if heavy else 1150,215 if heavy else 370,.037)
    tooth = (np.sin(phase)*.20 + np.sin(phase*2.13)*.07 + np.sin(phase*3.71)*.025)
    tooth *= np.exp(-.5*((t-(peak_at+.005))/(width*.77))**2)
    # Three discrete tooth catches identify the saw and articulate the release.
    gear = sum(ring(t,at,freq,gain,75) for at,freq,gain in [
        (.014,1410,.065),(.042,1013,.083),(.082 if heavy else .067,677,.055)])
    x = air+body+tooth+gear
    if heavy:
        x += np.sin(glide(t,175,68,.023))*np.exp(-.5*((t-.067)/.044)**2)*.22
    x = np.tanh(x*1.20)/1.20
    fade(x,.002,.034)
    return spatial(x,.065,-.19 if reverse else .19)


def impact_metal(seconds):
    t = axis(seconds)
    # Initial contact: short low knock, steel snap, then several rattling teeth.
    knock = np.sin(glide(t,260,110,.013))*np.exp(-t*52)*.40
    snap = noise(len(t),850,6900)*np.exp(-t*103)*.30
    clang = sum(ring(t,0,f,g,d) for f,g,d in [(621,.22,44),(1171,.14,61),(2077,.08,82),(3673,.035,112)])
    pieces = sum(ring(t,at,f,g,95) for at,f,g in [(.023,1691,.070),(.041,2329,.056),(.074,1283,.045),(.098,2519,.028)])
    return spatial(fade(np.tanh((knock+snap+clang+pieces)*1.12)/1.12),.10)


def impact_cloth(seconds):
    t = axis(seconds)
    # Stuffing compresses first; the seam's short rip follows six milliseconds later.
    thud = np.sin(glide(t,176,74,.018))*np.exp(-t*40)*.62
    cushion = noise(len(t),85,1250)*np.exp(-t*57)*.32
    rip_env = np.exp(-np.maximum(t-.006,0)*67)*np.minimum(t/.006,1)
    rip = noise(len(t),1550,4300)*rip_env*.13
    button = ring(t,.022,811,.046,85)+ring(t,.041,547,.027,92)
    return spatial(fade(np.tanh((thud+cushion+rip+button)*1.05)/1.05),.075)


def finish(seconds):
    t = axis(seconds)
    # One strong disassembly accent, followed by rapidly shrinking loose fragments.
    body = np.sin(glide(t,193,61,.020))*np.exp(-t*26)*.60
    crack = noise(len(t),470,7300)*np.exp(-t*87)*.34
    woody = noise(len(t),200,2500)*np.exp(-t*43)*.24
    shell = sum(ring(t,0,f,g,d) for f,g,d in [(373,.23,34),(811,.15,41),(1397,.10,57),(2591,.05,80)])
    chips = np.zeros_like(t)
    for i,(at,freq) in enumerate([(.026,2111),(.051,1387),(.087,2797),(.126,941),(.179,1907),(.227,1141)]):
        chips += ring(t,at,freq,.075*.72**i,71+i*6)
        s = np.maximum(t-at,0)
        chips += noise(len(t),900,5400)*np.where(t>=at,np.exp(-s*175),0)*.043*.65**i
    x = np.tanh((body+crack+woody+shell+chips)*1.26)/1.26
    return spatial(fade(x,.0012,.055),.13)


SOUNDS = {
    'saw_swing_a': (.190, -4.0, -13, '瓶盖锯正向轻挥；开始挥动时触发', lambda d:swing(d)),
    'saw_swing_b': (.215, -4.0, -13, '交替反向轻挥；与 a 轮流使用', lambda d:swing(d,reverse=True)),
    'saw_swing_heavy': (.290, -3.5, -11, '每第三次重挥；比轻挥更低沉、更宽', lambda d:swing(d,heavy=True)),
    'saw_hit_metal': (.205, -3.5, -10, '锯齿咬合金属的接触瞬间；鼠、车、甲虫等', impact_metal),
    'saw_hit_cloth': (.175, -3.5, -10, '填充物闷击与短布缝撕裂；布偶、柔软目标', impact_cloth),
    'saw_finish': (.425, -3.0, -10, '重击击杀或连拆高潮；不要对同帧每个敌人重复叠加', finish),
}


def db(x):
    return 20*math.log10(max(float(x),1e-12))


def inspect_pcm(x, decoded, target_peak):
    absolute = np.abs(x)
    energy = np.mean(x*x,axis=1)
    cumulative = np.cumsum(energy)
    total = max(float(cumulative[-1]),1e-12)
    fft = np.fft.rfft(x,axis=0)
    spectral = np.sum(np.abs(fft)**2,axis=1)
    freq = np.fft.rfftfreq(len(x),1/SR)
    last20 = x[-round(.02*SR):]
    true_peak = np.max(np.abs(decoded))
    return {
        'sample_rate':SR,'channels':2,'frames':len(x),'seconds':len(x)/SR,
        'sample_peak_dbfs':round(db(np.max(absolute)),3),
        'true_peak_4x_dbfs':round(db(true_peak),3),
        'rms_dbfs':round(db(np.sqrt(np.mean(x*x))),3),
        'dc_offset':np.mean(x,axis=0).tolist(),
        'clipped_samples':int((absolute>=1).sum()),
        'first_sample':x[0].tolist(),'last_sample':x[-1].tolist(),
        'energy_95_percent_ms':round(np.searchsorted(cumulative,total*.95)/SR*1000,2),
        'energy_99_percent_ms':round(np.searchsorted(cumulative,total*.99)/SR*1000,2),
        'last_20ms_rms_dbfs':round(db(np.sqrt(np.mean(last20*last20))),3),
        'energy_above_8khz_fraction':float(np.sum(spectral[freq>8000])/np.sum(spectral)),
        'checks':{
            'under_half_second':len(x)/SR<.5,
            'zero_sample_clipping':not bool((absolute>=1).any()),
            'true_peak_below_minus_2_dbfs':db(true_peak)<-2,
            'endpoints_silent':bool((x[0]==0).all() and (x[-1]==0).all()),
            'tail_below_minus_45_dbfs':db(np.sqrt(np.mean(last20*last20)))<-45,
            'low_dc':bool(np.max(np.abs(np.mean(x,axis=0)))<.001),
        },
    }


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    report={'source':'Original offline NumPy synthesis, no recordings or paid services.',
            'format':'44.1 kHz / stereo / signed PCM16 WAV; one-shot, not looping.',
            'sounds':{}}
    for name,(duration,target_peak,volume,usage,builder) in SOUNDS.items():
        x=builder(duration)
        # Remove tiny numerical DC before the final envelope and set conservative peaks.
        x-=np.mean(x,axis=0)
        for channel in range(2):fade(x[:,channel],.001,.020)
        x*=10**(target_peak/20)/max(float(np.max(np.abs(x))),1e-8)
        pcm=np.rint(x*32767).astype('<i2')
        path=OUT/(name+'.wav')
        with wave.open(str(path),'wb') as w:
            w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
        # Inspect the actual output PCM, including a 4x reconstruction peak check.
        data=pcm.astype(np.float64)/32768
        result=subprocess.run(['/opt/homebrew/bin/ffmpeg','-v','error','-i',str(path),'-af','aresample=176400','-f','f32le','pipe:1'],check=True,capture_output=True)
        decoded=np.frombuffer(result.stdout,dtype='<f4').reshape(-1,2)
        metrics=inspect_pcm(data,decoded,target_peak)
        metrics['recommended_player_volume_db']=volume
        metrics['usage']=usage
        report['sounds'][name]=metrics
        assert all(metrics['checks'].values()),(name,metrics['checks'])
    (OUT/'audio-analysis.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    lines=['# 瓶盖锯短音效','',
           '六个本地原创合成音效，无外部录音、采样包或收费服务。离线渲染，运行时直接加载 WAV。', '',
           '| 文件 | 时长 | 建议播放器音量 | 触发 |','| --- | --- | --- | --- |']
    for name,(duration,_,volume,usage,_) in SOUNDS.items():
        lines.append(f'| {name}.wav | {duration:.3f} 秒 | {volume} dB | {usage} |')
    lines+=['','轻挥 a/b 轮流使用，轻挥可微调 pitch_scale 到 0.96–1.04；重挥使用自己的低沉音色，不需要再大幅降速。挥动音在起手后刀刃加速时播放，材质命中音只在真实接触帧播放。',
            '', '多目标一击建议最多叠一条主要材质命中音和一条终结音；同组命中共用 60–80 毫秒的短音效间隔，避免每个敌人都触发导致音量暴涨。终结音仅在重击击杀或连拆高潮触发。',
            '', '表中数值为 AudioStreamPlayer.volume_db 的建议绝对值。原音效池默认 -15 dB，如果逐音效改音量，应在每次播放时明确设回该音效需要的值，避免音量残留影响其他音效。',
            '', '44,100 Hz、立体声、16-bit PCM，全部小于 0.5 秒，首尾采样归零。输出 PCM 经 FFmpeg 四倍过采样检查真实峰值；各音效保留至少 2 dB 真实峰值余量，没有削波，末尾 20 毫秒低于 -45 dB RMS。具体峰值、有效能量时长和检查结果见 audio-analysis.json。',
            '', '复现：运行 tools/v04_saw_audio.py。脚本只写本目录。信号检查验证时长、余量与收尾，最终音量应在战斗中结合现有配乐与其他音效听调。']
    (OUT/'README.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps({name:{k:v for k,v in data.items() if k in ['seconds','sample_peak_dbfs','true_peak_4x_dbfs','energy_95_percent_ms','last_20ms_rms_dbfs','checks']} for name,data in report['sounds'].items()},ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
