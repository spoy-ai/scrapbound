from pathlib import Path
import urllib.request,urllib.error,json,base64,time
ROOT=Path(__file__).resolve().parents[1];BASE='http://127.0.0.1:3000'
def call(path,data=None,timeout=90):
 req=urllib.request.Request(BASE+path,data=json.dumps(data).encode() if data else None,headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=timeout) as f:return json.load(f)
common='Game animation asset. Exactly the single character from first frame, identity, materials and equipment unchanged. Orthographic elevated three-quarter view, always faces RIGHT. Camera entirely static with no zoom, pan, cuts or rotation. The character stays centered and moves IN PLACE on a treadmill, feet anchored near the same baseline. Absolutely uniform bright magenta #ff00ff background, no floor, no cast shadow, no text. Preserve same size throughout, leave generous margin, no parts clipped. Natural articulated motion, no sliding cutout. '
jobs=[
 ('hero_run','hero',common+'Animate a seamless jogging cycle in place: stubby cloth legs alternately lift and plant, knees bend, arms pump gently while firmly holding the bottle-cap saw, soft stuffed body has subtle squash and bounce, scarf and battery backpack lag behind. Four seconds of steady continuous repeated jogging; first and last pose match. Keep face, button eyes and single saw unchanged.','firstlast'),
 ('hero_attack','hero',common+'Animate ONE clear bottle-cap saw attack over four seconds. 0 to 0.7 second holds ready pose; 0.7 to 1.3 twists body and winds saw back; 1.3 to 1.8 sweeps saw forcefully in a wide horizontal arc to the right with both arms, cloth body twists naturally; 1.8 to 2.4 follows through and recovers; 2.4 to 4 holds original ready pose. Keep both feet in place, no walking. No glowing effects, no added objects or weapon transformation. Return to first pose.','firstlast'),
 ('rat_run','rat',common+'Loop this wind-up tin mouse scurrying in place with fast alternating tiny wheel-leg movement, a gentle metal body bob and brass winding key rotating mechanically. Thin tail sways. Not running away from camera. Four seconds continuous steady motion, no transformation. First and last pose match.','firstlast'),
 ('car_run','car',common+'Loop this rusty mustard toy car driving in place: four wheels rotate quickly, suspension bounces and tilts subtly, winding key rotates. Car body stays in the same place and same orientation. No forward displacement, no smoke, no dust, no particles. Four seconds steady motion, first and last pose match.','firstlast'),
 ('doll_run','doll',common+'Loop this mismatched violet toy doll walking briskly in place. Two long articulated jointed legs take alternating awkward high steps, two arms counter swing, rounded head bobs slightly. Creepy playful toy motion, no new limbs, no distortion. Four seconds continuous walk, same start and end pose.','firstlast'),
 ('slash',None,'VFX sprite asset for an overhead toy-wasteland action game. Pure uniform BLACK background, no character, no text, no environment, locked orthographic overhead camera. One isolated warm ivory and gold crescent saw slash centered with large margins. A single effect appears at 0.5 seconds, rapidly sweeps clockwise through a 160 degree arc around an empty center, sparks trail behind, reaches bright impact at 1.2 seconds, quickly dissipates by 2 seconds, black remaining time. Elegant crisp thick crescent with fine golden metal sparks, visible empty center. No full circular portal, no explosion cloud, no camera movement, no edge cropping.','t2v')]
for name,ref,prompt,mode in jobs:
 p=ROOT/'source'/f'{name}-video-job.json'
 if p.exists():continue
 body={'regionId':'domestic','videoModel':'seedance-2.0','mode':mode,'resolution':'480p','ratio':'1:1','duration':4,'n':1,'generateAudio':False,'watermark':False,'prompt':prompt,'requestId':'vid-scrapbound-'+name.replace('_','-')+'-v1','source':'scrapbound-game'}
 if ref:
  u='data:image/png;base64,'+base64.b64encode((ROOT/'source'/f'{ref}-ref.png').read_bytes()).decode()
  body['firstFrame']=u
  body['lastFrame']=u
 (ROOT/'source'/f'{name}-video-prompt.txt').write_text(prompt)
 meta={k:v for k,v in body.items() if k not in ['firstFrame','lastFrame']}
 (ROOT/'source'/f'{name}-video-request.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
 print('Submitting',name,flush=True)
 try:r=call('/api/video',body)
 except Exception as e:
  print('Submission uncertain; inspect history for '+body['requestId']+' before any retry. '+str(e),flush=True);raise
 p.write_text(json.dumps(r,ensure_ascii=False,indent=2))
 print(name,r.get('taskId'),flush=True)
