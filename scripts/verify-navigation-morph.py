"""Check the actual package's DEBUG-only native morph trace; no screenshot ingestion needed."""
import json, sys
from pathlib import Path
report = json.loads(Path(sys.argv[1]).read_text())
rows = report['rows']
assert len(rows) == 121, len(rows)
assert all(r['alpha'] == 1 and r['sameFont'] == 1 for r in rows), 'Raster/font/brightness changed'
assert len({r['boundsWidth'] for r in rows}) == 1, 'Text reflowed during scroll'
assert all(b['scale'] <= a['scale'] + 0.00001 for a,b in zip(rows,rows[1:])), 'Scale reversed'
assert all(b['y'] <= a['y'] + 0.34 for a,b in zip(rows,rows[1:])), 'Vertical path reversed'
assert all(r['rasterScale'] * r['scale'] >= 2.99 for r in rows), 'Insufficient raster density'
assert report['passes'] <= 121 * 5, f"Runaway layout: {report['passes']} passes"
print(f"Morph passed: {len(rows)} states, constant raster/font/alpha, monotonic scale/path; {report['passes']} layout passes")
