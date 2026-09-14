from pathlib import Path
import wave,numpy as np
r=Path(__file__).resolve().parents[1]/'assets/v02';sr=32000;rng=np.random.default_rng(24)
for name,dur in [('metal_break',.42),('wood_break',.3),('cloth_break',.28),('button_fire',.15),('button_hit',.16),('heavy_hit',.28),('pulse_sound',.65)]:
 t=np.arange(int(sr*dur))/sr
 n=rng.uniform(-1,1,len(t));low=np.convolve(n,np.ones(8)/8,mode='same')
 if name=='metal_break':
  x=sum(np.sin(2*np.pi*f*t)*np.exp(-t*(8+i*4)) for i,f in enumerate([331,597,1181,1733]))*.16+n*np.exp(-t*29)*.35
  for at in [.09,.16,.24]:x+=np.where(t>at,np.sin(2*np.pi*1703*(t-at))*np.exp(-np.maximum(t-at,0)*75)*.22,0)
 elif name=='wood_break':x=low*np.exp(-t*18)*1.3+np.sin(2*np.pi*145*t)*np.exp(-t*28)*.4+n*np.exp(-t*95)*.4
 elif name=='cloth_break':x=low*np.exp(-t*14)*1.2+n*np.sin(np.pi*t/dur)**2*.16
 elif name=='button_fire':x=np.sin(2*np.pi*(900*t-1900*t*t))*np.exp(-t*33)*.55+n*np.exp(-t*65)*.2
 elif name=='button_hit':x=(np.sin(2*np.pi*1270*t)*.3+np.sin(2*np.pi*610*t)*.2+n*.25)*np.exp(-t*35)
 elif name=='heavy_hit':x=np.sin(2*np.pi*(105*t-110*t*t))*np.exp(-t*21)*.8+n*np.exp(-t*50)*.3
 else:x=(np.sin(2*np.pi*(290*t+300*t*t))*.35+np.sin(2*np.pi*579*t)*.15)*np.exp(-t*5)+low*np.exp(-t*12)*.2
 x*=np.minimum(1,t*1000)*np.clip((dur-t)*100,0,1)
 with wave.open(str(r/(name+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes((np.clip(x,-1,1)*26000).astype('<i2').tobytes())
print('Seven material-specific and weapon sounds saved.')
