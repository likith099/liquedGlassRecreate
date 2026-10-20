"""Measure a red badge through a recorded press/release, including position jumps.

Requires ffmpeg and numpy. Select an interval where the badge is always on screen
and a crop containing only that badge (x y width height, in recording pixels).
"""
import argparse
import json
import subprocess

import numpy as np

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('video')
p.add_argument('--start', type=float, required=True)
p.add_argument('--duration', type=float, required=True)
p.add_argument('--crop', type=int, nargs=4, required=True)
p.add_argument('--max-step', type=float, default=12,
               help='Largest allowed one-frame center or size change, in pixels')
p.add_argument('--max-size', type=float,
               help='Largest allowed badge width or height, in pixels (detects gradual ballooning)')
p.add_argument('--output', required=True)
args = p.parse_args()
x0, y0, width, height = args.crop
# Decode before seeking: Simulator VFR recordings can skip the start of the
# requested interval with input-side seeking, invalidating frame timestamps.
process = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', args.video,
    '-ss', str(args.start), '-t', str(args.duration), '-vf',
    f'fps=60,crop={width}:{height}:{x0}:{y0}', '-f', 'rawvideo',
    '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
frames, missing, jumps, oversized = [], [], [], []
previous = None
while True:
    data = process.stdout.read(width * height * 3)
    if not data:
        break
    if len(data) != width * height * 3:
        raise RuntimeError('Incomplete decoded frame')
    image = np.frombuffer(data, np.uint8).reshape(height, width, 3)
    y, x = np.where((image[:, :, 0] > 170) & (image[:, :, 1] < 115) & (image[:, :, 2] < 130))
    time = round(args.start + len(frames) / 60, 4)
    if not len(x):
        missing.append(time); frames.append({'time': time, 'badge': None})
        previous = None
        continue
    values = np.array([(x.min() + x.max()) / 2 + x0,
        (y.min() + y.max()) / 2 + y0, x.max() - x.min() + 1, y.max() - y.min() + 1])
    if args.max_size is not None and values[2:].max() > args.max_size:
        oversized.append({'time': time, 'size_wh': values[2:].tolist()})
    if previous is not None:
        delta = np.abs(values - previous)
        if delta.max() > args.max_step:
            jumps.append({'time': time, 'delta_xywh': delta.tolist()})
    frames.append({'time': time, 'badge': values.tolist()})
    previous = values
if process.wait() != 0:
    raise RuntimeError('ffmpeg failed')
summary = {'samples_at_60fps': len(frames), 'missing_frames': len(missing),
    'jumps': jumps, 'max_allowed_step_pixels': args.max_step,
    'oversized_frames': len(oversized), 'max_allowed_size_pixels': args.max_size}
with open(args.output, 'w') as output:
    json.dump({'summary': summary, 'missing_times': missing, 'oversized': oversized, 'frames': frames}, output)
print(json.dumps(summary))
if not frames or missing or jumps or oversized:
    raise SystemExit(1)
