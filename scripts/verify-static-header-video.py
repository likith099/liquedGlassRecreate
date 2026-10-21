"""Measure whether a header control stays still through a screen transition.

Usage: python3 scripts/verify-static-header-video.py artifacts/name --rect shared-back-all \
         --still push-item --still swipe-item --moves push-from-home [--scale 3]
Requires the .mp4/.log/.start from record-ios-ui-test.sh, the ALG-RECT and the ALG-MARKs.
For each mark, compares every frame in the window with the frame just before the mark (mean
absolute grey difference over the control's rect, 0-255). `--still` marks must stay below
--max-diff; `--moves` marks are positive controls that must exceed it. `--absent` marks require
the rect to stay dark (fraction of pixels brighter than 200 at most --max-ink), e.g. a compact
title that must not appear. Writes JSON; no PNGs.
"""
import argparse, json, re, shutil, subprocess
from pathlib import Path
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('base', type=Path)
p.add_argument('--rect', required=True)
p.add_argument('--still', action='append', default=[])
p.add_argument('--moves', action='append', default=[])
p.add_argument('--absent', action='append', default=[])
p.add_argument('--max-ink', type=float, default=.01)
p.add_argument('--window', type=float, default=1.2)
p.add_argument('--scale', type=float, default=3)
p.add_argument('--max-diff', type=float, default=4)
a = p.parse_args()
log = a.base.with_suffix('.log').read_text(errors='replace')
start = float(a.base.with_suffix('.start').read_text())
rect = tuple(map(float, re.search(rf'ALG-RECT {re.escape(a.rect)} ([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+)', log).groups()))
x, y, w, h = [int(v * a.scale) // 2 * 2 for v in rect]
marks = {name: float(re.search(rf'ALG-MARK {re.escape(name)} ([\d.]+)', log)[1]) - start for name in a.still + a.moves + a.absent}
ffmpeg, ffprobe = [shutil.which(name) or '/opt/homebrew/bin/' + name for name in ('ffmpeg', 'ffprobe')]
video = str(a.base.with_suffix('.mp4'))
pts = subprocess.check_output([ffprobe, '-v', 'error', '-select_streams', 'v', '-show_entries', 'frame=pts_time', '-of', 'csv=p=0', video], text=True)
times = [float(v.strip(',')) for v in pts.split() if v.strip(',')]
proc = subprocess.Popen([ffmpeg, '-v', 'error', '-i', video, '-vf', f"crop={w}:{h}:{x}:{y},format=gray", '-fps_mode', 'passthrough', '-enc_time_base', '1:60000', '-f', 'rawvideo', '-'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
reference, rows = {}, {name: [] for name in marks}
for t in times:
    frame = proc.stdout.read(w*h)
    if len(frame) != w*h: raise RuntimeError('Recording ended before all timestamped frames were decoded')
    for name, m in marks.items():
        if t < m: reference[name] = frame
        elif t <= m + a.window and name in reference:
            diff = sum(abs(p - q) for p, q in zip(frame, reference[name])) / len(frame)
            rows[name].append({'t': round(t - m, 4), 'diff': round(diff, 2), 'ink': round(sum(v > 200 for v in frame) / len(frame), 4)})
assert proc.wait() == 0
report = {name: {'max_diff': max((r['diff'] for r in rows[name]), default=None), 'max_ink': max((r['ink'] for r in rows[name]), default=None),
                 'samples': len(rows[name]), 'expect': 'still' if name in a.still else 'absent' if name in a.absent else 'moves',
                 'rows': rows[name]} for name in marks}
a.base.with_suffix('.' + a.rect + '.static.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({name: {k: v for k, v in r.items() if k != 'rows'} for name, r in report.items()}))
failures = []
for name, r in report.items():
    if r['samples'] <= 10: failures.append(f'{name}: too few frames in the window ({r["samples"]})')
    elif r['expect'] == 'still' and r['max_diff'] > a.max_diff: failures.append(f'{name}: changed by {r["max_diff"]} (> {a.max_diff})')
    elif r['expect'] == 'absent' and r['max_ink'] > a.max_ink: failures.append(f'{name}: something appeared ({r["max_ink"]} bright)')
    elif r['expect'] == 'moves' and r['max_diff'] <= a.max_diff: failures.append(f'{name}: positive control did not change ({r["max_diff"]})')
assert not failures, '; '.join(failures)
