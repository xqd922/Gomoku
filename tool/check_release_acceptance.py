"""A stable tag needs recorded online and physical-device acceptance."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
version = re.search(r'^version:\s*(\d+\.\d+\.\d+)',
                    (root / 'apps/gomoku_app/pubspec.yaml').read_text(), re.M).group(1)
record = json.loads((root / f'docs/releases/v{version}-acceptance.json').read_text())
for gate in ('online', 'capacity60Minutes', 'backupRestore', 'existingServices',
             'androidManual', 'windowsRuntime', 'webRuntime'):
    check = record.get(gate, {})
    if check.get('status') != 'passed' or not check.get('evidence'):
        raise SystemExit(f'Stable release blocked: {gate} acceptance is incomplete. Use an RC tag.')
print('Online and device acceptance recorded for', version)
