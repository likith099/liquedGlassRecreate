"""Exercise the demo's native SeekBar on a running Android device/emulator.

Start Metro and open LiquidGlassLab before running. Uses ANDROID_SERIAL/ADB
when set; otherwise selects emulator-5554 and the standard macOS SDK path.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
ARTIFACTS = ROOT / 'artifacts'
ARTIFACTS.mkdir(exist_ok=True)
ADB = os.environ.get('ADB', str(Path.home() / 'Library/Android/sdk/platform-tools/adb'))
SERIAL = os.environ.get('ANDROID_SERIAL', 'emulator-5554')

def adb(*args):
    return subprocess.check_output([ADB, '-s', SERIAL, *map(str, args)], timeout=30)

def tree():
    adb('shell', 'uiautomator', 'dump', '/sdcard/alg-slider-test.xml')
    return ET.fromstring(adb('shell', 'cat', '/sdcard/alg-slider-test.xml'))

def find(root, identifier):
    for node in root.iter('node'):
        if node.get('resource-id') == identifier or (identifier == 'seekbar' and node.get('class') == 'android.widget.SeekBar'):
            return node
    raise AssertionError(f'{identifier} is not visible')

def bounds(node):
    return list(map(int, re.findall(r'\d+', node.get('bounds'))))

def tap(identifier):
    x1, y1, x2, y2 = bounds(find(tree(), identifier))
    adb('shell', 'input', 'tap', (x1 + x2) // 2, (y1 + y2) // 2)
    time.sleep(0.3)

def switch(identifier, enabled):
    if (find(tree(), identifier).get('checked') == 'true') != enabled:
        tap(identifier)

def value(root):
    return float(find(root, 'slider-value').get('text').split(': ')[1])

def drag(target):
    root = tree()
    x1, y1, x2, y2 = bounds(find(root, 'seekbar'))
    # Android's native thumb track is inset from the view bounds.
    inset = (y2 - y1) * 0.3
    start = x1 + inset + (x2 - x1 - 2 * inset) * value(root) / 100
    end = x1 + inset + (x2 - x1 - 2 * inset) * target
    adb('shell', 'input', 'swipe', round(start), (y1 + y2) // 2, round(end), (y1 + y2) // 2, 700)
    time.sleep(0.5)
    return tree()

def screenshot(name):
    (ARTIFACTS / name).write_bytes(adb('exec-out', 'screencap', '-p'))

root = tree()
for attempt in range(8):
    if any(n.get('resource-id') == 'slider-lock-toggle' for n in root.iter('node')):
        break
    screen = bounds(root.find('node'))
    adb('shell', 'input', 'swipe', screen[2] // 2, round(screen[3] * 0.8), screen[2] // 2, round(screen[3] * 0.3), 450)
    root = tree()
find(root, 'slider-lock-toggle')
switch('slider-disabled-toggle', False)
switch('slider-lock-toggle', False)
switch('slider-step-toggle', True)
tap('slider-reset')
assert value(tree()) == 40
screenshot('slider-android-reset.png')

root = drag(0.81)
snapped = value(root)
assert snapped >= 70 and snapped % 10 == 0, snapped
assert find(root, 'slider-event').get('text').startswith('Completed:'), ET.tostring(root)
print(f'Stepped drag passed: {snapped}', flush=True)

tap('slider-reset')
assert value(tree()) == 40
switch('slider-lock-toggle', True)
root = drag(0.9)
assert value(root) == 40
assert find(root, 'slider-event').get('text').startswith('Completed:'), ET.tostring(root)
screenshot('slider-android-rejected.png')
print('Rejected change kept the controlled value at 40; thumb screenshot captured.', flush=True)

switch('slider-lock-toggle', False)
switch('slider-disabled-toggle', True)
root = tree()
assert find(root, 'seekbar').get('enabled') == 'false'
previous = find(root, 'slider-event').get('text')
root = drag(0.75)
assert value(root) == 40
assert find(root, 'slider-event').get('text') == previous
print('Disabled drag suppressed changes and completion.', flush=True)

switch('slider-disabled-toggle', False)
switch('slider-step-toggle', False)
root = drag(0.63)
continuous = value(root)
assert 55 < continuous < 70 and continuous % 10 != 0, continuous
assert find(root, 'slider-event').get('text').startswith('Completed:')
screenshot('slider-android.png')
(ARTIFACTS / 'slider-android-results.json').write_text(json.dumps({
    'device': SERIAL, 'steppedDrag': snapped, 'controlledReset': 40,
    'rejectedChangeValue': 40, 'disabledSuppression': 'passed',
    'continuousDrag': continuous,
    'note': 'Inspect reset/rejected screenshots to verify native thumb reconciliation.'
}, indent=2))
print(f'Continuous drag passed: {continuous}', flush=True)
