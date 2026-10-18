#!/bin/bash
# The Mac's display while a device is connected (docs/display-sleep-plan.md): DisplayPowerRule, pure.
# When the display is held awake and let go (the setting, who is connected, a synthetic host never),
# when a sleeping display is woken, the wait, and every line.
# Compiled with the files in module.txt as one module (../module.py drops their `import StreamProtocol`).
#   Tests/checks/display-power/run.sh             compile and run the check
#   Tests/checks/display-power/run.sh --mutants   one-line mutants of DisplayPower.swift; each must fail it
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/../common.sh"
if [ "${1:-}" = "--mutants" ]; then run_mutants python3 "$here/mutants.py" "$root"; exit; fi
python3 "$here/../module.py" "$name" "$root" "$out/check"
