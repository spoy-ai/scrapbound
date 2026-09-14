from pathlib import Path
import urllib.request,json
ROOT=Path(__file__).resolve().parents[1];BASE='http://127.0.0.1:3000'
for job in sorted((ROOT/'source').glob('*-video-job.json')):
 name=job.name.replace('-video-job.json','')
 target=ROOT/'source'/f'{name}.mp4'
 if target.exists(): print(name,'downloaded');continue
 task=json.loads(job.read_text())['taskId']
 try:
  with urllib.request.urlopen(BASE+'/api/video/'+task+'?regionId=domestic',timeout=35) as f:r=json.load(f)
  (ROOT/'source'/f'{name}-video-status.json').write_text(json.dumps(r,ensure_ascii=False,indent=2))
  print(name,task,r.get('status'),str(r.get('error') or '')[:250],flush=True)
  if r.get('status')=='succeeded':
   url=r.get('videoUrl') or r.get('remoteVideoUrl')
   if url:
    with urllib.request.urlopen(BASE+url if url.startswith('/') else url,timeout=90) as f:target.write_bytes(f.read())
    print('Saved',name,target.stat().st_size,flush=True)
 except Exception as e:print(name,type(e).__name__,str(e)[:150],flush=True)
