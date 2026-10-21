"""0.2.0 acceptance on Android: native measurement sizes (no JS round trip), group/pill/morph
geometry, presence exit, header stack push/pop with slot morph, controls shared by two screens
staying still (screen recording of the back button's bounds, compared numerically; no PNGs)."""
import runpy, shutil, subprocess, time
from pathlib import Path
h = runpy.run_path(str(Path(__file__).with_name('verify-android-menu.py')))
adb, tree, find, bounds = (h[k] for k in ('adb', 'tree', 'find', 'bounds'))
ffmpeg, ffprobe = [shutil.which(n) or '/opt/homebrew/bin/' + n for n in ('ffmpeg', 'ffprobe')]
artifacts = Path(__file__).resolve().parent.parent / 'artifacts'

def recorded_change(name, box, action, seconds=4):
  """Largest mean grey change (0-255) inside `box` (screen px) while `action` runs, against the
  first recorded frame."""
  adb('shell', 'rm', '-f', f'/sdcard/{name}.mp4')
  rec = subprocess.Popen([h['ADB'], '-s', h['SERIAL'], 'shell', 'screenrecord', '--time-limit', str(seconds), f'/sdcard/{name}.mp4'])
  time.sleep(1.0); action(); rec.wait(timeout=seconds + 10); time.sleep(.5)
  video = artifacts / f'{name}.mp4'; artifacts.mkdir(exist_ok=True); adb('pull', f'/sdcard/{name}.mp4', video)
  vw, vh = map(int, subprocess.check_output([ffprobe, '-v', 'error', '-select_streams', 'v', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', str(video)], text=True).strip().split(','))
  sw, sh = map(int, adb('shell', 'wm', 'size').decode().split()[-1].split('x'))
  k = min(vw / sw, vh / sh); ox, oy = (vw - sw * k) / 2, (vh - sh * k) / 2  # screenrecord may letterbox
  x1, y1, x2, y2 = box; x, y, w, hh = [int(v) // 2 * 2 for v in (x1 * k + ox, y1 * k + oy, (x2 - x1) * k, (y2 - y1) * k)]
  raw = subprocess.check_output([ffmpeg, '-v', 'error', '-i', str(video), '-vf', f'crop={w}:{hh}:{x}:{y},format=gray', '-fps_mode', 'passthrough', '-f', 'rawvideo', '-'])
  frames = [raw[i:i + w * hh] for i in range(0, len(raw) - w * hh + 1, w * hh)]
  assert len(frames) > 5, f'{name}: only {len(frames)} frames recorded'
  return max(sum(abs(p - q) for p, q in zip(f, frames[0])) / len(f) for f in frames)
# `wm density` prints the physical and, if set, override density; the last value is in effect.
density = float(adb('shell', 'wm', 'density').decode().split()[-1]) / 160

def tap(value):
  try: node = find(tree(), value)
  except AssertionError: node = h['reveal'](value)
  x1, y1, x2, y2 = bounds(node); adb('shell', 'input', 'tap', (x1 + x2) // 2, (y1 + y2) // 2); time.sleep(.6)

def absent(root, value):
  try: find(root, value)
  except AssertionError: return True
  return False

def size(value):
  try: node = find(tree(), value)
  except AssertionError: node = h['reveal'](value)
  x1, y1, x2, y2 = bounds(node); return (x2 - x1) / density, (y2 - y1) / density

tap('open-acceptance-demo')
for name, side in [('mini', 28), ('small', 36), ('regular', 44), ('large', 50), ('extraLarge', 56)]:
  w, hgt = size(f'acc-size-{name}')
  assert abs(w - side) <= 1 and abs(hgt - side) <= 1, f'controlSize {name}: {w:.1f}x{hgt:.1f}'
# Natively measured: a 3-item group is wider than one 44 dp item (no 44x44 placeholder).
gw, gh = size('acc-group3'); assert gw > 3 * 44 and abs(gh - 44) <= 1, f'group {gw:.1f}x{gh:.1f}'
mw, mh = size('acc-morph'); assert abs(mw - 44) <= 1, f'morph start {mw:.1f}'
tap('acc-morph-trigger'); time.sleep(.8)
mw2, _ = size('acc-morph'); assert mw2 > 60, f'morph to Select did not resize natively: {mw2:.1f}'
tap('acc-morph-trigger'); time.sleep(.8)
assert abs(size('acc-morph')[0] - 44) <= 1, 'morph back to the disc'
# Presence: exits once.
tap('acc-presence-toggle'); time.sleep(.8)
assert 'Exits: 1' in find(tree(), 'acc-exits').get('text', ''), 'presence exit reported once'
tap('acc-presence-toggle'); time.sleep(.8)
# Header stack: Home ⋯, push All (back + Select), pop back.
tap('acc-open-stack'); time.sleep(1.2)
assert find(tree(), 'acc-header-primary') is not None
tap('acc-row-All'); time.sleep(1.4)
pw, _ = size('acc-header-primary'); assert pw > 60, f'header primary should be the Select capsule: {pw:.1f}'
find(tree(), 'acc-header-back')
# Controls on both screens keep their capsule: All (back, Select, Share) → Item (back, Edit,
# Share, slots named differently). The back button must not change while Item is pushed and
# popped with the system Back key (which does not touch it). Positive control: Home → All, where
# the back button appears in the same bounds.
back_box = bounds(find(tree(), 'acc-header-back'))
tap('acc-header-back'); time.sleep(1.4)
assert abs(size('acc-header-primary')[0] - 44) <= 1, 'header primary back to ⋯ disc'
appears = recorded_change('android-shared-appear', back_box, lambda: (tap('acc-row-All'), time.sleep(1.4)))
def push_and_pop():
  tap('acc-row-Item1'); time.sleep(1.4)
  assert bounds(find(tree(), 'acc-item-back')) == back_box, 'Item back button in the same place'
  tap('acc-item-share'); assert find(tree(), 'acc-item-state').get('text') == 'Shared', 'carried Share reaches Item'
  adb('shell', 'input', 'keyevent', '4'); time.sleep(1.4)
still = recorded_change('android-shared-still', back_box, push_and_pop, seconds=16)
print(f'back button change: appears {appears:.2f}, shared {still:.2f}')
assert appears > 4, f'positive control: the appearing back button should register ({appears:.2f})'
assert still <= 4, f'the back button shared by All and Item changed ({still:.2f})'
assert find(tree(), 'acc-header-back') is not None and bounds(find(tree(), 'acc-header-back')) == back_box
# Within a screen: back → Cancel and Edit → Done keep their edges, Share leaves and returns.
tap('acc-row-Item1'); time.sleep(1.4)
item_back, item_primary = bounds(find(tree(), 'acc-item-back')), bounds(find(tree(), 'acc-item-primary'))
item_share = bounds(find(tree(), 'acc-item-share'))
for leave in ['acc-item-primary', 'acc-item-cancel']:
  tap('acc-item-primary'); time.sleep(1.0)
  root = tree(); cancel, done = find(root, 'acc-item-cancel'), find(root, 'acc-item-primary')
  assert abs(bounds(cancel)[0] - item_back[0]) <= 2, 'Cancel keeps the leading edge'
  assert abs(bounds(done)[2] - item_primary[2]) <= 2 and done.get('content-desc', '').startswith('Done'), f'Done keeps the trailing edge: {done.get("content-desc")}'
  assert absent(root, 'acc-item-share'), 'Share leaves in edit mode'
  tap(leave); time.sleep(1.0)
  root = tree()
  assert bounds(find(root, 'acc-item-back')) == item_back and bounds(find(root, 'acc-item-share')) == item_share, 'back and Share return'
# Across screens with different controls and counts: Item [back | Share, Edit] → Details [Close | ⋯].
tap('acc-item-details'); time.sleep(1.4)
root = tree()
assert abs(bounds(find(root, 'acc-details-close'))[0] - item_back[0]) <= 2, 'Close takes the back button place'
assert abs(bounds(find(root, 'acc-details-more'))[2] - item_primary[2]) <= 2, 'More takes Edit place'
tap('acc-details-more'); assert find(tree(), 'acc-details-state').get('text') == 'More', 'More reaches Details'
adb('shell', 'input', 'keyevent', '4'); time.sleep(1.4)
root = tree()
assert bounds(find(root, 'acc-item-back')) == item_back and bounds(find(root, 'acc-item-share')) == item_share, 'Item controls return after Details'
adb('shell', 'input', 'keyevent', '4'); time.sleep(1.4)
tap('acc-header-back'); time.sleep(1.4)
print('Android 0.2.0 acceptance passed: native sizes, group, morph resize, presence, header push/pop, shared controls still, edit mode, different counts')
