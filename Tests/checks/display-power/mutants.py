"""DisplayPowerRule mutants (docs/display-sleep-plan.md): each must compile and make display-power/main.swift
fail. usage: mutants.py ROOT"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import module
F = "Sources/SillHost/DisplayPower.swift"
M = [
    ("held with nobody connected", F, "package static func wantsHold(enabled: Bool, devices: Int) -> Bool { enabled && devices > 0 }",
     "package static func wantsHold(enabled: Bool, devices: Int) -> Bool { enabled }"),
    ("held with the setting off", F, "package static func wantsHold(enabled: Bool, devices: Int) -> Bool { enabled && devices > 0 }",
     "package static func wantsHold(enabled: Bool, devices: Int) -> Bool { devices > 0 }"),
    ("a synthetic host holds", F, "        guard !synthetic else { return nil }\n        let want = wantsHold", "        let want = wantsHold"),
    ("hold and release swapped", F, "        return want ? .hold : .release\n", "        return want ? .release : .hold\n"),
    ("a change reported when nothing changes", F, "        if want == holding { return nil }\n", ""),
    ("woken with the setting off", F, "        !synthetic && enabled && asleep\n", "        !synthetic && asleep\n"),
    ("woken when awake", F, "        !synthetic && enabled && asleep\n", "        !synthetic && enabled\n"),
    ("a synthetic host wakes", F, "        !synthetic && enabled && asleep\n", "        enabled && asleep\n"),
    ("a wait of a minute", F, "package static let wakeWait: TimeInterval = 3", "package static let wakeWait: TimeInterval = 60"),
    ("a poll slower than the wait", F, "package static let wakePoll: TimeInterval = 0.05", "package static let wakePoll: TimeInterval = 5"),
    ("the lock unsaid", F, '        if locked { line += " This Mac is locked: unlock it to see it from the device." }\n', ""),
    ("the lock said whatever", F, '        if locked { line += " This Mac is locked', '        if !locked { line += " This Mac is locked'),
    ("the not-lit case reads as lit", F, '            line += ", but it had not lit \\(Int(wakeWait)) s later."', '            line += " (lit in 0.0 s)."'),
    ("the setting-off line does not name the setting", F, "Keep display awake is off, so it stays dark", "it stays dark"),
    ("the released line is the held one", F, 'package static let releasedLine = "Display: may sleep again (no device connected)."',
     'package static let releasedLine = "Display: kept awake while a device is connected."'),
]
sys.exit(0 if module.mutate("display-power", M, sys.argv[1]) else 1)
