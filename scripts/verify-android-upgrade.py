"""Focused 0.2.0 controls check. Run only after shutting down all iOS simulators."""
import io
from pathlib import Path
import runpy
import time
from PIL import Image
h = runpy.run_path(str(Path(__file__).with_name('verify-android-menu.py')))
adb, tree, find, bounds = (h[k] for k in ('adb', 'tree', 'find', 'bounds'))
def tap(value):
    try: node = find(tree(), value)
    except AssertionError: node = h['reveal'](value)
    x1, y1, x2, y2 = bounds(node)
    adb('shell', 'input', 'tap', (x1+x2)//2, (y1+y2)//2)
    time.sleep(.6)
def badge_box(node, match, margin=60):
    """Pixel bounding box (width, height, centre x/y relative to the node) of matching pixels near a node."""
    x1, y1, x2, y2 = bounds(node)
    image = Image.open(io.BytesIO(adb('exec-out', 'screencap', '-p'))).convert('RGB')
    left, top = max(0, x1 - margin), max(0, y1 - margin)
    crop = image.crop((left, top, min(image.width, x2 + margin), min(image.height, y2 + margin)))
    xs, ys = [], []
    for y in range(crop.height):
        for x in range(crop.width):
            if match(*crop.getpixel((x, y))): xs.append(x); ys.append(y)
    assert xs, f'No badge pixels near {node.get("resource-id")}'
    return (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1,
            (min(xs) + max(xs)) / 2 + left - x1, (min(ys) + max(ys)) / 2 + top - y1)
def badges():
    """Dot, text and capped badges: spoken labels and rendered size/colour (density from the 44 dp control)."""
    red = lambda r, g, b: r > 170 and g < 90 and b < 90
    h['reveal']('upgrade-badge-cap')
    time.sleep(1.5)  # let the pushed screen and its badges finish drawing before measuring pixels
    dot = find(tree(), 'upgrade-badge-dot')
    root = tree()
    assert find(root, 'upgrade-badge-dot').get('content-desc') == 'Inbox, New'
    assert find(root, 'upgrade-badge-text').get('content-desc') == 'Updates, New'
    assert find(root, 'upgrade-badge-cap').get('content-desc') == 'Messages, 120 unread messages'
    assert find(root, 'upgrade-pill-recent').get('content-desc').endswith(', New')
    dp = (bounds(dot)[2] - bounds(dot)[0]) / 44
    w, hgt, cx, cy = badge_box(dot, red)
    assert abs(w - 8 * dp) <= 2 * dp and abs(hgt - 8 * dp) <= 2 * dp, ('dot must be an 8 dp circle', w, hgt)
    w, hgt, _, _ = badge_box(find(root, 'upgrade-badge-text'), lambda r, g, b: r > 200 and g > 170 and b < 90)
    assert abs(hgt - 18 * dp) <= 2 * dp and w > 20 * dp, ('yellow text badge', w, hgt)
    w, hgt, _, _ = badge_box(find(root, 'upgrade-badge-cap'), lambda r, g, b: r < 70 and 100 < g < 170 and b > 200)
    assert abs(hgt - 18 * dp) <= 2 * dp and w > 24 * dp, ('blue 99+ badge', w, hgt)
    # Narrow margin: the neighbouring Saved pill's red badge is only 10 dp away.
    w, hgt, _, _ = badge_box(find(root, 'upgrade-pill-recent'), red, margin=12)
    assert abs(w - 8 * dp) <= 2 * dp and abs(hgt - 8 * dp) <= 2 * dp, ('pill dot', w, hgt)
def main():
    adb('shell', 'am', 'start', '-S', '-n', 'com.liquidglasslab/.MainActivity')
    for _ in range(30):
        try:
            find(tree(), 'open-upgrade-demo'); break
        except AssertionError:
            time.sleep(1)
    tap('open-upgrade-demo')
    badges()
    h['reveal']('upgrade-share')
    tap('upgrade-share')
    assert 'share' in find(tree(), 'upgrade-status').get('text', '')
    tap('upgrade-more'); tap('Pin item')
    assert 'pin' in find(tree(), 'upgrade-status').get('text', '')
    tap('upgrade-pill-saved')
    assert 'saved' in find(tree(), 'upgrade-status').get('text', '')
    # The morph keeps one capsule anchored to its trailing edge: it widens for "Done" and returns to
    # the 44 dp circle, with the same right edge both ways (no jump or clipped intermediate frame).
    rest = bounds(find(tree(), 'upgrade-morph'))
    for _ in range(2):
        tap('upgrade-morph'); time.sleep(.5)
        opened = find(tree(), 'upgrade-morph')
        assert 'Done' in opened.get('content-desc', '')
        wide = bounds(opened)
        assert wide[2] - wide[0] > rest[2] - rest[0] + 20, (rest, wide)
        assert abs(wide[2] - rest[2]) <= 2, (rest, wide)
        tap('upgrade-morph'); time.sleep(.5)
        closed = bounds(find(tree(), 'upgrade-morph'))
        assert abs((closed[2] - closed[0]) - (rest[2] - rest[0])) <= 2 and abs(closed[2] - rest[2]) <= 2, (rest, closed)
    tap('upgrade-morph'); time.sleep(.5)
    assert 'Done' in find(tree(), 'upgrade-morph').get('content-desc', '')
    tap('upgrade-toggle-presence')
    assert 'Exits: 1' in find(tree(), 'upgrade-exits').get('text', '')
    h['reveal']('upgrade-header-primary')
    for _ in range(2):
        tap('upgrade-header-primary')
        assert find(tree(), 'upgrade-header-primary').get('content-desc') == 'Done'
        find(tree(), 'upgrade-header-back')
        tap('upgrade-header-primary')
        assert find(tree(), 'upgrade-header-primary').get('content-desc') == 'More'
        assert not any(node.get('resource-id') == 'upgrade-header-back' for node in tree().iter('node'))
    print('0.2.0 Android controls passed')
if __name__ == '__main__': main()
