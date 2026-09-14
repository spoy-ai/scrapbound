"""Offline chroma cleanup, fixed anchors, atlases and visual QA boards."""
from pathlib import Path
import json, math, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw
from v02_assets import matte as previous_matte

R = Path(__file__).resolve().parents[1]
S = R/'source/v03'
A = R/'assets/v03/art'

def matte(im):
    out = previous_matte(im)
    rgb = np.asarray(im.convert('RGB')).astype(float)
    r,g,b = rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
    # Dark cast-shadow magenta is less saturated in absolute RGB yet still backdrop.
    bg = (r > g*1.4+9) & (b > g*1.35+9)
    a = np.asarray(out).copy()
    a[:,:,3][bg] = 0
    return Image.fromarray(a)

def save_asset(im, name, prop=False):
    out = matte(im)
    bbox = out.getbbox()
    if bbox is None:
        raise RuntimeError('Empty alpha '+name)
    out = out.crop(bbox)
    out.thumbnail((768,768), Image.Resampling.LANCZOS)
    out.save(A/(name+'.png'))
    if prop:
        reference = Image.new('RGBA',(512,512))
        cut = out.copy()
        cut.thumbnail((350,340), Image.Resampling.LANCZOS)
        reference.alpha_composite(cut,((512-cut.width)//2,420-cut.height))
        rgb=Image.new('RGB',reference.size,(255,0,255))
        rgb.paste(reference,mask=reference.getchannel('A'))
        rgb.save(S/(name+'-ref.png'))

def prepare():
    A.mkdir(parents=True,exist_ok=True)
    for name in ['musicbox','recycler']:
        if (S/(name+'.png')).exists():
            save_asset(Image.open(S/(name+'.png')),name,True)
    if (S/'build-icons.png').exists():
        im=Image.open(S/'build-icons.png');w,h=im.width//2,im.height//2
        for i,name in enumerate(['route_saw','route_thread','route_coil','overdrive']):
            save_asset(im.crop((i%2*w,i//2*h,(i%2+1)*w,(i//2+1)*h)),name)
    names=['musicbox','recycler','route_saw','route_thread','route_coil','overdrive']
    board=Image.new('RGB',(1200,820),(83,74,59));d=ImageDraw.Draw(board)
    for i,name in enumerate(names):
        p=A/(name+'.png')
        if not p.exists():continue
        im=Image.open(p);im.thumbnail((350,335),Image.Resampling.LANCZOS)
        x=i%3*400;y=i//3*410
        board.paste(im,(x+(400-im.width)//2,y+40+(350-im.height)//2),im)
        d.text((x+20,y+15),name,fill=(241,218,176))
    board.save(S/'art-review.jpg',quality=94)
    print('Prepared',sum((A/(name+'.png')).exists() for name in names),'art assets',flush=True)

def inspect():
    for p in S.glob('*_loop.mp4'):
        directory=S/(p.stem+'-frames');directory.mkdir(exist_ok=True)
        if not (directory/'001.png').exists():
            subprocess.run(['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-i',str(p),'-vf','fps=24','-y',str(directory/'%03d.png')],check=True)
        fs=sorted(directory.glob('*.png'))
        board=Image.new('RGB',(960,1040),(83,74,59));d=ImageDraw.Draw(board)
        for i,f in enumerate(fs[::6][:16]):
            im=matte(Image.open(f));im.thumbnail((240,240),Image.Resampling.LANCZOS)
            x=i%4*240;y=i//4*260
            board.paste(im,(x,y+20),im)
            d.text((x+8,y+2),f'{p.stem} {i*.25:.2f}s',fill='white')
        board.save(S/(p.stem+'-contact.jpg'),quality=93)
        print(p.stem,len(fs),flush=True)

def build():
    meta={}
    report={}
    for name in ['musicbox_loop','recycler_loop']:
        fs=sorted((S/(name+'-frames')).glob('*.png'))[:96]
        if not fs:continue
        cell=384;cols=12;frames=[];bounds=[]
        for f in fs:
            im=matte(Image.open(f)).resize((cell,cell),Image.Resampling.LANCZOS)
            frames.append(im);bounds.append(im.getbbox())
        atlas=Image.new('RGBA',(cols*cell,math.ceil(len(frames)/cols)*cell))
        for i,im in enumerate(frames):atlas.paste(im,(i%cols*cell,i//cols*cell))
        atlas.save(A/(name+'-atlas.png'),optimize=True)
        job=json.loads((S/(name+'-video-job.json')).read_text())
        meta[name]={'file':'res://assets/v03/art/'+name+'-atlas.png','frames':len(frames),'fps':24,'cell':cell,'cols':cols,'loop':True,'pivot':[.5,420/512],'source_fps':24,'source_size':list(Image.open(fs[0]).size),'source_clip':[0,len(frames)/24],'model':'seedance-2.5','resolution':'480p','source_task':job['taskId']}
        first=np.asarray(frames[0]).astype(float);last=np.asarray(frames[-1]).astype(float)
        occupied=(first[:,:,3]>40)|(last[:,:,3]>40)
        report[name]={'frames':len(frames),'bounding_box_union':[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)],'first_last_mean_abs_RGBA':round(float(np.abs(first-last)[occupied].mean()),3),'all_frames_nonempty':all(b is not None for b in bounds),'no_frame_touches_border':all(b[0]>0 and b[1]>0 and b[2]<cell and b[3]<cell for b in bounds)}
        preview=[]
        for im in frames[::2]:
            bg=Image.new('RGBA',im.size,(83,74,59,255));bg.alpha_composite(im);preview.append(bg.convert('RGB'))
        preview[0].save(S/(name+'-preview.gif'),save_all=True,append_images=preview[1:],duration=84,loop=0)
        print('BUILT',name,len(frames),flush=True)
    (A/'animations.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
    (S/'art-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))

if __name__=='__main__':
    {'prepare':prepare,'inspect':inspect,'build':build}[sys.argv[1]]()
