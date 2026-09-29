"""Exercise GlassMenuPanel and GlassLongPress in the running Android demo: tap selection, long press
with the frame, the pressing finger sliding onto a row, and lifting off the panel."""
import importlib.util
import time
from pathlib import Path

spec = importlib.util.spec_from_file_location('menu', Path(__file__).with_name('verify-android-menu.py'))
menu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(menu)

def status():
    return menu.find(menu.tree(), 'panel-status').get('text')

def centre(node):
    x1, y1, x2, y2 = menu.bounds(node)
    return (x1 + x2)//2, (y1 + y2)//2

def press_and_slide(start, end, hold=.9, steps=8):
    """One finger: down, held past the long-press threshold, moved in steps, lifted."""
    menu.adb('shell', 'input', 'touchscreen', 'motionevent', 'DOWN', *start)
    time.sleep(hold)
    for step in range(1, steps + 1):
        menu.adb('shell', 'input', 'touchscreen', 'motionevent', 'MOVE', start[0] + (end[0] - start[0])*step//steps,
                 start[1] + (end[1] - start[1])*step//steps)
    time.sleep(.2)
    menu.adb('shell', 'input', 'touchscreen', 'motionevent', 'UP', *end)
    time.sleep(.6)

for attempt in range(20):
    try:
        menu.find(menu.tree(), 'open-context-demo')
        break
    except AssertionError:
        if attempt == 19:
            raise
        time.sleep(1)
menu.tap('open-context-demo')
menu.reveal('panel-toggle'); menu.tap('panel-toggle')
menu.reveal('Copy'); menu.tap('Copy')
assert status() == 'Panel selected: copy', status()
menu.reveal('panel-longpress'); menu.tap('panel-longpress')
menu.reveal('Below right'); menu.tap('Below right')
message = menu.reveal('panel-message')
start = centre(message)
# A tap before the threshold reaches the message.
menu.tap('panel-message')
assert status() == 'Message tapped', status()
# A long press opens the panel and reports the message's frame.
press_and_slide(start, start)
assert status().startswith('Long press at '), status()
root = menu.tree()
star = centre(menu.find(root, 'Star'))
(menu.ROOT/'artifacts/menu-panel-android.png').write_bytes(menu.adb('exec-out', 'screencap', '-p'))
menu.tap('panel-message')
assert status() == 'Message tapped', status()
# The finger that pressed slides onto a row and lifts: that row is chosen.
press_and_slide(start, star)
assert status() == 'Panel selected: star', status()
# Lifting off the panel chooses nothing and leaves it open for a tap.
press_and_slide(start, (start[0] - 300, start[1] - 150))
assert status().startswith('Long press at '), status()
menu.find(menu.tree(), 'Copy')
menu.tap('Copy')
assert status() == 'Panel selected: copy', status()
print('Android menu panel checks passed.')
