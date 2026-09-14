from pathlib import Path
from PIL import Image,ImageFilter,ImageDraw
import numpy as np,json,sys,math,subprocess
from prepare_refs import key_magenta

R=Path(__file__).resolve().parents[1];S=R/'source/v02';A=R/'assets/v02';C=R/'captures/v02'

def matte(im,fragments=False):
 out=key_magenta(im)
 alpha=out.getchannel('A')
 hard=alpha.point(lambda v:255 if v>110 else 0).filter(ImageFilter.MedianFilter(3))
 support=hard.filter(ImageFilter.MaxFilter(3))
 a=np.asarray(alpha).copy();a[np.asarray(support)==0]=0;a[a<70]=0
 out.putalpha(Image.fromarray(a));return out

def cut_save(im,name,actor=False):
 im=matte(im);box=im.getbbox()
 if box is None:raise RuntimeError('Empty '+name)
 im=im.crop(box)
 # Trimmed texture for item/UI use, fixed-foot padded texture for characters.
 if actor:
  im.thumbnail((386,356),Image.Resampling.LANCZOS)
  out=Image.new('RGBA',(512,512));out.alpha_composite(im,((512-im.width)//2,444-im.height))
 else:
  im.thumbnail((768,768),Image.Resampling.LANCZOS);out=im
 out.save(A/(name+'.png'))
 if actor:ref=out
 else:
  ref=Image.new('RGBA',(512,512));cut=out.copy();cut.thumbnail((340,340),Image.Resampling.LANCZOS);ref.alpha_composite(cut,((512-cut.width)//2,(512-cut.height)//2))
 bg=Image.new('RGB',ref.size,(255,0,255));bg.paste(ref,mask=ref.getchannel('A'));bg.save(S/(name+'-ref.png'))

def prepare():
 im=Image.open(S/'new-enemies.png');s=im.width//2
 for i,n in enumerate(['beetle','jack','wasp','boss']):cut_save(im.crop(((i%2)*s,(i//2)*s,(i%2+1)*s,(i//2+1)*s)),n,True)
 names=['damage','speed','range','bolt','health','dash','magnet','battery','button','medkit','thread','scrap','pulse','turret','needle','amber']
 im=Image.open(S/'items.png');s=im.width//4
 for i,n in enumerate(names):cut_save(im.crop(((i%4)*s,(i//4)*s,(i%4+1)*s,(i//4+1)*s)),n)
 im=Image.open(S/'ui-materials.png')
 for n,box in [('card',(0,0,1024,1240)),('slot',(1024,0,2048,1140)),('plaque',(0,1250,1024,2048)),('heart',(1024,1140,2048,2048))]:cut_save(im.crop(box),n)
 im=Image.open(S/'props.png');w,h=im.width//4,im.height//2
 for i,n in enumerate(['crate','spool','lantern','bricks','wire','gears','fabric','flag']):cut_save(im.crop(((i%4)*w,(i//4)*h,(i%4+1)*w,(i//4+1)*h)),'prop_'+n)
 if (S/'arena.png').exists():(A/'arena.png').write_bytes((S/'arena.png').read_bytes())
 # Real material pieces for secondary flying debris; preserve multiple fragments.
 for i,(name,box) in enumerate([('shard_metal',(130,80,360,290)),('shard_wood',(75,85,260,275)),('shard_cloth',(160,110,350,315))]):
  source=Image.open(A/({'shard_metal':'scrap','shard_wood':'prop_crate','shard_cloth':'medkit'}[name]+'.png')).convert('RGBA')
  w,h=source.size;patch=source.crop((int(w*.28),int(h*.22),int(w*.67),int(h*.61)))
  mask=Image.new('L',patch.size);d=ImageDraw.Draw(mask);pw,ph=patch.size
  d.polygon([(0,ph*.3),(pw*.45,0),(pw,ph*.2),(pw*.76,ph),(pw*.12,ph*.85)],fill=255)
  aa=np.minimum(np.asarray(patch.getchannel('A')),np.asarray(mask));patch.putalpha(Image.fromarray(aa));patch.thumbnail((96,96));patch.save(A/(name+'.png'))
 print('Prepared 35 art assets and video references',flush=True)

def inspect():
 for p in sorted(S.glob('*.mp4')):
  out=S/(p.stem+'-frames');out.mkdir(exist_ok=True)
  if not (out/'001.png').exists():subprocess.run(['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-i',str(p),'-vf','fps=24','-y',str(out/'%03d.png')],check=True)
  fs=sorted(out.glob('*.png'))
  board=Image.new('RGB',(640,680),(22,29,28));draw=ImageDraw.Draw(board)
  for i,f in enumerate(fs[::6][:16]):
   im=Image.open(f).convert('RGB');im.thumbnail((160,150));x=i%4*160;y=i//4*170
   board.paste(im,(x,y+20));draw.text((x+5,y+2),f'{p.stem} {i*.25:.2f}s',fill='white')
  board.save(C/(p.stem+'-contact.jpg'))
  print(p.stem,len(fs),flush=True)

def black(im):
 rgb=np.asarray(im.convert('RGB')).astype(float);lum=rgb.max(2)
 alpha=np.clip((lum-14)/205,0,1)
 rgb=np.clip(rgb/np.maximum(alpha[:,:,None],.01),0,255)
 rgba=np.dstack([rgb,alpha*255]).astype(np.uint8)
 h,w=lum.shape;y,x=np.mgrid[:h,:w];edge=np.minimum.reduce([x,y,w-1-x,h-1-y])
 rgba[:,:,3]=(rgba[:,:,3]*np.clip(edge/20,0,1)).astype(np.uint8)
 return Image.fromarray(rgba)

def build():
 effects={'impact_metal','impact_cloth','pickup_burst','dash_trail','pulse_ring'}
 meta=json.loads((A/'animations.json').read_text()) if (A/'animations.json').exists() else {}
 for job in sorted(S.glob('*-video-job.json')):
  name=job.name.replace('-video-job.json','')
  if name in {'boss_death','rat_death','beetle_death','crate_break'}:continue
  if name in meta and (A/(name+'-atlas.png')).exists():continue
  fs=sorted((S/(name+'-frames')).glob('*.png'))
  if not fs:continue
  isdeath='_death' in name or name.startswith('crate_break');isfx=name in effects
  start,end=(0,80) if isdeath else ((5,52) if isfx else ((6,52) if name=='hero_attack2' else (0,96)))
  cell=192 if isdeath or isfx else 256
  if name=='hero_idle':cell=512
  elif name in ['beetle_run','jack_run','wasp_run','boss2_run']:cell=384
  if name in ['battery_loop','medkit_loop','button_spin']:cell=128
  clips={'car_death':(29,89),'doll_death':(20,86),'jack_death':(29,89),'wasp_death':(26,89),'hero_death':(21,89),'boss2_death':(16,89),'rat_death2':(35,90),'beetle_death2':(14,88),'crate_break':(20,90),'crate_break2':(54,93),'impact_metal':(4,88),'impact_cloth':(4,96),'pickup_burst':(6,95),'dash_trail':(24,96),'pulse_ring':(10,91)}
  start,end=clips.get(name,(start,end))
  selected=fs[start:end]
  if name=='hero_attack2':selected=fs[19:30]+fs[50:81];start,end=19,81
  if name=='boss2_slam':selected=fs[16:36]+fs[64:82];start,end=16,82
  frames=[]
  for f in selected:
   im=black(Image.open(f)) if isfx else matte(Image.open(f),isdeath)
   if name=='wasp_run':
    small=np.asarray(im.getchannel('A').resize((160,160)))>100
    visited=np.zeros((160,160),bool);clean=np.zeros((160,160),np.uint8)
    for yy,xx in zip(*np.where(small)):
     if visited[yy,xx]:continue
     queue=[(yy,xx)];visited[yy,xx]=True;part=[]
     while queue:
      y,x=queue.pop();part.append((y,x))
      for ny,nx in [(y-1,x),(y+1,x),(y,x-1),(y,x+1)]:
       if 0<=ny<160 and 0<=nx<160 and small[ny,nx] and not visited[ny,nx]:visited[ny,nx]=True;queue.append((ny,nx))
     if len(part)>125:
      for y,x in part:clean[y,x]=255
    support=Image.fromarray(clean).resize(im.size).filter(ImageFilter.MaxFilter(7))
    ar=np.asarray(im).copy();ar[:,:,3][np.asarray(support)<50]=0;im=Image.fromarray(ar)
   frames.append(im.resize((cell,cell),Image.Resampling.LANCZOS))
  count=len(frames);cols=12
  atlas=Image.new('RGBA',(cols*cell,math.ceil(count/cols)*cell))
  for i,im in enumerate(frames):atlas.paste(im,(i%cols*cell,i//cols*cell))
  atlas.save(A/(name+'-atlas.png'),optimize=True)
  meta[name]={'file':'v02/'+name+'-atlas.png','frames':count,'fps':24,'cell':cell,'cols':cols,'source_fps':24,'source_clip':[start/24,end/24],'source_segments':[[19/24,30/24],[50/24,81/24]] if name=='hero_attack2' else ([[16/24,36/24],[64/24,82/24]] if name=='boss2_slam' else [[start/24,end/24]]),'loop':name.endswith('_run') or name.endswith('_loop') or name in ['hero_idle','button_spin'],'source_task':json.loads(job.read_text())['taskId'],'model':'seedance-2.5','resolution':'480p'}
  previews=[]
  for im in frames[::2]:
   bg=Image.new('RGBA',im.size,(114,101,79,255));bg.alpha_composite(im);previews.append(bg.convert('RGB'))
  previews[0].save(C/(name+'-preview.gif'),save_all=True,append_images=previews[1:],duration=84,loop=0)
  print('BUILT',name,count,flush=True)
 (A/'animations.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
 if meta:
  m=json.loads((R/'assets/animations.json').read_text());m.update(meta);(R/'assets/animations.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
if __name__=='__main__':{'prepare':prepare,'inspect':inspect,'build':build}[sys.argv[1]]()
