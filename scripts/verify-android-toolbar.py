"""Run the shared flat-menu regression and B1 toolbar/hierarchy checks in a fresh demo."""
import json
from pathlib import Path
import runpy
import time
import sys

ROOT = Path(__file__).resolve().parent.parent
# Reuse helpers; run the affected flat-menu regression once unless resuming the timed check.
helpers = runpy.run_path(str(ROOT/'scripts/verify-android-menu.py'))
adb, tree, find, tap, reveal, menu_row = [helpers[key] for key in ['adb', 'tree', 'find', 'tap', 'reveal', 'menu_row']]
replacement_only = '--replacement-only' in sys.argv
toolbar_only = '--toolbar-only' in sys.argv
if not replacement_only and not toolbar_only: helpers['verify']()
adb('shell', 'am', 'start', '-S', '-n', 'com.liquidglasslab/.MainActivity')
time.sleep(3)

def exists(root, value):
    try: find(root, value); return True
    except AssertionError: return False

def status(value):
    assert find(tree(), 'toolbar-status').get('text') == f'Toolbar selected: {value}'

def reveal_near(value):
    for _ in range(14):
        root = tree()
        try:
            node = find(root, value)
            x1,y1,x2,y2 = helpers['bounds'](node)
            if y2 > y1 and y1 > 160 and y2 < 2700: return
            up = y1 >= 160
        except AssertionError:
            up = True
        adb('shell', 'input', 'swipe', 670, 2200 if up else 1000, 670, 1000 if up else 2200, 350)
    raise AssertionError(f'Could not reveal {value}')

if not replacement_only:
    reveal_near('Save'); tap('Save'); status('save')
    print('Toolbar direct action passed.', flush=True)
    tap('Sort'); tap('Most recent'); status('recent')
    assert find(tree(), 'toolbar-selection').get('text') == 'Order: recent'
    tap('Sort')
    root = tree()
    assert menu_row(root, 'Locked action').get('enabled') == 'false'
    assert any(n.get('checked') == 'true' for n in menu_row(root, 'Most recent').iter('node'))
    (ROOT/'artifacts/b1-android-grouped-menu.png').write_bytes(adb('exec-out','screencap','-p'))
    adb('shell','input','keyevent',4); status('recent')
    tap('More options')
    assert menu_row(tree(), 'Unavailable toolbar action').get('enabled') == 'false'
    tap('Export entire collection'); status('export')
    print('Toolbar groups, checkmarks, overflow and dismissal passed.', flush=True)
    tap('hierarchy-menu')
    assert menu_row(tree(), 'Locked group').get('enabled') == 'false'
    tap('Order options'); tap('By name'); status('name')
    reveal_near('toolbar-disabled-toggle'); tap('toolbar-disabled-toggle')
    assert find(tree(), 'Save').get('enabled') == 'false'
    assert find(tree(), 'hierarchy-menu').get('enabled') == 'false'
    tap('toolbar-disabled-toggle')
    reveal_near('toolbar-narrow-toggle'); tap('toolbar-narrow-toggle')
    reveal_near('More options')
    assert not exists(tree(), 'Save'), 'Narrow toolbar must move actions into overflow'
    tap('More options'); tap('Save')
    status('save')
    (ROOT/'artifacts/b1-android-narrow.png').write_bytes(adb('exec-out','screencap','-p'))
    reveal_near('toolbar-narrow-toggle'); tap('toolbar-narrow-toggle')
    reveal_near('toolbar-replace-toggle'); tap('toolbar-replace-toggle')
    reveal_near('Archive'); tap('Archive'); status('archive')
    assert not exists(tree(), 'Save')
    print('Hierarchy, disablement, narrow layout and replacement passed.', flush=True)
else:
    reveal_near('toolbar-replace-toggle'); tap('toolbar-replace-toggle')
    reveal_near('Archive'); tap('Archive'); status('archive')
reveal_near('toolbar-timed-replace'); tap('toolbar-timed-replace')
reveal_near('Sort'); tap('Sort')
assert exists(tree(), 'Most recent'), 'Open menu before the scheduled replacement'
deadline = time.monotonic() + 25
while time.monotonic() < deadline:
    if not exists(tree(), 'Most recent'): break
else: raise AssertionError('Replacing toolbar items did not dismiss the submenu')
status('archive')
assert exists(tree(), 'Save')
result = {'openMenuReplacement': 'passed'} if replacement_only else {name: 'passed' for name in ['flatMenuRegression','toolbarAction','overflow','hierarchy','checked','disabled','dismissal','narrowLayout','replacement','openMenuReplacement']}
record_name = 'b1-android-replacement.json' if replacement_only else 'b1-android-verification.json'
if toolbar_only and not replacement_only: result['flatMenuRegression'] = 'not rerun: toolbar placement-only follow-up; preceding flat regression passed'
(ROOT/'artifacts'/record_name).write_text(json.dumps(result, indent=2)+'\n')
print('Android B1 checks passed.', flush=True)
