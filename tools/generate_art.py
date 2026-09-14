from pathlib import Path
import urllib.request,urllib.error,json,base64,shutil,time
ROOT=Path(__file__).resolve().parents[1]
BASE='http://127.0.0.1:3000'
REF=ROOT/'source/art-direction-v1.png'
def call(path,data=None,timeout=600):
 req=urllib.request.Request(BASE+path,data=json.dumps(data).encode() if data else None,headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=timeout) as f:return json.load(f)
def image(name,prompt,size):
 record=ROOT/'source'/f'{name}-job.json'
 if record.exists():return json.loads(record.read_text())
 request={'regionId':'domestic','imageModel':'pro','prompt':prompt,'size':size,'n':1,'image':'data:image/png;base64,'+base64.b64encode(REF.read_bytes()).decode(),'watermark':False,'outputFormat':'png','requestId':'img-scrapbound-'+name+'-v1'}
 (ROOT/'source'/f'{name}-prompt.txt').write_text(prompt)
 print('Submitting image',name,flush=True)
 try:r=call('/api/image',request)
 except Exception as e:
  print('Image request interrupted. Query existing ID before resubmission.',str(e),flush=True);raise
 record.write_text(json.dumps(r,ensure_ascii=False,indent=2))
 u=(r.get('outputUrls') or r['assets'])[0]
 with urllib.request.urlopen(BASE+u if u.startswith('/') else u) as f:(ROOT/'source'/f'{name}.png').write_bytes(f.read())
 print('Saved',name,r.get('id'),flush=True)
 return r
image('characters', '''Using the reference art direction, make a production character reference sheet of exactly FOUR isolated full-body characters in a precise 2 by 2 layout. Each quadrant is an equal square. Entire image has a perfectly flat solid vivid magenta RGB(255,0,255) background, including space between characters. No text, no panels, no lines, no floor, no shadows, no props other than character equipment. Each character occupies the middle 65 percent of its quadrant with generous empty margin, entire silhouette visible. All four face screen RIGHT at a slight three-quarter angle with face and front visible, orthographic elevated 45 degree camera suitable for a top-down 2.5D arena game. Consistent soft top left light. Beautiful tangible hand-painted toy miniature style matching reference, cream cloth, teal accents, aged tin and muted mustard plastic.
TOP LEFT: same original repaired cream canvas ragdoll as reference, square soft head, single teal button eye, cross-stitched other eye, ochre forehead patch, short teal scarf, stubby arms and legs, battery backpack. Hold the red bottle-cap saw with clothespin handle at waist in right hand, lowered and clearly visible. No extra weapons.
TOP RIGHT: the reference rusty wind-up tin mouse, rounded dark teal metal body, big rounded metal ears, brass winding key, thin tail, four small legs, red eye. Face right.
BOTTOM LEFT: the reference chunky mustard yellow toy car with rusted metal front bumper and spikes, four chunky wheels, small winding key on top, front faces right.
BOTTOM RIGHT: the reference broken toy doll, pale rounded head with button eyes and a small tuft, mismatched violet jointed limbs, two elongated legs and two arms, unsettling but playful, facing right. Keep each design singular, compact and recognizable. No gore, no cinematic background, no photographic room.''','2048x2048')
image('arena', '''Create ONLY an empty playable overhead arena background matching the supplied toy-wasteland art reference. Landscape 16:9, orthographic directly overhead floor, NO characters, NO weapons, NO pickups, NO UI, NO text, NO shadows of characters. The ENTIRE central 85 percent must be an open unobstructed faded blue-grey and muted sage children's rug, very low contrast soft textile fibers with a very faint large faded stitched star near center, desaturated and readable. Fine handcrafted textile quality, subtle repairs. At ONLY the outermost 5 percent frame edges: aged cardboard walls, muted yellow and teal chipped wooden blocks, a large thread spool partially cropped at top right, bits of old fabric and tape. Edge debris must stay outside playable center. Soft ambient warm light upper left, tactile handpainted 2.5D miniature materials. Less brown and much less noisy than reference, beautiful subdued blue-grey floor lets cream ragdoll and yellow cars stand out. No perspective horizon, no isometric diamond, no strong directional cast shadows, no central furniture. Seamless cohesive full-frame environment art.''','2560x1440')
