"""Exercise real per-app locales in the installed demo; restore the original locale."""
import json
from pathlib import Path
import re
import runpy
import time

ROOT = Path(__file__).resolve().parent.parent
h = runpy.run_path(str(ROOT / 'scripts/verify-android-menu.py'))
adb, tree, find, bounds = [h[key] for key in ['adb', 'tree', 'find', 'bounds']]
PACKAGE = 'com.liquidglasslab'

def reveal(identifier):
    for attempt in range(20):
        root = tree()
        _, _, width, height = bounds(root.find('node'))
        upward = attempt < 10
        try:
            node = find(root, identifier)
            x1, y1, x2, y2 = bounds(node)
            if y2 > y1 and y1 > 70 and y2 < height - 80:
                return node
            upward = (y1 + y2) / 2 > height / 2
        except AssertionError:
            pass
        start, end = (.75, .35) if upward else (.35, .75)
        adb('shell', 'input', 'swipe', width // 2, int(height * start), width // 2, int(height * end), 300)
        time.sleep(.3)
    raise AssertionError(f'{identifier} not reachable')

def tap(identifier):
    x1, y1, x2, y2 = bounds(reveal(identifier))
    adb('shell', 'input', 'tap', (x1 + x2) // 2, (y1 + y2) // 2)
    time.sleep(.4)

def center_x(node):
    x1, _, x2, _ = bounds(node)
    return (x1 + x2) / 2

def locale(value):
    adb('shell', 'cmd', 'locale', 'set-app-locales', PACKAGE, '--user', 'current', '--locales', value or "''")
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
    for _ in range(25):
        try:
            find(tree(), 'open-accessibility-demo')
            return
        except AssertionError:
            time.sleep(.5)
    raise AssertionError('Release app did not launch')

assert int(adb('shell', 'getprop', 'ro.build.version.sdk').strip()) >= 33, 'Per-app locale test requires API 33+'
original_output = adb('shell', 'cmd', 'locale', 'get-app-locales', PACKAGE, '--user', 'current').decode()
matches = re.findall(r'\[([^\]]*)\]', original_output)
assert matches, original_output
original = matches[-1].replace(' ', '')
assert re.fullmatch(r'[A-Za-z0-9,-]*', original), original
results = {}
try:
    for name, language, rtl in [('ltr', 'en', False), ('rtl', 'ar', True), ('ltr-restored', 'en', False)]:
        locale(language)
        tap('open-accessibility-demo')
        environment = find(tree(), 'adaptive-environment').get('text', '')
        assert ('RTL' if rtl else 'LTR') in environment, environment
        reveal('adaptive-segments-saved')
        root = tree()
        first = find(root, 'adaptive-segments-all')
        last = find(root, 'adaptive-segments-shared')
        assert (center_x(first) > center_x(last)) == rtl, 'Selector order does not match the locale'
        assert last.get('enabled') == 'false', 'Disabled option must remain disabled'
        tap('adaptive-segments-saved')
        assert find(tree(), 'adaptive-selection').get('text') == 'Selected: saved'
        tap('glass-cluster-toggle')
        tap('glass-action-save')
        assert find(tree(), 'adaptive-event').get('text') == 'Action: save'
        (ROOT / f'artifacts/b5-android-{name}.png').write_bytes(adb('exec-out', 'screencap', '-p'))
        results[name] = {'locale': language, 'environment': environment, 'selectorAndAction': 'passed'}
finally:
    locale(original)
(ROOT / 'artifacts/b5-android-rtl.json').write_text(json.dumps(results, indent=2) + '\n')
print('Android real-locale LTR → RTL → LTR checks passed; original locale restored.')
