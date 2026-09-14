"""Verify the new native menu in an installed/running Android demo (requires its native rebuild)."""
import json
import os
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
ADB = os.environ.get('ADB', str(Path.home() / 'Library/Android/sdk/platform-tools/adb'))
SERIAL = os.environ.get('ANDROID_SERIAL', 'emulator-5554')

def adb(*args):
    return subprocess.check_output([ADB, '-s', SERIAL, *map(str, args)], timeout=30)

def tree():
    for _ in range(3):
        result = adb('shell', 'uiautomator', 'dump', '/sdcard/alg-menu-test.xml')
        if b'dumped to' in result:
            return ET.fromstring(adb('shell', 'cat', '/sdcard/alg-menu-test.xml'))
        # UIAutomator can return success with a null root during popup transitions.
        # Never inspect the previous dump as though it described the current UI.
        time.sleep(.5)
    raise AssertionError('UIAutomator did not return a fresh accessibility tree')

def find(root, value):
    for node in root.iter('node'):
        if value in [node.get('resource-id'), node.get('text'), node.get('content-desc')]:
            return node
    raise AssertionError(f'{value} not visible')

def menu_row(root, title):
    for view in root.iter('node'):
        if view.get('class') == 'android.widget.ListView':
            for row in view:
                if any(n.get('text') == title for n in row.iter('node')):
                    return row
    raise AssertionError(f'No native menu row for {title}')

def bounds(node):
    return list(map(int, re.findall(r'\d+', node.get('bounds'))))

def tap(value):
    x1, y1, x2, y2 = bounds(find(tree(), value))
    adb('shell', 'input', 'tap', (x1+x2)//2, (y1+y2)//2)
    time.sleep(.4)

def reveal(value):
    for _ in range(10):
        root = tree()
        try:
            node = find(root, value)
            if bounds(node)[3] > bounds(node)[1]: return node
        except AssertionError:
            pass
        _, _, width, height = bounds(root.find('node'))
        adb('shell', 'input', 'swipe', width//2, int(height*.75), width//2, int(height*.4), 350)
    raise AssertionError(f'Could not reveal {value}')

def verify():
    reveal('native-menu')
    tap('native-menu')
    assert menu_row(tree(), 'Unavailable action').get('enabled') == 'false'
    tap('Favorite item')
    assert find(tree(), 'menu-status').get('text') == 'Menu selected: favorite'
    assert find(tree(), 'menu-checked').get('text') == 'Favorite: on'
    tap('native-menu')
    root = tree()
    rows = [node for node in root.iter('node') if node.get('class') == 'android.widget.ListView']
    assert rows, 'Expected a native popup list'
    checked_rows = [row for view in rows for row in view if any(n.get('text') == 'Favorite item' for n in row.iter('node'))]
    assert any(n.get('checked') == 'true' for row in checked_rows for n in row.iter('node')), 'Expected controlled checkmark'
    (ROOT/'artifacts/menu-android-open.png').write_bytes(adb('exec-out', 'screencap', '-p'))
    tap('Share item')
    assert find(tree(), 'menu-status').get('text') == 'Menu selected: share'
    tap('native-menu')
    adb('shell', 'input', 'keyevent', 4)
    assert find(tree(), 'menu-status').get('text') == 'Menu selected: share', 'Dismissal must not select'
    tap('native-menu'); tap('Remove item')
    assert find(tree(), 'menu-status').get('text') == 'Menu selected: remove'
    reveal('menu-disabled-toggle'); tap('menu-disabled-toggle')
    assert find(tree(), 'native-menu').get('enabled') == 'false'
    tap('menu-disabled-toggle')
    assert find(tree(), 'native-menu').get('enabled') == 'true'
    (ROOT/'artifacts/menu-android-verification.json').write_text(json.dumps({'nativePopup': 'passed', 'selection': 'passed', 'checked': 'passed', 'disabled': 'passed', 'dismissal': 'passed'}, indent=2)+'\n')
    print('Android native menu checks passed.')

if __name__ == '__main__':
    verify()
