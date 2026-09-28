"""Exercise the content-preserving native menu in the running Android demo."""
import importlib.util
import json
import time
from pathlib import Path

spec = importlib.util.spec_from_file_location('menu', Path(__file__).with_name('verify-android-menu.py'))
menu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(menu)

def hold():
    x1, y1, x2, y2 = menu.bounds(menu.find(menu.tree(), 'message-context'))
    assert y2 - y1 > 80, 'React children must size the content host'
    x, y = (x1 + x2)//2, (y1 + y2)//2
    menu.adb('shell', 'input', 'swipe', x, y, x, y, 1000)
    time.sleep(.5)

def absent(title):
    assert not any(n.get('text') == title for n in menu.tree().iter('node')), title

for attempt in range(20):
    try:
        menu.find(menu.tree(), 'open-context-demo')
        break
    except AssertionError:
        if attempt == 19:
            raise
        time.sleep(1)
menu.tap('open-context-demo')
menu.tap('message-context'); absent('Edit message')
hold()
assert menu.menu_row(menu.tree(), 'Unavailable message action').get('enabled') == 'false'
(menu.ROOT/'artifacts/context-android-open.png').write_bytes(menu.adb('exec-out', 'screencap', '-p'))
menu.tap('Edit message')
assert menu.find(menu.tree(), 'context-status').get('text') == 'Context selected: edit'
menu.find(menu.tree(), 'message-context')
hold(); menu.tap('Save message')
assert menu.find(menu.tree(), 'context-saved').get('text') == 'Message saved: on'
hold(); menu.tap('More message actions'); menu.tap('Copy message')
assert menu.find(menu.tree(), 'context-status').get('text') == 'Context selected: copy'
# Confirm the menu is open first: Back with no menu would leave the demo instead.
hold(); menu.menu_row(menu.tree(), 'Edit message'); menu.adb('shell', 'input', 'keyevent', 4)
assert menu.find(menu.tree(), 'context-count').get('text') == 'Context actions: 3'
menu.tap('context-disabled'); hold(); absent('Edit message'); menu.tap('context-disabled')
menu.tap('context-replace'); hold(); time.sleep(8); absent('Edit message')
hold(); menu.tap('New action')
assert menu.find(menu.tree(), 'context-count').get('text') == 'Context actions: 4'
menu.tap('context-unmount'); hold(); time.sleep(8); absent('New action')
assert menu.find(menu.tree(), 'context-status').get('text') == 'Message removed'
assert menu.find(menu.tree(), 'context-count').get('text') == 'Context actions: 4'
(menu.ROOT/'artifacts/context-android-verification.json').write_text(json.dumps({
    'longPress': 'passed', 'tapDoesNotOpen': 'passed', 'selection': 'passed',
    'disabled': 'passed', 'submenu': 'passed', 'dismissal': 'passed',
    'replacement': 'passed', 'unmount': 'passed'}, indent=2) + '\n')
print('Android context menu checks passed.')
