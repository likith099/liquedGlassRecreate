"""Verify the installed B2 demo: native selection and actual React Navigation state."""
import json
from pathlib import Path
import runpy
import time

ROOT = Path(__file__).resolve().parent.parent
h = runpy.run_path(str(ROOT/'scripts/verify-android-menu.py'))
adb, tree, find, bounds = [h[key] for key in ['adb','tree','find','bounds']]
adb('shell','am','start','-S','-n','com.liquidglasslab/.MainActivity')
time.sleep(3)

def node(root, value):
    try: return find(root, value)
    except AssertionError:
        for n in root.iter('node'):
            if n.get('content-desc', '').startswith(value + ','): return n
        raise

def tap(value):
    n=node(tree(),value); x1,y1,x2,y2=bounds(n)
    adb('shell','input','tap',(x1+x2)//2,(y1+y2)//2);time.sleep(.4)

def visible(value):
    for _ in range(6):
        root=tree()
        try:
            n=node(root,value); x1,y1,x2,y2=bounds(n)
            if y2>y1: return n
        except AssertionError: pass
        _,_,w,height=bounds(root.find('node'))
        adb('shell','input','swipe',w//2,int(height*.7),w//2,int(height*.4),350)
    raise AssertionError(f'{value} not visible')

def screen(name):
    assert node(tree(),f'{name} screen') is not None

def selected(name):
    n=node(tree(),f'{name} tab')
    assert n.get('selected')=='true' or n.get('checked')=='true', f'{name} is not selected'

def toggle(id): visible(id);tap(id)

visible('open-tabs-demo');tap('open-tabs-demo');screen('Home');selected('Home')
tap('screen-increment')
tap('Library tab');screen('Library');selected('Library')
tap('Home tab');screen('Home')
assert find(tree(),'screen-counter').get('text')=='Home count: 1'
tap('Home tab')
assert find(tree(),'tab-event-count').get('text')=='Tab events: 3'
print('Native selection, retained screen state and reselection passed.',flush=True)
toggle('tabs-reject-toggle');tap('Inbox tab');screen('Home');selected('Home')
assert find(tree(),'tab-event').get('text')=='Prevented: Inbox'
toggle('tabs-reject-toggle');toggle('tabs-inbox-disabled-toggle')
assert node(tree(),'Inbox tab').get('enabled')=='false'
toggle('tabs-inbox-disabled-toggle');toggle('tabs-disabled-toggle')
assert node(tree(),'Library tab').get('enabled')=='false'
tap('tabs-go-inbox');screen('Inbox');selected('Inbox')
toggle('tabs-disabled-toggle')
old_home=bounds(node(tree(),'Home tab'))[0]
toggle('tabs-reverse-toggle');selected('Inbox')
assert bounds(node(tree(),'Home tab'))[0]>old_home
toggle('tabs-replace-toggle')
assert node(tree(),'Search tab') is not None
tap('Search tab');screen('Search');selected('Search')
root=tree(); inbox=node(root,'Inbox tab')
assert '3' in inbox.get('content-desc',''), 'Numeric badge should be exposed by the native control'
(ROOT/'artifacts/b2-android-tabs.png').write_bytes(adb('exec-out','screencap','-p'))
toggle('tabs-badges-toggle')
assert '3' not in node(tree(),'Inbox tab').get('content-desc','')
(ROOT/'artifacts/b2-android-no-badges.png').write_bytes(adb('exec-out','screencap','-p'))
print('Rejection, disabled, programmatic selection, reorder/replacement and badges passed.',flush=True)
adb('shell','input','keyevent',4);time.sleep(.5);screen('Inbox');selected('Inbox')
tap('close-tabs-demo');tap('open-tabs-demo');screen('Home');selected('Home')
(ROOT/'artifacts/b2-android-verification.json').write_text(json.dumps({key:'passed' for key in [
 'selection','reselection','retainedState','preventDefault','disabled','programmaticSelection',
 'reorder','replacement','badges','backNavigation','remount']},indent=2)+'\n')
print('Android B2 checks passed.',flush=True)
