"""Focused header interaction and blur-vs-solid backdrop check."""
import io
import runpy
import time
from pathlib import Path
from PIL import Image
h = runpy.run_path(str(Path(__file__).with_name('verify-android-menu.py')))
adb, tree, find, bounds = (h[k] for k in ('adb', 'tree', 'find', 'bounds'))
def tap(value):
    try: node = find(tree(), value)
    except AssertionError: node = h['reveal'](value)
    x1,y1,x2,y2 = bounds(node)
    adb('shell','input','tap',(x1+x2)//2,(y1+y2)//2); time.sleep(.5)
def color_pixels():
    x1,y1,x2,y2 = bounds(find(tree(),'contacts-header'))
    image = Image.open(io.BytesIO(adb('exec-out','screencap','-p'))).convert('RGB')
    return sum(r > g + 18 and r > b + 12 for r,g,b in image.crop((x1,y1,x2,y2)).getdata())
tap('Navigation & headers'); tap('nav-blur-only'); tap('header-scroll')
time.sleep(.8)
blur = color_pixels()
tap('header-add'); assert '21' in find(tree(),'header-added').get('text','')
tap('header-fallback'); solid = color_pixels()
assert blur > solid + 20, f'Uniform backdrop blur must show underlying avatar colour; blur={blur}, solid={solid}'
tap('header-reset'); tap('close-scroll-header'); tap('nav-blur-only')
find(tree(),'contacts-title')
print(f'Scroll header passed: blur coloured pixels={blur}, solid={solid}; actions and remount passed')
