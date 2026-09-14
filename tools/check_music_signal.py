"""Inspect actual Godot AudioEffectCapture output from check_music.gd."""
from pathlib import Path
import json
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
P = ROOT/'captures/v03'
run = json.loads((P/'music-runtime-test.json').read_text())
sr = int(run['captured_sample_rate'])
x = np.fromfile(P/'music-runtime.f32', dtype='<f4').reshape(-1, 2)


def stats(y):
    return {'rms_dbfs': round(float(20*np.log10(max(np.sqrt(np.mean(y*y)), 1e-10))), 3),
            'peak_dbfs': round(float(20*np.log10(max(np.max(np.abs(y)), 1e-10))), 3),
            'clipped_samples': int((np.abs(y)>=1).sum())}


r = {'seconds': len(x)/sr, 'whole_recording': stats(x), 'regions': {}, 'discarded_capture_frames': run['capture_discarded_frames']}
for label, check_label, seconds in [
    ('upgrade', 'upgrade reduces rhythm', .25),
    ('paused', 'pause reduces background', .25),
    ('muted', 'mute fades player below minus 55 dB', .15),
    ('unmuted', 'unmute restores volume', .25),
    ('after_loop', 'all stems loop without stopping', .25),
]:
    check = next(c for c in run['checks'] if c['label']==check_label)
    end = check['captured_frames']
    y = x[end-round(seconds*sr):end]
    r['regions'][label] = stats(y)
    r['regions'][label]['capture_end_frame'] = end
r['checks'] = {
    'no_clipping': r['whole_recording']['clipped_samples']==0,
    'mute_signal_below_minus_55_db': r['regions']['muted']['rms_dbfs'] < -55,
    'restored_signal_more_than_25_db_above_muted': r['regions']['unmuted']['rms_dbfs']-r['regions']['muted']['rms_dbfs'] > 25,
    'loop_continues_with_nonzero_audio': r['regions']['after_loop']['rms_dbfs'] > -40,
    'no_capture_overflow': r['discarded_capture_frames']==0,
}
(P/'music-engine-signal.json').write_text(json.dumps(r, indent=2))
print(json.dumps(r, indent=2))
assert all(r['checks'].values()), 'Actual mixer signal checks failed'
