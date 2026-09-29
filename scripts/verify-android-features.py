"""Verify the 0.1.3 additions in the running Android demo: icon buttons and programmatic menus,
segment counts, badges and the prominent icon button, expanding pills, the search field and toast,
and tab image sources with per-tab and bar colours. Screens are saved under artifacts/.

Requires the debug demo installed on ANDROID_SERIAL (default emulator-5554) with Metro on 8093.
"""
import io
import json
from pathlib import Path
import runpy
import time

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
h = runpy.run_path(str(ROOT / 'scripts/verify-android-menu.py'))
adb, tree, find, bounds, menu_row = [h[key] for key in ['adb', 'tree', 'find', 'bounds', 'menu_row']]
DENSITY = int(adb('shell', 'wm', 'density').split()[-1]) / 160
results = {}

def launch():
    adb('shell', 'am', 'start', '-S', '-n', 'com.liquidglasslab/.MainActivity')
    for _ in range(30):
        try:
            find(tree(), 'open-tabs-demo')
            return
        except AssertionError:
            time.sleep(1)
    raise AssertionError('Demo did not start')

def node(root, value):
    """A node by id, text or content description, including Material tabs ("Library tab, …")."""
    try:
        return find(root, value)
    except AssertionError:
        for candidate in root.iter('node'):
            if candidate.get('content-desc', '').startswith(value + ','):
                return candidate
        raise

def center(value):
    x1, y1, x2, y2 = bounds(node(tree(), value))
    return (x1 + x2) // 2, (y1 + y2) // 2

def tap(value, settle=.5):
    adb('shell', 'input', 'tap', *center(value))
    time.sleep(settle)

def wait(value, timeout=6):
    end = time.time() + timeout
    while True:
        try:
            return node(tree(), value)
        except AssertionError:
            if time.time() > end:
                raise
            time.sleep(.4)

def absent(value, timeout=2):
    time.sleep(timeout)
    try:
        node(tree(), value)
    except AssertionError:
        return
    raise AssertionError(f'{value} should not be visible')

