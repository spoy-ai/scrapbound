from pathlib import Path
import urllib.request,urllib.error,json,base64,time,sys,hashlib
from PIL import Image
R=Path(__file__).resolve().parents[1];S=R/'source/v02';A=R/'assets/v02';BASE='http://127.0.0.1:3000'
def api(path,body=None,timeout=600):
 req=urllib.request.Request(BASE+path,data=json.dumps(body).encode() if body is not None else None,headers={'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=timeout) as f:return json.load(f)
 except urllib.error.HTTPError as e:
  raise RuntimeError(str(e.code)+' '+e.read().decode()[:1800]) from None
def dataurl(path):return 'data:image/png;base64,'+base64.b64encode(Path(path).read_bytes()).decode()
def download(url,path):
 with urllib.request.urlopen(BASE+url if url.startswith('/') else url,timeout=120) as f:Path(path).write_bytes(f.read())
def gen_image(name,prompt,size='2048x2048'):
 out=S/f'{name}.png';job=S/f'{name}-image-job.json';record=S/f'{name}-image-request.json'
 if out.exists():return
 rid='img-scrapbound-v02-'+name
 if record.exists():
  result=api('/api/image/jobs/'+rid)
  if result.get('status')!='succeeded':print(name,'existing image',result.get('status'),flush=True);return
 else:
  body={'regionId':'domestic','imageModel':'pro','size':size,'n':1,'watermark':False,'outputFormat':'png','prompt':prompt,'requestId':rid,'image':dataurl(S/'target-reference.png')}
  record.write_text(json.dumps({k:v for k,v in body.items() if k!='image'},ensure_ascii=False,indent=2))
  print('IMAGE',name,'submitted',flush=True)
  result=api('/api/image',body)
 job.write_text(json.dumps(result,ensure_ascii=False,indent=2))
 urls=result.get('outputUrls') or result.get('assets') or result.get('remoteUrls')
 if not urls:raise RuntimeError('No image URL: '+name)
 download(urls[0],out);print('IMAGE',name,'saved',flush=True)
STYLE='Match the attached toy-wasteland reference EXACTLY in tactile handcrafted style: convincing cream canvas stitching, chipped mustard/teal plastic, oxidized tin, brass, warm soft light, compact original toy silhouettes, premium polished handpainted miniature game assets. No text, letters, numbers, logos or watermarks. '
IMAGES=[
 ('new-enemies',STYLE+'''Production sheet, precise 2 by 2 layout, one isolated full body enemy in each equal quadrant, absolutely flat saturated MAGENTA #ff00ff background including all empty space, no cast shadows or floor. Each subject centered in its quadrant and fully visible, 65 percent cell occupancy, generous margins. Orthographic elevated 45 degree three-quarter camera, front faces RIGHT, compact top-down game view. TOP LEFT: armored wind-up tin beetle, four stubby articulated legs, oxidized teal domed shell reinforced with brass plates and a bottlecap frontal shield, single warm amber eye, exposed small glowing teal gear on back. TOP RIGHT: spring jack-in-the-box clown toy, chipped coral and cream wooden music box with four tiny feet, lid popped open, thick coiled steel spring neck and friendly-menacing wooden jester head, faded red cloth hat. BOTTOM LEFT: flying sewing-spool wasp toy, stout brass thread-spool body wrapped with mustard thread, two clear scratched cellophane wings, button eyes, small sewing needle stinger, wind-up mechanism, hover pose, no shadow. BOTTOM RIGHT: unique large boss toy junk bulldozer, chunky rusty mustard tracked chassis, broad scarred teal front shovel, two asymmetrical headlamp eyes, chimney exhaust pipe and wind-up key, bolted patchwork plating and small cloth pennant, powerful boss silhouette, no conventional real military vehicle. Exactly these four distinct toys, not variants of the same creature.''','2048x2048'),
 ('items',STYLE+'''Production icon sheet, EXACTLY 4 columns by 4 rows, sixteen equally sized isolated objects, each centered in its own square with 18 percent margin. Uniform solid MAGENTA #ff00ff backdrop, no labels, panels, cast shadows, floor, UI or lines. Clear detailed item icons, elevated three-quarter view, strong silhouettes. ROW 1 left to right: (1) red serrated bottle-cap saw with wooden clothespin handle; (2) brass winding key with two interlocking gears; (3) long reinforced wooden clothespin grip wrapped in canvas; (4) handmade Y-shaped slingshot with teal thread bands and one teal button ammunition. ROW 2: (5) heart-shaped cream canvas pincushion with ochre patch and visible stitches; (6) pair of tiny patched cloth boots with exposed steel coil spring soles; (7) red horseshoe magnet with silver tips and teal cloth wrap; (8) ornate upright teal glass battery vial with aged metal caps, glowing teal liquid, small lightning symbol embedded as an emblem. ROW 3: (9) real thick convex teal sewing button with FOUR visible holes, ivory thread, worn raised rim and glossy specular highlight, angled 25 degrees, recognizable 3D button ammunition; (10) cream cotton and rolled bandage tied with teal thread; (11) wooden spool tightly wrapped with teal sewing thread; (12) small cluster of individual brass screws, gear fragments, rusty metal flakes. ROW 4: (13) stout copper electrical coil with teal insulator, electrical pulse weapon; (14) improvised rotating spool turret with a small clothespin barrel, brass base and teal details; (15) one sharp rusty sewing pin with a coral round pearl head, enemy projectile; (16) a small amber glass energy capsule with brass cap and warm glowing core. Consistent highly tactile materials and polished distinct items. Keep every object strictly within its cell.''','2048x2048'),
 ('ui-materials',STYLE+'''A production UI material sheet with exactly FOUR elements in a precise 2 by 2 grid. Plain flat saturated magenta #ff00ff background and margins, no text, no icons, no lettering, no layout decorations beyond requested four objects. Straight-on flat camera, no perspective distortion. TOP LEFT: one large rectangular cream canvas upgrade card with rounded corners, stitched ochre leather border, thread stitches, lightly stained linen empty center, tiny brass rivets at four corners, clean legible pale interior. TOP RIGHT: one square equipment slot frame made of stitched tan canvas, chunky dark bronze inner rim, dark moss-grey EMPTY center, slightly worn edges. BOTTOM LEFT: one rectangular softly padded tan canvas HUD plaque, rounded corners, stitched seam, aged brass edge, empty dark faded brown woven fabric interior suitable for white text. BOTTOM RIGHT: one plush embroidered TEAL HEART life icon with tan canvas backing and brass stitched outline, rich stuffed cloth volume. Every element fully visible with 15 percent magenta margins, high quality textures but clean silhouettes.''','2048x2048'),
 ('props',STYLE+'''Production prop atlas, EXACT 4 columns by 2 rows, eight isolated different miniature scenery props on uniform flat MAGENTA #ff00ff, no ground shadows or text. Same elevated orthographic 45 degree camera as toy reference. Objects centered at 68 percent of each cell, fully visible with margins. Top row: (1) open cardboard toy salvage crate, folded torn flaps and a few small gears inside; (2) big wooden spool wrapped in dark teal thread, loose curved thread end; (3) upright makeshift battery lantern with warm amber glass bulb, cream cloth handle and tiny switch; (4) short stack of chipped red, teal and mustard wooden toy bricks. Bottom row: (5) a tangle of coiled copper wire and brass springs; (6) broken oval tin toy gear housing filled with loose gears; (7) a small cream patch of frayed fabric with a curved needle and teal thread; (8) a tiny patched canvas flag on a bent sewing-needle pole and bottle-cap stand, muted coral cloth pennant. Assets for a beautiful handmade toy wasteland. Do not generate characters.''','2560x1440'),
 ('arena',STYLE+'''Generate ONLY a beautiful empty overhead combat arena ground, closely matching the RIGHT gameplay panel of reference: an old warm greige TAN rug with faded muted red stitched circular play markings, rich fine fabric grain and worn patches, not the cool blue-grey rug. Landscape 16:9, orthographic overhead, no horizon. Middle 85 percent OPEN and unobstructed, low contrast floor details and very subtle weathered red ring, no hard geometric stars. At far frame edges ONLY: layered folded cardboard walls, dark warm torn cloth, worn mustard and teal and muted coral toy bricks, large wooden thread spool cropped at top right, tiny scraps and stitches. Premium tactile miniature art, gently warm lit, the beige ragdoll and teal pickups must separate from floor. No characters, enemies, weapons, HUD, UI, text or bright glowing items. Beautiful rich edges but restrained center. Match reference materials and palette, maintain readable battlefield.''','2560x1440')]

def video(name,prompt,ref=None,loop=False,death=False):
 job=S/f'{name}-video-job.json';record=S/f'{name}-video-request.json'
 if job.exists() or record.exists():return
 body={'regionId':'domestic','videoModel':'seedance-2.5','mode':'firstlast' if loop else ('first' if ref else 't2v'),'resolution':'480p','ratio':'adaptive' if ref else '1:1','duration':4,'n':1,'generateAudio':False,'watermark':False,'prompt':prompt,'requestId':'vid-scrapbound-v02-'+name.replace('_','-'),'source':'scrapbound-v02'}
 if ref:
  path=Path(ref)
  if death:
   original=Image.open(path).convert('RGB').resize((512,512))
   padded=Image.new('RGB',(768,768),(255,0,255));padded.paste(original,(128,222))
   path=S/(name+'-reference.png');padded.save(path)
  else:
   dest=S/(name+'-reference.png')
   if path!=dest:dest.write_bytes(path.read_bytes())
   path=dest
  body['firstFrame']=dataurl(path)
  if loop:body['lastFrame']=body['firstFrame']
 meta={k:v for k,v in body.items() if k not in ['firstFrame','lastFrame']}
 if ref:meta['reference_file']=path.name;meta['reference_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
 record.write_text(json.dumps(meta,ensure_ascii=False,indent=2))
 print('VIDEO',name,'submitted',flush=True)
 try:result=api('/api/video',body,90)
 except Exception as e:
  (S/(name+'-submit-error.txt')).write_text(str(e));print('REJECTED',name,str(e)[:300],flush=True);return
 job.write_text(json.dumps(result,ensure_ascii=False,indent=2));print(name,result.get('taskId'),flush=True)
FIX='Game animation asset. Exactly the single toy in the first frame, preserve identity, material, weapon and proportions. Camera fully locked, orthographic elevated three-quarter view. No pan, zoom, cuts, camera rotation, added text or extra characters. Uniform solid saturated MAGENTA #ff00ff background throughout; no floor or black shadow. Keep the whole action inside frame with generous margins. '
DEATH=FIX+'ONE toy defeat animation, not a loop. Hold reference pose for 0.25 second, then visibly react to an impact and break or fall as described. All parts remain visible within the frame. By 2.3 seconds all parts must settle completely and remain motionless through 4 seconds. Do not rebuild or regenerate the character, do not fade parts; fading will be added by the game. No smoke cloud hiding the motion. '
FX='Standalone game VFX sprite, perfect uniform BLACK background. Locked orthographic overhead camera, centered effect with wide safe margins, no environment, text, character or camera movement. One event, starts at .15 second, bursts by .6 second, dissipates fully by 2 seconds and remains black. '
def initial_videos():
 refs={k:R/'source'/f'{k}-video-reference-v1.png' for k in ['hero','rat','car','doll']}
 for k,desc in {
 'rat':'The wind-up tin mouse jolts, its domed body cracks open into 7 large identifiable tin plates, one winding key and four tiny wheel parts. The key flips once, the tail collapses, metal parts bounce twice and scatter in a compact radius around original feet.',
 'car':'The small toy car suffers a mechanical breakdown: chassis buckles, hood springs open, two wheels pop off and roll a short distance to either side, front bumper drops with a heavy bounce. The wreck settles at the original position.',
 'doll':'The jointed toy doll loses its strings, knees buckle, torso slumps sideways to the floor, one arm detaches and the button-eyed head rolls a short distance. A cloth ribbon flutters and settles. Keep the original recognizable head and jointed body as a collapsed wreck.',
 'hero':'The patched cloth ragdoll staggers, knees buckle and falls gently onto its side, bottle-cap saw drops beside it, a few fluffy cotton tufts escape a torn seam. The body remains intact and recognizable. Non-gory toy defeat.'}.items():video(k+'_death',DEATH+desc,refs[k],death=True)
 video('hero_idle',FIX+'Seamless in-place idle breathing loop. Tiny gentle stuffed chest breathing, a slight head tilt, scarf tips gently sway, small fingers readjust their grip on the saw. Feet never leave the same position. No walking, no turning. Start and end same pose.',refs['hero'],loop=True)
 video('hero_attack2',FIX+'ONE crisp powerful saw attack. Hold .25 seconds, wind saw to the left with a clear torso twist until .8 seconds, then make one strong horizontal sweep RIGHT between .8 and 1.3 seconds, follow through with cloth squash and scarf lag, then return to ready pose by 2 seconds and hold until end. Feet stay planted, always keep face and button eye visible. No full body spin, no turning back to camera, no extra saw, no changing hands. No glowing effects.',refs['hero'])
 for name,desc in {
 'impact_metal':'A crisp tiny warm white contact flash followed by a radial spray of golden sparks and a few tumbling recognizable rusty metal flecks, heavy mechanical hit feel, sharp core and short trails, no giant fireball.',
 'impact_cloth':'A soft burst of cream cotton fluff, tiny tan thread fibers and two button-sized cloth scraps, an ivory impact flash, fluffy particles quickly drift outward, non-gory textile hit.',
 'pickup_burst':'A tight elegant teal glowing spiral made of tiny luminous sewing stitches, rises slightly as a little battery pickup sparkle, a few ivory stars, compact and graceful rather than explosion.',
 'dash_trail':'A short horizontal teal and ivory swoosh from left to right with trailing luminous thread stitches and cloth motes, tapered ends, energetic but translucent. No large ring.'}.items():video(name,FX+desc)
def poll():
 for job in sorted(S.glob('*-video-job.json')):
  name=job.name.replace('-video-job.json','');target=S/(name+'.mp4')
  if target.exists():continue
  task=json.loads(job.read_text())['taskId']
  try:
   r=api('/api/video/'+task+'?regionId=domestic',timeout=45)
   (S/(name+'-video-status.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2))
   print(name,r.get('status'),str(r.get('error') or '')[:160],flush=True)
   if r.get('status')=='succeeded':download(r.get('videoUrl') or r['remoteVideoUrl'],target)
  except Exception as e:print(name,str(e)[:160],flush=True)
if __name__=='__main__':
 cmd=sys.argv[1]
 if cmd=='images':
  for args in IMAGES:gen_image(*args)
 elif cmd=='initial':initial_videos()
 elif cmd=='poll':poll()
