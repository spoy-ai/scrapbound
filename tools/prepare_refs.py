from pathlib import Path
from PIL import Image
import numpy as np, shutil
ROOT=Path(__file__).resolve().parents[1]
def key_magenta(im):
 a=np.asarray(im.convert('RGB')).astype(np.float32)
 r,g,b=a[:,:,0],a[:,:,1],a[:,:,2]
 dominance=np.minimum(r,b)-g
 alpha=1-np.clip((dominance-25)/60,0,1)
 ratio=dominance/(np.maximum(r,b)+1)
 alpha=np.minimum(alpha,np.clip((0.55-ratio)/.15,0,1))
 # Suppress saturated magenta spill along antialiased silhouette boundaries.
 edge=(alpha>0)&(alpha<1)
 clean=a.copy()
 neutral=(r+b)/2
 clean[:,:,0]=np.where(edge,np.minimum(r,g+35),r)
 clean[:,:,2]=np.where(edge,np.minimum(b,g+35),b)
 rgba=np.dstack([clean,np.round(alpha*255)]).astype(np.uint8)
 return Image.fromarray(rgba)
if __name__=='__main__':
 sheet=Image.open(ROOT/'source/characters.png')
 s=sheet.width//2
 for name,(x,y) in zip(['hero','rat','car','doll'],[(0,0),(1,0),(0,1),(1,1)]):
  cut=key_magenta(sheet.crop((x*s,y*s,(x+1)*s,(y+1)*s)))
  box=cut.getbbox();cut=cut.crop(box)
  limit=360
  cut.thumbnail((390,limit),Image.Resampling.LANCZOS)
  canvas=Image.new('RGBA',(512,512))
  canvas.alpha_composite(cut,((512-cut.width)//2,444-cut.height))
  canvas.save(ROOT/'assets'/f'{name}.png')
  matte=Image.new('RGB',(512,512),(255,0,255));matte.paste(canvas,mask=canvas.getchannel('A'))
  matte.save(ROOT/'source'/f'{name}-ref.png')
 shutil.copy2(ROOT/'source/arena.png',ROOT/'assets/arena.png')
 print('Four isolated references and game sprites prepared')