def reveal(value, down=True):
    """Scroll until the element is on screen, clear of the edges. When the page stops moving without
    finding it, the search reverses once. At most 16 drags."""
    direction = 1 if down else -1
    reversed_once = False
    previous = None
    for _ in range(16):
        root = tree()
        _, _, width, height = bounds(root.find('node'))
        try:
            position = bounds(node(root, value))
        except AssertionError:
            position = None
        if position and position[1] > height * .12 and position[3] < height * .85:
            return
        if position:
            direction = 1 if position[3] >= height * .85 else -1
        screen = [(n.get('text'), n.get('bounds')) for n in root.iter('node') if n.get('text')]
        if screen == previous:
            if position and position[1] >= 0 and position[3] <= height:
                return  # at the page end, wholly visible
            if position or reversed_once:
                break
            direction, reversed_once = -direction, True
        previous = screen
        start, end = (.7, .4) if direction > 0 else (.35, .65)
        adb('shell', 'input', 'swipe', width // 2, int(height * start), width // 2, int(height * end), 600)
        time.sleep(.5)
    raise AssertionError(f'Could not reveal {value}')

def width_dp(value):
    x1, _, x2, _ = bounds(node(tree(), value))
    return (x2 - x1) / DENSITY

def screenshot(name):
    data = adb('exec-out', 'screencap', '-p')
    (ROOT / f'artifacts/{name}.png').write_bytes(data)
    return Image.open(io.BytesIO(data)).convert('RGB')

def pixels(image, box, color, distance=40):
    x1, y1, x2, y2 = box
    count = 0
    for r, g, b in image.crop((x1, y1, x2, y2)).getdata():
        if (r - color[0]) ** 2 + (g - color[1]) ** 2 + (b - color[2]) ** 2 < distance ** 2:
            count += 1
    return count

def keyboard_shown():
    return 'mInputShown=true' in adb('shell', 'dumpsys', 'input_method').decode()

# Icon buttons: plain press, tap-open and dismiss, open() from code, and disabled.
launch()
reveal('icon-open-from-code')
assert abs(width_dp('icon-close') - 40) < 2, f'icon-close is {width_dp("icon-close")} dp wide'
tap('icon-close'); wait('Icon pressed: close')
# While a popup is open UIAutomator dumps only the popup window, so counts are read after it closes.
tap('icon-more'); menu_row(tree(), 'Share')
adb('shell', 'input', 'keyevent', 4); wait('Menu opened 1, closed 1')
wait('Icon pressed: close')
screenshot('b11-android-icon-buttons')
tap('icon-open-from-code'); menu_row(tree(), 'Share')
tap('Share'); wait('Toolbar selected: share'); wait('Menu opened 2, closed 2')
reveal('toolbar-disabled-toggle'); tap('toolbar-disabled-toggle')
reveal('icon-open-from-code')
assert node(tree(), 'icon-close').get('enabled') == 'false'
tap('icon-open-from-code'); absent('Duplicate')
wait('Menu opened 2, closed 2')
results['iconButtons'] = 'passed'
print('Icon buttons, open() and lifecycle events passed.', flush=True)

# Segment counts and colours, badges and the prominent icon button.
launch()
reveal('segment-counts-toggle'); tap('segment-counts-toggle')
reveal('Saved 3'); tap('Saved 3'); wait('Showing: saved')
screenshot('b11-android-segments')
reveal('fab')
assert abs(width_dp('fab') - 56) < 2, f'fab is {width_dp("fab")} dp wide'
# The badges sit above the button; on a short screen they can be scrolled off the top.
reveal('New'); reveal('Updating…')
screenshot('b11-android-badges-fab')
reveal('fab'); tap('fab'); wait('FAB pressed')
results['segmentsBadgesFab'] = 'passed'
print('Segment counts, badges and the prominent icon button passed.', flush=True)

# Expanding pills: selection, the selected pill opening, labels exposed while collapsed.
reveal('filter-tabs-recent')
assert node(tree(), 'filter-tabs-overview').get('selected') == 'true'
assert node(tree(), 'filter-tabs-recent').get('content-desc') == 'Recent, 3 of 5'
collapsed = width_dp('filter-tabs-recent')
tap('filter-tabs-recent', settle=1); wait('Filter: recent')
assert node(tree(), 'filter-tabs-recent').get('selected') == 'true'
assert node(tree(), 'filter-tabs-overview').get('selected') == 'false'
assert width_dp('filter-tabs-recent') > collapsed + 20, 'The selected pill did not open'
screenshot('b11-android-pills')
for value in ['favorites', 'shared', 'archive', 'overview']:
    reveal(f'filter-tabs-{value}'); tap(f'filter-tabs-{value}', settle=1); wait(f'Filter: {value}')
results['expandingPills'] = 'passed'
print('Expanding pills passed.', flush=True)

# Search field, submit, toast and focus from code.
launch()
reveal('open-search-demo', down=False); tap('open-search-demo')
wait('20 results')
tap('item-search')
adb('shell', 'input', 'text', 'ec'); wait('2 results')
adb('shell', 'input', 'text', 'h'); adb('shell', 'input', 'keyevent', 66)
wait('Submitted: ech'); wait('1 results')
screenshot('b11-android-search')
# Submitting hides the keyboard; the buttons pinned above it move down while it animates away.
for _ in range(10):
    if not keyboard_shown():
        break
    time.sleep(.5)
else:
    adb('shell', 'input', 'keyevent', 4)
time.sleep(1)
# The toast shows for 2 s, and on a slow emulator one tree read can take longer. Find the button
# once, then tap and read straight away, up to three times: each tap shows the toast again.
copy_x, copy_y = center('copy-action')
for attempt in range(3):
    adb('shell', 'input', 'tap', copy_x, copy_y)
    try:
        node(tree(), 'Copied 1 items')
        break
    except AssertionError:
        if attempt == 2:
            raise
# A second toast is captured for review.
adb('shell', 'input', 'tap', copy_x, copy_y); time.sleep(.3); screenshot('b11-android-toast')
time.sleep(2.5); absent('Copied 1 items', timeout=0)
tap('search-focus', settle=1)
assert keyboard_shown(), 'focus() did not raise the keyboard'
adb('shell', 'input', 'keyevent', 4)
results['searchToast'] = 'passed'
print('Search field, toast and focus passed.', flush=True)

# Tab image sources, per-tab colours and the Android bar and indicator colours.
launch()
tap('open-tabs-demo'); wait('Home screen')
reveal('tabs-brand-toggle'); tap('tabs-brand-toggle', settle=1)
tap('Library tab', settle=1); wait('Library screen')
night = 'yes' in adb('shell', 'cmd', 'uimode', 'night').decode()
background, indicator = ((0x1E, 0x1B, 0x16), (0x3A, 0x34, 0x28)) if night else ((0xF4, 0xF1, 0xEA), (0xE3, 0xDC, 0xCB))
x1, y1, x2, y2 = bounds(node(tree(), 'Library tab'))
icon_band = (x1, y1, x2, y1 + (y2 - y1) * 55 // 100)
image = screenshot('b11-android-tabs-library')
selected = pixels(image, icon_band, (0x2E, 0x7D, 0x32))
tap('Settings tab', settle=1); wait('Settings screen')
image = screenshot('b11-android-tabs-settings')
inactive = pixels(image, icon_band, (0x8A, 0x8F, 0x98))
bar = bounds(node(tree(), 'Home tab'))
assert selected > 150, f'Library selected artwork: {selected} green pixels'
assert inactive > 60, f'Library inactive artwork: {inactive} gray pixels'
assert selected > inactive * 1.3, f'Selected image should be the filled diamond ({selected} vs {inactive})'
sx1, sy1, sx2, sy2 = bounds(node(tree(), 'Settings tab'))
assert pixels(image, (sx1, sy1, sx2, sy2), (0xC6, 0x28, 0x28)) > 100, 'Settings should use its own red'
assert pixels(image, (sx1, sy1, sx2, sy2), indicator, 12) > 500, 'Indicator colour not applied'
assert pixels(image, (bar[0], bar[1], bar[2], bar[3]), background, 12) > 2000, 'Bar background colour not applied'
results['tabImagesAndColours'] = {'selectedGreen': selected, 'inactiveGray': inactive}
print(f'Tab image sources and colours passed ({selected} vs {inactive}).', flush=True)

(ROOT / 'artifacts/b11-android-features.json').write_text(json.dumps(results, indent=2) + '\n')
print('Android 0.1.3 feature checks passed.', flush=True)
