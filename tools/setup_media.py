from pathlib import Path
import urllib.request, numpy as np, wave
r=Path(__file__).resolve().parents[1]
for name,url in [
 ('NotoSansSC.ttf','https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf'),
 ('FONT-LICENSE.txt','https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt')]:
 p=r/'assets'/name
 if not p.exists():
  with urllib.request.urlopen(url,timeout=120) as f:p.write_bytes(f.read())
 print(name,p.stat().st_size,flush=True)
rng=np.random.default_rng(7);sr=22050
for name,duration in [('hit',.12),('saw',.2),('dash',.22),('pick',.09),('hurt',.25),('upgrade',.65),('end',1.1)]:
 t=np.arange(int(sr*duration))/sr;env=(1-t/duration)**2
 if name=='hit': x=(rng.uniform(-1,1,len(t))*.45+np.sin(2*np.pi*(140*t-160*t*t))*.5)*env
 elif name=='saw': x=(rng.uniform(-1,1,len(t))*.3+np.sin(2*np.pi*(650*t-700*t*t))*.2)*env
 elif name=='dash':x=rng.uniform(-1,1,len(t))*.45*np.sin(np.pi*t/duration)**2
 elif name=='pick':x=np.sin(2*np.pi*1100*t)*env*.27
 elif name=='hurt':x=(np.sin(2*np.pi*95*t)*.6+rng.uniform(-1,1,len(t))*.1)*env
 elif name=='upgrade':x=sum(np.sin(2*np.pi*f*t) for f in [523.25,659.25,783.99])*env*.16
 else:x=sum(np.sin(2*np.pi*f*t) for f in [196,233,293.66])*env*.15
 with wave.open(str(r/'assets'/f'{name}.wav'),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes((np.clip(x,-1,1)*26000).astype('<i2').tobytes())
print('Sound effects saved')
