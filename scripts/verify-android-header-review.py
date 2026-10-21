"""Material header: collapse, slots, nested navigation, scopes and refresh integration."""
import io, runpy, subprocess, time
from PIL import Image
from pathlib import Path
h = runpy.run_path(str(Path(__file__).with_name('verify-android-menu.py')))
adb, tree, find, bounds = (h[k] for k in ('adb', 'tree', 'find', 'bounds'))
def tap(value, result=False):
    root = tree()
    node = next((n for n in root.iter('node') if n.get('content-desc') == value and n.get('class') == 'android.widget.Button'), None) if result else find(root, value)
    assert node is not None, f'Result button {value} not visible'
    x1,y1,x2,y2 = bounds(node); adb('shell','input','tap',(x1+x2)//2,(y1+y2)//2); time.sleep(.6)
def option(value):
    tap('review-options'); tap(value)
tap('open-search-demo'); tap('open-scroll-header'); tap('nav-review')
find(tree(), 'review-close')
adb('shell','input','swipe',650,1800,650,600,450); time.sleep(.6)
# Hard band (edgeEffect.band): once the list has scrolled, the app bar takes the band colour.
def bar_rgb():
    png = subprocess.check_output([h['ADB'], '-s', h['SERIAL'], 'exec-out', 'screencap', '-p'])
    image = Image.open(io.BytesIO(png)).convert('RGB')
    x1, y1, x2, y2 = bounds(find(tree(), 'review-options'))
    pixels = list(image.crop((x1 - 140, y1 + 8, x1 - 60, y2 - 8)).getdata())
    return [sum(p[i] for p in pixels) / len(pixels) for i in range(3)]
bands = {'default': bar_rgb()}
for name in ('lighter', 'tinted', 'system', 'default'):
    option(f'Hard band: {name}'); time.sleep(.6); bands[name + ('-again' if name == 'default' else '')] = bar_rgb()
print('band colours', {k: [round(c) for c in v] for k, v in bands.items()})
assert bands['tinted'][2] > bands['tinted'][0] + 10, 'The band takes the app colour'
assert max(abs(a - b) for a, b in zip(bands['default'], bands['system'])) > 3, 'The default band changes the bar colour; system keeps it'
assert max(abs(a - b) for a, b in zip(bands['default'], bands['default-again'])) <= 2, 'The default band returns'
tap('review-top'); find(tree(),'Contact 1')
option('Large in bar'); option('Show pinned filter'); find(tree(),'Filter: all')
option('Custom title and subtitles'); find(tree(),'◉  Custom contact')
option('Text title'); tap('review-top')
tap('review-search'); tap('review-search-field')
for query in ('Contact 11', 'Contact 1'):
    adb('shell','input','text',query.replace(' ', '%s')); time.sleep(.5)
    field = find(tree(), 'review-search-field')
    assert field.get('text') == query, f"Search dropped keyboard input: expected {query!r}, got {field.get('text')!r}"
    if query == 'Contact 11': tap('Clear text')
tap('Contact 1', result=True); find(tree(),'Newest message')
tap('review-detail-back'); find(tree(),'review-search-field')
tap('Close search')
assert not any(n.get('resource-id') == 'review-search-field' for n in tree().iter('node')), 'Dismissed search reopened'
tap('review-close'); find(tree(),'nav-add')
adb('shell','input','keyevent','4'); time.sleep(.5); find(tree(),'open-scroll-header')
print('Header review passed: Material collapse/actions, custom slots, search, nested back and system Back')
