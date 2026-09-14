from pathlib import Path
from PIL import Image,ImageFilter,ImageDraw
import numpy as np,json,math
from collections import deque
from prepare_refs import key_magenta
ROOT=Path(__file__).resolve().parents[1]

def clean_key(im):
 im=key_magenta(im)
 a=im.getchannel('A')
 solid=a.point(lambda x:255 if x>155 else 0).filter(ImageFilter.MedianFilter(3))
 # Keep the main connected silhouette at reduced resolution; remove isolated key noise.
 small=np.asarray(solid.resize((120,120),Image.Resampling.NEAREST))>0
 seen=np.zeros_like(small);largest=[]
 for yy,xx in zip(*np.where(small)):
  if seen[yy,xx]:continue
  q=deque([(yy,xx)]);seen[yy,xx]=1;component=[]
  while q:
   y,x=q.popleft();component.append((y,x))
   for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
    ny,nx=y+dy,x+dx
    if 0<=ny<120 and 0<=nx<120 and small[ny,nx] and not seen[ny,nx]:
     seen[ny,nx]=1;q.append((ny,nx))
  if len(component)>len(largest):largest=component
 keep=np.zeros((120,120),np.uint8)
 for y,x in largest:keep[y,x]=255
 keep=Image.fromarray(keep).resize(im.size,Image.Resampling.NEAREST).filter(ImageFilter.MaxFilter(7))
 aa=np.asarray(a).copy();aa[np.asarray(keep)==0]=0;aa[aa<45]=0
 im.putalpha(Image.fromarray(aa))
 return im

def black_key(im):
 a=np.asarray(im.convert('RGB')).astype(np.float32)
 maximum=a.max(axis=2)
 alpha=np.clip((maximum-12)/200,0,1)
 # Unpremultiply so source's glow is preserved over arbitrary floor colours.
 rgb=np.clip(a/np.maximum(alpha[:,:,None],.01),0,255)
 out=np.dstack([rgb,alpha*255]).astype(np.uint8)
 # The effect dies to transparent before reaching cell boundary.
 h,w=alpha.shape;y,x=np.mgrid[:h,:w]
 edge=np.minimum.reduce([x,y,w-1-x,h-1-y])
 out[:,:,3]=(out[:,:,3]*np.clip(edge/18,0,1)).astype(np.uint8)
 return Image.fromarray(out)

meta={}
for name in ['hero_run','hero_attack','rat_run','car_run','doll_run','slash']:
 files=sorted((ROOT/'source'/(name+'-frames')).glob('*.png'))
 if not files:continue
 if name=='hero_attack':start,end=17,74
 elif name=='slash':start,end=3,64
 else:start,end=0,96
 selected=files[start:end]
 frames=[]
 for f in selected:
  im=Image.open(f)
  im=black_key(im) if name=='slash' else clean_key(im)
  frames.append(im.resize((256,256),Image.Resampling.LANCZOS))
 # Blend the last few loop frames into the opening pose; no synthetic extra FPS.
 if name.endswith('_run'):
  for k in range(3):
   weight=(k+1)/4
   frames[-3+k]=Image.blend(frames[-3+k],frames[0],weight)
 cols=12;rows=math.ceil(len(frames)/cols)
 atlas=Image.new('RGBA',(cols*256,rows*256))
 for i,im in enumerate(frames):atlas.paste(im,((i%cols)*256,(i//cols)*256))
 atlas.save(ROOT/'assets'/f'{name}-atlas.png',optimize=True)
 meta[name]={'file':f'{name}-atlas.png','frames':len(frames),'fps':24,'cell':256,'cols':cols,'source_fps':24,'source_clip':[start/24,end/24],'foot_anchor':[128,222],'loop':name.endswith('_run'),'source_task':json.loads((ROOT/'source'/f'{name}-video-job.json').read_text())['taskId']}
 # Small animation previews over a neutral ground are kept for visual QA.
 preview=[]
 for frame in frames:
  bg=Image.new('RGBA',(256,256),(64,80,75,255));bg.alpha_composite(frame)
  preview.append(bg.convert('RGB'))
 preview[0].save(ROOT/'captures'/f'{name}-preview.gif',save_all=True,append_images=preview[1:],duration=42,loop=0)
 print(name,len(frames),'atlas saved',flush=True)
(ROOT/'assets/animations.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
# High-resolution stills use the same key cleanup, canvas, and anchor as motion.
sheet=Image.open(ROOT/'source/characters.png');s=sheet.width//2
for name,(x,y) in zip(['hero','rat','car','doll'],[(0,0),(1,0),(0,1),(1,1)]):
 cut=clean_key(sheet.crop((x*s,y*s,(x+1)*s,(y+1)*s)))
 box=cut.getbbox();cut=cut.crop(box);cut.thumbnail((390,360),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(512,512));canvas.alpha_composite(cut,((512-cut.width)//2,444-cut.height))
 canvas.save(ROOT/'assets'/f'{name}.png')
print('All animation metadata and stills saved')
