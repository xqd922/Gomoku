"""Stable tags need acceptance evidence or an explicitly recorded user waiver."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
version = re.search(r'^version:\s*(\d+\.\d+\.\d+)',
                    (root / 'apps/gomoku_app/pubspec.yaml').read_text(), re.M).group(1)
record = json.loads((root / f'docs/releases/v{version}-acceptance.json').read_text())
decision = record.get('releaseDecision', {})
waived = set(decision.get('waivedChecks', [])) if (
    decision.get('authorizedBy') == 'user' and decision.get('instruction')
) else set()
for gate in ('online', 'capacity60Minutes', 'backupRestore', 'existingServices',
             'androidManual', 'windowsRuntime', 'webRuntime'):
    check = record.get(gate, {})
    if gate in waived and check.get('status') == 'waived' and check.get('evidence'):
        print(f'User-authorized release before completing {gate}: {check["evidence"]}')
        continue
    if check.get('status') != 'passed' or not check.get('evidence'):
        raise SystemExit(f'Stable release blocked: {gate} acceptance is incomplete. Use an RC tag.')
print('Online and device acceptance recorded for', version)
