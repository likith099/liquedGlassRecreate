"""Exercise the demo's long-press message menu (GlassContextMenu, menuPlacement "below") on Android: for
a received and a sent message at the top, middle and bottom of the screen, a long press opens the menu
popup, choosing a row reports it, and where the popup opened relative to the message is recorded."""
import importlib.util
import io
import json
import time
from pathlib import Path
from PIL import Image

spec = importlib.util.spec_from_file_location('menu', Path(__file__).with_name('verify-android-menu.py'))
menu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(menu)

def bubble_bottom(png, x1, x2):
    """The lowest row of the message bubble's colour within its columns. While a popup is open,
    UIAutomator dumps only the popup, so the lifted message is found in the screenshot."""
    image = Image.open(io.BytesIO(png)).convert('RGB')
    pixels = image.load()
    colours = [(166, 187, 255), (59, 74, 140)]  # the demo bubble in light and dark
    rows = [y for y in range(0, image.height, 2)
            if sum(1 for x in range(x1 + 10, x2 - 10, 4)
                   if any(sum(abs(a - b) for a, b in zip(pixels[x, y], c)) < 30 for c in colours)) > 3]
    return max(rows) if rows else None

def status():
    return menu.find(menu.tree(), 'panel-status').get('text')

def screen_height():
    return menu.bounds(menu.tree().find('node'))[3]

def to_band(value, low, high):
    """Scroll until the element's centre sits within [low, high] of the screen height."""
    height = screen_height()
    for _ in range(20):
        x1, y1, x2, y2 = menu.bounds(menu.find(menu.tree(), value))
        centre = (y1 + y2) / 2
        target = height * (low + high) / 2
        if height * low <= centre <= height * high:
            return x1, y1, x2, y2
        distance = max(-height // 3, min(height // 3, int(centre - target)))
        start = height // 2 + distance // 2
        menu.adb('shell', 'input', 'swipe', 60, start, 60, start - distance, 700)
        time.sleep(.5)
    raise AssertionError(f'Could not move {value} to {low}-{high}')

for attempt in range(20):
    try:
        menu.find(menu.tree(), 'open-context-demo')
        break
    except AssertionError:
        if attempt == 19:
            raise
        time.sleep(1)
menu.tap('open-context-demo')
menu.reveal('panel-longpress'); menu.tap('panel-longpress')
results = []
for side in ['Received', 'Sent']:
    menu.reveal(side); menu.tap(side)
    for low, high in [(.15, .25), (.45, .55), (.8, .88)]:
        x1, y1, x2, y2 = to_band('panel-message', low, high)
        menu.adb('shell', 'input', 'swipe', (x1 + x2) // 2, (y1 + y2) // 2, (x1 + x2) // 2, (y1 + y2) // 2, 900)
        time.sleep(.8)
        row = menu.menu_row(menu.tree(), 'Forward')
        rx1, ry1, rx2, ry2 = menu.bounds(row)
        png = menu.adb('exec-out', 'screencap', '-p')
        (menu.ROOT/f'artifacts/menu-panel-android-{side.lower()}-{int(low*100)}.png').write_bytes(png)
        lifted = bubble_bottom(png, x1, x2)
        assert lifted is not None, 'message not found on screen'
        # The popup's first row sits below the (possibly lifted) message.
        assert ry1 >= lifted, f'popup above the message ({side}, {low}-{high}): row {ry1}, message bottom {lifted}'
        results.append({'side': side, 'band': [low, high], 'messageBefore': [x1, y1, x2, y2], 'messageBottomNow': lifted,
                        'firstRow': [rx1, ry1, rx2, ry2]})
        print(f'{side} {low}-{high}: message bottom {y2} -> {lifted}, popup first row y {ry1}: below', flush=True)
        rows = menu.menu_row(menu.tree(), 'Copy')
        cx1, cy1, cx2, cy2 = menu.bounds(rows)
        menu.adb('shell', 'input', 'tap', (cx1 + cx2) // 2, (cy1 + cy2) // 2)
        time.sleep(.6)
        assert status() == 'Panel selected: copy', status()
(menu.ROOT/'artifacts/menu-panel-android.json').write_text(json.dumps(results, indent=2) + '\n')
print('Android menu panel checks passed.')
