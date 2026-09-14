from PIL import Image
from v02_assets import cut_save,S,R,A
from v02_pipeline import video,FIX,DEATH
cut_save(Image.open(S/'boss-redesign.png'),'boss2',True)
ref=S/'boss2-ref.png'
video('boss2_run',FIX+'A handmade wooden toy tractor rolls IN PLACE, four wooden wheels rotate, brass winding key turns, canvas roof and small cloth flag flutter subtly. Same position, orientation and scale, seamless continuous loop, no forward translation.',ref,loop=True)
video('boss2_death',DEATH+'The wooden toy salvage tractor breaks down: its front metal scoop drops, two wooden wheels come off and roll only a short distance, canvas roof collapses softly, wooden panels crack apart and brass key falls beside the wreck. Keep all wreckage close to the original position. Warm playful non-gory toy disassembly.',ref,death=True)
video('boss2_slam',FIX+'ONE mechanical toy action. Hold for .2 second; wooden toy tractor raises its front scoop until .7 second, then slams scoop down at 1 second, wooden wheels compress and rebound slightly. Return to original pose by 2 seconds. Keep toy facing right, feet fixed, no floor, no emitted effects.',ref)
# The first mouse death scattered its head to the frame edge. Wider stage keeps every part visible.
ref=Image.open(R/'source/rat-video-reference-v1.png').convert('RGB').resize((512,512))
padded=Image.new('RGB',(1024,1024),(255,0,255));padded.paste(ref,(256,444));path=S/'rat-death-wide-ref.png';padded.save(path)
video('rat_death2',DEATH+'COMPACT disassembly of the small wind-up tin mouse. Its metal dome splits into only four chunky pieces, small wheel parts and winding key drop beside it. Pieces make tiny low bounces and settle closely around original feet, within a circle only 1.5 times the original body width. Do not throw any piece far away. Every piece including head and tail must stay entirely inside the central 70 percent of the frame. By 1.8 seconds all pieces rest, hold until end.',path)
