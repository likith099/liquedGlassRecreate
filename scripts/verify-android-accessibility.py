"""B3 control coverage and adaptive snapshots. Restores changed emulator settings even on failure."""
import json
import os
from pathlib import Path
import runpy
import time

ROOT = Path(__file__).resolve().parent.parent
h = runpy.run_path(str(ROOT / 'scripts/verify-android-menu.py'))
adb, tree, find, bounds = [h[key] for key in ['adb', 'tree', 'find', 'bounds']]

def reveal(value, up=True):
    """Scroll until the whole control is on screen.

    UIAutomator clips bounds to the window, so a control scrolled only partly into view
    reports a short box whose bottom sits on the fold. Accept a control that clears the
    window edge, or one whose visible height has stopped growing because the list ended.
    """
    previous = -1
    for _ in range(16):
        root = tree()
        _, _, w, height = bounds(root.find('node'))
        visible = -1
        try:
            n = find(root, value)
            x1, y1, x2, y2 = bounds(n)
            visible = y2 - y1
            if visible > 0 and (y2 < height - 100 or visible <= previous): return n
        except AssertionError: pass
        previous = visible
        start, end = (.72, .38) if up else (.38, .72)
        adb('shell', 'input', 'swipe', w // 2, int(height * start), w // 2, int(height * end), 350)
        time.sleep(.35)
    raise AssertionError(f'{value} not reachable')

def tap(value, up=True):
    n = reveal(value, up)
    x1, y1, x2, y2 = bounds(n)
    adb('shell', 'input', 'tap', (x1+x2)//2, (y1+y2)//2)
    time.sleep(.4)

def text(value): return find(tree(), value).get('text')
def launch():
    adb('shell', 'am', 'start', '-S', '-n', 'com.liquidglasslab/.MainActivity')
    for _ in range(30):
        try:
            find(tree(), 'open-accessibility-demo')
            break
        except AssertionError: time.sleep(1)
    else: raise AssertionError('Demo did not finish loading')
    tap('open-accessibility-demo')

def capture(name):
    (ROOT / f'artifacts/b3-android-{name}.png').write_bytes(adb('exec-out', 'screencap', '-p'))
    (ROOT / f'artifacts/b3-android-{name}.xml').write_bytes(__import__('xml.etree.ElementTree', fromlist=['tostring']).tostring(tree()))

def controls():
    launch(); tap('adaptive-button')
    assert text('adaptive-count') == 'Added: 1'
    tap('adaptive-loading', up=False)
    assert reveal('adaptive-button').get('enabled') == 'false'
    tap('adaptive-button'); assert text('adaptive-count') == 'Added: 1'
    tap('adaptive-loading', up=False)
    tap('adaptive-segments-saved')
    assert text('adaptive-selection') == 'Selected: saved'
    assert find(tree(), 'adaptive-segments-saved').get('checked') == 'true'
    assert find(tree(), 'adaptive-segments-shared').get('enabled') == 'false'
    tap('adaptive-reject', up=False); tap('adaptive-segments-all')
    assert text('adaptive-selection') == 'Selected: saved'
    tap('adaptive-disabled', up=False)
    assert reveal('adaptive-button').get('enabled') == 'false'
    assert reveal('adaptive-segments-all').get('enabled') == 'false'
    tap('adaptive-disabled', up=False)
    tap('glass-cluster-toggle')
    assert reveal('glass-action-locked').get('enabled') == 'false'
    tap('glass-action-save'); assert text('adaptive-event') == 'Action: save'
    tap('glass-cluster-toggle')
    assert not any(n.get('resource-id') == 'glass-action-save' for n in tree().iter('node'))
    capture('controls')
    print('Android button, loading/disabled, controlled selector and action cluster passed.', flush=True)

# RTL is not automated here. The developer force-RTL setting has no effect on this app,
# a Play Store emulator image cannot change persist.sys.locale without root, and a per-app
# Arabic locale left both React and native Android layout unmirrored. Exercise RTL on a
# rootable google_apis AVD or a physical device set to an RTL language; see docs/accessibility.md.
original = {'font_scale': adb('shell', 'settings', 'get', 'system', 'font_scale').decode().strip()}
original_night = adb('shell', 'cmd', 'uimode', 'night').decode().strip().split()[-1]
results = {}
try:
    adb('shell', 'settings', 'put', 'system', 'font_scale', '1.0')
    adb('shell', 'cmd', 'uimode', 'night', 'no')
    controls(); results['controls'] = 'passed'
    if os.environ.get('B3_CONTROLS_ONLY') != '1':
        for name, scale, night in [('large-dark', '2.0', 'yes'), ('standard-light', '1.0', 'no')]:
            adb('shell', 'settings', 'put', 'system', 'font_scale', scale)
            adb('shell', 'cmd', 'uimode', 'night', night)
            launch()
            environment = text('adaptive-environment')
            assert ('dark' if night == 'yes' else 'light') in environment, environment
            assert f'Text scale: {float(scale):.2f}' in environment, environment
            tap('adaptive-segments-saved')
            assert text('adaptive-selection') == 'Selected: saved'
            capture(name)
            reveal('adaptive-tabs')
            root = tree()
            locked = next(n for n in root.iter('node') if n.get('content-desc', '').startswith('Locked'))
            assert locked.get('enabled') == 'false'
            capture(name + '-tabs')
            results[name] = 'passed'
            print(f'Android {name} passed.', flush=True)
finally:
    for key, value in original.items():
        if value == 'null': adb('shell', 'settings', 'delete', 'system', key)
        else: adb('shell', 'settings', 'put', 'system', key, value)
    adb('shell', 'cmd', 'uimode', 'night', original_night)
(ROOT / 'artifacts/b3-android-verification.json').write_text(json.dumps(results, indent=2) + '\n')
print('Android B3 checks passed; emulator settings restored.', flush=True)
