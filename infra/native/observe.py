#!/usr/bin/env python3
"""Observe service resources without logging environment variables or accounts."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

duration = int(sys.argv[1]) if len(sys.argv) > 1 else 3660
output = Path('/var/lib/gomoku/capacity-observation.json')
samples = []
started = time.time()
units = ['gomoku', 'postgresql@17-main', 'redis-server', 'caddy', 'haproxy', 'xray']
while time.time() - started < duration:
    sample = {'elapsedSeconds': round(time.time() - started),
              'freeDiskMiB': shutil.disk_usage('/').free // (1024 * 1024), 'units': {}}
    for unit in units:
        values = subprocess.check_output(['systemctl', 'show', unit, '-p', 'ActiveState',
                    '-p', 'MainPID', '-p', 'NRestarts', '-p', 'MemoryCurrent', '-p', 'Result'], text=True)
        sample['units'][unit] = dict(line.split('=', 1) for line in values.splitlines() if '=' in line)
    sample['memoryKiB'] = {line.split(':')[0]: int(line.split()[1])
                          for line in Path('/proc/meminfo').read_text().splitlines()
                          if line.startswith(('MemAvailable:', 'SwapFree:', 'SwapTotal:'))}
    samples.append(sample)
    output.write_text(json.dumps({'startedAtEpoch': started, 'samples': samples}, indent=2))
    time.sleep(15)
print('Resource observation completed; no credentials were collected.')
