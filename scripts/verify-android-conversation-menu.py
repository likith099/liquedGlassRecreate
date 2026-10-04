"""Verify the shared afterClose option in the installed Release conversation demo."""
import importlib.util
import json
import time
from pathlib import Path

spec = importlib.util.spec_from_file_location('menu', Path(__file__).with_name('verify-android-menu.py'))
menu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(menu)

menu.reveal('open-context-demo'); menu.tap('open-context-demo')
menu.reveal('open-chat-menu-demo'); menu.tap('open-chat-menu-demo')

def latest():
    # Initial FlatList positioning can finish after the first button press on a cold emulator.
    for _ in range(4):
        menu.tap('chat-latest')
        time.sleep(1)
        try:
            node = menu.find(menu.tree(), 'chat-message-29')
            _, y1, _, y2 = menu.bounds(node)
            if y2 - y1 > 80:
                return
        except AssertionError:
            pass
    raise AssertionError('Latest message did not become visible after layout settled')

latest()

def hold():
    x1, y1, x2, y2 = menu.bounds(menu.find(menu.tree(), 'chat-message-29'))
    x, y = (x1 + x2) // 2, (y1 + y2) // 2
    menu.adb('shell', 'input', 'swipe', x, y, x, y, 1000)
    time.sleep(.5)
    root = menu.tree()
    assert menu.menu_row(root, 'Unavailable').get('enabled') == 'false'
    menu.menu_row(root, 'Copy')

def status():
    return menu.find(menu.tree(), 'chat-status').get('text')

for count in range(1, 4):
    hold()
    menu.adb('shell', 'input', 'keyevent', 4)
    time.sleep(.5)
    assert f'opened {count}; closed {count}' in status(), status()
    assert 'No action' in status()

hold(); menu.tap('Copy')
assert 'copy 29; opened 4; closed 4' in status(), status()
menu.tap('chat-image'); latest(); hold()
(menu.ROOT / 'artifacts/b17-android-conversation.png').write_bytes(menu.adb('exec-out', 'screencap', '-p'))
menu.tap('Delete')
assert 'delete 29; opened 5; closed 5' in status(), status()
assert not any(n.get('resource-id') == 'chat-message-29' for n in menu.tree().iter('node'))
(menu.ROOT / 'artifacts/b17-android-conversation.json').write_text(json.dumps({
    'repeatedDismissal': 'passed', 'disabledRow': 'passed', 'afterCloseSelection': 'passed',
    'imageSourceDeletion': 'passed', 'animationTimingMeasured': False,
}, indent=2) + '\n')
print('Android conversation menu checks passed.')
