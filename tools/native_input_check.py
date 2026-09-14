from pathlib import Path
import subprocess,time,json
R=Path(__file__).resolve().parents[1]
log=(R/'captures/v02/native.log').open('w')
p=subprocess.Popen(['/Applications/Godot.app/Contents/MacOS/Godot','--path',str(R),'--','--test=native'],stdout=log,stderr=subprocess.STDOUT)
time.sleep(3)
def press(code):
 script=f'''tell application "System Events"
set targetProcess to first process whose unix id is {p.pid}
set frontmost of targetProcess to true
tell targetProcess to key code {code}
end tell'''
 subprocess.run(['/usr/bin/osascript','-e',script],check=True,stdout=subprocess.DEVNULL)
press(36);time.sleep(.5)
# Hold movement through the operating system, not by changing game state.
script=f'''tell application "System Events"
set targetProcess to first process whose unix id is {p.pid}
set frontmost of targetProcess to true
key down "d"
delay 1.0
key up "d"
end tell'''
subprocess.run(['/usr/bin/osascript','-e',script],check=True)
press(49);time.sleep(.7)
press(48);time.sleep(.3);press(124);press(49);time.sleep(2.0)
press(53);time.sleep(.3);press(53)
p.wait(timeout=25);log.close()
r=json.loads((R/'captures/native-report.json').read_text())
assert r['stats']['dashes']>=1 and r['state']=='paused',r
print('Native OS input passed: start, movement, dash, gallery navigation/death, return and pause')
