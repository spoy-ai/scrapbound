from pathlib import Path
from PIL import Image,ImageDraw
import subprocess,json
ROOT=Path(__file__).resolve().parents[1]
for video in sorted((ROOT/'source').glob('*.mp4')):
 name=video.stem
 out=ROOT/'source'/(name+'-frames');out.mkdir(exist_ok=True)
 subprocess.run(['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-i',str(video),'-vf','fps=24','-y',str(out/'%03d.png')],check=True)
 frames=sorted(out.glob('*.png'))
 board=Image.new('RGB',(640,680),(20,30,31));draw=ImageDraw.Draw(board)
 for i,f in enumerate(frames[::6][:16]):
  im=Image.open(f).convert('RGB');im.thumbnail((160,150))
  x=(i%4)*160;y=(i//4)*170
  board.paste(im,(x,y+20));draw.text((x+5,y+3),f'{name} {i*.25:.2f}s',fill='white')
 board.save(ROOT/'captures'/f'{name}-contact.jpg')
 print(name,len(frames),Image.open(frames[0]).size,flush=True)
