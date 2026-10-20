"""Navigation fallback: actions, menus, controlled search, and return from standalone blur."""
import runpy, time
from pathlib import Path
h = runpy.run_path(str(Path(__file__).with_name('verify-android-menu.py')))
adb, tree, find, bounds = (h[k] for k in ('adb', 'tree', 'find', 'bounds'))
def tap(value):
    try: node = find(tree(), value)
    except AssertionError: node = h['reveal'](value)
    x1,y1,x2,y2 = bounds(node); adb('shell','input','tap',(x1+x2)//2,(y1+y2)//2); time.sleep(.5)
tap('open-search-demo'); tap('open-scroll-header'); tap('nav-add')
assert '21' in find(tree(),'nav-status').get('text','')
tap('nav-more'); tap('Mark all read')
assert 'All marked read' in find(tree(),'nav-status').get('text','')
tap('nav-search-toggle'); tap('Find contacts'); time.sleep(.6); tap('navigation-search'); adb('shell','input','text','Maya'); time.sleep(.6)
find(tree(),'Maya Chen')
assert all(node.get('text') != 'Noah Williams' for node in tree().iter('node'))
tap('Cancel'); find(tree(),'Noah Williams')
tap('navigation-back'); tap('open-scroll-header'); tap('nav-blur-only'); tap('close-scroll-header')
find(tree(),'nav-add')
print('Navigation passed: add, menu, search filtering, back and standalone blur return')
