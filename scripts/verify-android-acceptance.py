"""0.2.0 acceptance on Android: native measurement sizes (no JS round trip), group/pill/morph
geometry, presence exit, header stack push/pop with slot morph."""
import runpy, time
from pathlib import Path
h = runpy.run_path(str(Path(__file__).with_name('verify-android-menu.py')))
adb, tree, find, bounds = (h[k] for k in ('adb', 'tree', 'find', 'bounds'))
# `wm density` prints the physical and, if set, override density; the last value is in effect.
density = float(adb('shell', 'wm', 'density').decode().split()[-1]) / 160

def tap(value):
  try: node = find(tree(), value)
  except AssertionError: node = h['reveal'](value)
  x1, y1, x2, y2 = bounds(node); adb('shell', 'input', 'tap', (x1 + x2) // 2, (y1 + y2) // 2); time.sleep(.6)

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
tap('acc-header-back'); time.sleep(1.4)
assert abs(size('acc-header-primary')[0] - 44) <= 1, 'header primary back to ⋯ disc'
print('Android 0.2.0 acceptance passed: native sizes, group, morph resize, presence, header push/pop')
