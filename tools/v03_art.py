"""Versioned, resumable Ai-DF requests for Scrapbound v0.3 gameplay art."""
from pathlib import Path
import base64, hashlib, json, sys, urllib.request, urllib.error
from PIL import Image

R = Path(__file__).resolve().parents[1]
S = R / 'source/v03'
A = R / 'assets/v03/art'
BASE = 'http://127.0.0.1:3000'
S.mkdir(parents=True, exist_ok=True)
A.mkdir(parents=True, exist_ok=True)

def api(path, body=None, timeout=600):
    req = urllib.request.Request(BASE + path, data=json.dumps(body).encode() if body is not None else None, headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as f:
            return json.load(f)
    except urllib.error.HTTPError as e:
        raise RuntimeError(str(e.code) + ' ' + e.read().decode()[:1800]) from None

def dataurl(path):
    return 'data:image/png;base64,' + base64.b64encode(Path(path).read_bytes()).decode()

def download(url, path):
    with urllib.request.urlopen(BASE + url if url.startswith('/') else url, timeout=120) as f:
        Path(path).write_bytes(f.read())

STYLE = '''Match the attached reference exactly in its tactile handcrafted toy-wasteland art direction: premium miniature render, warm soft top-left lighting, fine convincing fabric stitching, chipped paint, old wood grain, oxidized brass and teal accents. Distinct compact silhouette and readable detailed materials. Orthographic elevated 45 degree three-quarter view facing right, consistent with top-down game assets. Strictly flat saturated MAGENTA #ff00ff background, no shadows on background, no floor, no gradient, no environment, no captions, no text, letters, watermark or logos. No purple/magenta parts on the objects. '''
IMAGES = {
    'musicbox': STYLE + '''One gorgeous original salvage MUSIC BOX for a toy survivor game. A low octagonal honey-brown wooden box with chipped teal lid standing open, small brass star inlay, stitched cream canvas strap, exposed polished brass toothed musical cylinder and steel comb clearly visible inside. Small double-loop brass winding key protrudes from the right side. A tiny carved wooden songbird figure stands on a little circular disk above the mechanism, as an automaton. Four little brass feet. Touches of deep muted red fabric in lining. Warm amber glow from inside but no particles. Full object centered, occupies only 62 percent of the square so moving parts have ample space, base feet at 78 percent of the image height. Miniature toy-scale, beautifully aged but functional. No extra objects, no humans.''',
    'recycler': STYLE + '''One beautiful original magnetic SALVAGE RECYCLER assembled from discarded toys. Compact squat machine, circular dark teal painted tin body, big visible copper wire coil around a cream ceramic upright core, two curved brass prongs forming a small U-shaped magnet above an open front hopper. A chunky winding handle and small exposed gears on its right side. Four rounded stubby wooden feet. Tiny warm amber bulb, a little canvas patch riveted to the teal casing. A few old gears rest INSIDE the hopper, no loose debris outside. Worn brass, copper, old teal paint, ivory cloth and weathered wood, match handmade toys, no real factory machine or sharp industrial clutter. Full object centered, occupies only 62 percent of the square, base feet at 78 percent of image height. No lightning or floating particles yet, no steam, no characters.''',
    'build-icons': STYLE + '''Production icon sheet in EXACT 2 columns by 2 rows, four distinct isolated handmade item groups. Every group entirely within its quadrant with at least 18 percent empty magenta margins, no grid lines, no frames, no labels. TOP LEFT: a powerful red bottle-cap circular saw with jagged brass teeth, a reinforced wooden clothespin handle wrapped in cream canvas and two small interlocking brass gears; compact readable diagonal silhouette. TOP RIGHT: two thick convex teal sewing buttons with four visible holes each, connected by ONE looping strong GOLDEN thread that passes through their holes, one button slightly above-left of the other, delicate realistic thread and clear button holes. BOTTOM LEFT: a little stout copper electrical coil beside a tiny charming sewing-spool helper robot, wooden spool body wrapped with teal thread, two small brass feet, cream cloth cap, button eye, one little clothespin turret arm, unified compact group. BOTTOM RIGHT: a tightly wound exposed spiral BRASS CLOCKWORK SPRING in a round aged bronze housing with a double-loop winding key, strong amber core glow within its concentric spring turns, cream canvas wrap on lower edge, no floating effects outside silhouette. Clear original inventory art, physically convincing volume, no pixel art.'''
}

def images():
    selected = sys.argv[2:] or list(IMAGES)
    for name in selected:
        prompt = IMAGES[name]
        target = S / (name + '.png')
        record = S / (name + '-image-request.json')
        job = S / (name + '-image-job.json')
        if target.exists():
            continue
        rid = 'img-scrapbound-v03-' + name
        if record.exists():
            result = api('/api/image/jobs/' + rid)
            if result.get('status') != 'succeeded':
                print(name, 'existing', result.get('status'), flush=True)
                continue
        else:
            body = dict(regionId='domestic', imageModel='pro', size='2048x2048', n=1, watermark=False, outputFormat='png', prompt=prompt, requestId=rid, image=dataurl(R/'source/v02/target-reference.png'))
            record.write_text(json.dumps({k:v for k,v in body.items() if k != 'image'}, ensure_ascii=False, indent=2))
            print('IMAGE', name, 'submitting', flush=True)
            result = api('/api/image', body)
        job.write_text(json.dumps(result, ensure_ascii=False, indent=2))
        urls = result.get('outputUrls') or result.get('assets') or result.get('remoteUrls')
        if not urls:
            raise RuntimeError('No output URL: ' + name)
        download(urls[0], target)
        print('IMAGE', name, 'saved', flush=True)

FIX = '''Game animation asset of exactly this handmade toy. Camera completely locked, orthographic elevated three-quarter view, constant scale, no zoom or pan. Same toy identity, materials, proportions and lighting throughout. Flat saturated solid MAGENTA #ff00ff background all frames, no floor or shadow on backdrop. Base feet never move; body never slides, rotates or bounces. Preserve generous margins and keep all motion safely within the central 70 percent. No text, new objects, characters, smoke, flashes or large effects. A seamless repeating four-second operating loop with small continuous mechanical motion; the first and last pose are identical. '''
MOTION = {
    'musicbox_loop': FIX + '''The brass winding key smoothly turns clockwise through exactly one full rotation. Inside the open box, the brass music cylinder rotates slowly while the little wooden songbird gently nods its head and pivots left-right only 15 degrees on its little disk. The lid stays steadily open. The brass mechanism catches tiny shifting warm highlights. This is a wind-up miniature music box quietly performing. Keep its entire wooden base absolutely fixed.''',
    'recycler_loop': FIX + '''The side winding handle and two little gears rotate slowly. The two curved brass magnetic prongs gently flex inward and outward by a tiny amount. The copper coil softly pulses with a subtle teal light between its windings, and a single small gear already inside the hopper trembles and lifts just a few pixels before settling back. The amber indicator glows rhythmically. Entire chassis and feet stay exactly fixed. No moving out of its original place, no exploding, no dramatic arcing lightning.'''
}

def videos():
    for name, prompt in MOTION.items():
        record = S / (name + '-video-request.json')
        job = S / (name + '-video-job.json')
        if record.exists() or job.exists():
            print(name, 'already submitted', flush=True)
            continue
        ref = S / (name.replace('_loop', '') + '-ref.png')
        if not ref.exists():
            print(name, 'waiting for reference', flush=True)
            continue
        body = dict(regionId='domestic', videoModel='seedance-2.5', mode='firstlast', resolution='480p', ratio='adaptive', duration=4, n=1, generateAudio=False, watermark=False, prompt=prompt, requestId='vid-scrapbound-v03-' + name.replace('_','-'), source='scrapbound-v03', firstFrame=dataurl(ref), lastFrame=dataurl(ref))
        meta = {k:v for k,v in body.items() if k not in ['firstFrame','lastFrame']}
        meta['reference_file'] = ref.name
        meta['reference_sha256'] = hashlib.sha256(ref.read_bytes()).hexdigest()
        record.write_text(json.dumps(meta, ensure_ascii=False, indent=2))
        print('VIDEO', name, 'submitting', flush=True)
        try:
            result = api('/api/video', body, 90)
        except Exception as e:
            (S/(name+'-submit-error.txt')).write_text(str(e))
            print(name, 'submission error', str(e), flush=True)
            continue
        job.write_text(json.dumps(result, ensure_ascii=False, indent=2))
        print(name, result.get('taskId'), flush=True)

def poll():
    for job in S.glob('*-video-job.json'):
        name = job.name.replace('-video-job.json','')
        target = S/(name+'.mp4')
        if target.exists():
            continue
        task = json.loads(job.read_text())['taskId']
        result = api('/api/video/'+task+'?regionId=domestic', timeout=45)
        (S/(name+'-video-status.json')).write_text(json.dumps(result, ensure_ascii=False, indent=2))
        print(name, result.get('status'), flush=True)
        if result.get('status') == 'succeeded':
            download(result.get('videoUrl') or result['remoteVideoUrl'], target)

if __name__ == '__main__':
    {'images':images, 'videos':videos, 'poll':poll}[sys.argv[1]]()
