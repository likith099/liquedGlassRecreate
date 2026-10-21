"""Measure a compact title's return after search dismissal without XCTest idle waits.

Usage: python3 scripts/verify-search-title-video.py artifacts/name [--scale 3]
Requires the matching .mp4/.log/.start from record-ios-ui-test.sh and an
ALG-RECT search-title + ALG-MARK close in the test. Writes compact JSON; no PNGs.
"""
import argparse, json, re, shutil, subprocess
from pathlib import Path
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('base', type=Path)
p.add_argument('--mark', default='close')
p.add_argument('--rect', default='search-title')
p.add_argument('--scale', type=float, default=3)
p.add_argument('--max-gap', type=float, default=.12)
a = p.parse_args()
log = a.base.with_suffix('.log').read_text(errors='replace')
start = float(a.base.with_suffix('.start').read_text())
mark = float(re.search(rf'ALG-MARK {re.escape(a.mark)} ([\d.]+)', log)[1]) - start
rect = tuple(map(float, re.search(rf'ALG-RECT {re.escape(a.rect)} ([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+)', log).groups()))
x, y, w, h = [int(v * a.scale) for v in rect]
# YUV420 crops round odd origins/sizes; make the requested ROI explicit.
x, y, w, h = [v // 2 * 2 for v in (x, y, w, h)]
ffmpeg, ffprobe = [shutil.which(name) or '/opt/homebrew/bin/' + name for name in ('ffmpeg', 'ffprobe')]
video = str(a.base.with_suffix('.mp4'))
pts = subprocess.check_output([ffprobe, '-v', 'error', '-select_streams', 'v', '-show_entries', 'frame=pts_time', '-of', 'csv=p=0', video], text=True)
times = [float(v.strip(',')) for v in pts.split() if v.strip(',')]
proc = subprocess.Popen([ffmpeg, '-v', 'error', '-i', video, '-vf', f"crop={w}:{h}:{x}:{y},format=gray", '-fps_mode', 'passthrough', '-enc_time_base', '1:60000', '-f', 'rawvideo', '-'], stdout=subprocess.PIPE)
rows = []
for t in times:
    frame = proc.stdout.read(w*h)
    if len(frame) != w*h: raise RuntimeError('Recording ended before all timestamped frames were decoded')
    if not mark <= t <= mark + 3: continue
    rows.append({'t': round(t - mark, 4), 'ink': round(sum(v > 200 for v in frame) / len(frame), 4)})
assert proc.wait() == 0
visible = [i for i,r in enumerate(rows) if r['ink'] >= .06 and r['t'] >= .2]
first = visible[0] if visible else None
gaps, gap_start = [], None
for r in rows[first or 0:]:
    if r['ink'] < .06 and gap_start is None: gap_start = r['t']
    elif r['ink'] >= .06 and gap_start is not None:
        gaps.append([gap_start, r['t']]); gap_start = None
if gap_start is not None: gaps.append([gap_start, rows[-1]['t']])
max_gap = max((end-begin for begin,end in gaps), default=0)
report = {'first_visible': rows[first]['t'] if first is not None else None, 'longest_disappearance_after_return': round(max_gap, 4), 'gaps': gaps, 'samples': len(rows), 'rows': rows}
a.base.with_suffix('.' + a.mark + '.title.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k != 'rows'}))
assert first is not None and rows[first]['t'] <= 1.0, 'Title did not return within the dismissal'
assert max_gap <= a.max_gap, f'Title disappeared again for {max_gap:.3f}s after returning'
