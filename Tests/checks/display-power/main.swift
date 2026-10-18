// The Mac's display while a device is connected (docs/display-sleep-plan.md §2): DisplayPowerRule.
// IOKit is never called here: the check reads the rule and its words only.
import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print("\(ok ? "ok" : "FAIL") \(what)")
    if !ok { failures += 1 }
}
func eq<T: Equatable>(_ a: T, _ b: T, _ what: String) { check(a == b, "\(what): \(a)" + (a == b ? "" : " (want \(b))")) }

typealias R = DisplayPowerRule

// MARK: The hold

check(!R.wantsHold(enabled: true, devices: 0), "nobody connected: no hold")
check(R.wantsHold(enabled: true, devices: 1), "one device, the setting on: held")
check(R.wantsHold(enabled: true, devices: 3), "three devices: held")
check(!R.wantsHold(enabled: false, devices: 1), "the setting off: never held")
check(!R.wantsHold(enabled: false, devices: 0), "the setting off, nobody: no hold")

eq(R.holdChange(enabled: true, devices: 1, holding: false, synthetic: false), .hold, "the first device connects: hold")
eq(R.holdChange(enabled: true, devices: 2, holding: true, synthetic: false), nil, "a second device: nothing changes")
eq(R.holdChange(enabled: true, devices: 1, holding: true, synthetic: false), nil, "one leaves of two: still held")
eq(R.holdChange(enabled: true, devices: 0, holding: true, synthetic: false), .release, "the last device leaves: release")
eq(R.holdChange(enabled: true, devices: 0, holding: false, synthetic: false), nil, "nobody, not held: nothing")
eq(R.holdChange(enabled: false, devices: 1, holding: true, synthetic: false), .release, "the setting goes off while a device is connected: release at once")
eq(R.holdChange(enabled: true, devices: 1, holding: false, synthetic: false), .hold, "the setting comes on while a device is connected: hold at once")
eq(R.holdChange(enabled: false, devices: 1, holding: false, synthetic: false), nil, "a device connects with the setting off: nothing")
eq(R.holdChange(enabled: true, devices: 1, holding: false, synthetic: true), nil, "a synthetic host never holds")
eq(R.holdChange(enabled: true, devices: 0, holding: true, synthetic: true), nil, "a synthetic host never releases either (it never held)")

// Every state over the grid: the change applied leaves `holding` equal to what is wanted.
for enabled in [false, true] {
    for devices in 0...3 {
        for holding in [false, true] {
            var h = holding
            switch R.holdChange(enabled: enabled, devices: devices, holding: h, synthetic: false) {
            case .hold: h = true
            case .release: h = false
            case nil: break
            }
            check(h == R.wantsHold(enabled: enabled, devices: devices), "grid: enabled \(enabled), \(devices) devices, holding \(holding) → holding \(h)")
        }
    }
}

// MARK: The wake

check(R.wakes(enabled: true, asleep: true, synthetic: false), "asleep, the setting on: wake")
check(!R.wakes(enabled: true, asleep: false, synthetic: false), "awake: nothing to wake")
check(!R.wakes(enabled: false, asleep: true, synthetic: false), "the setting off: not woken")
check(!R.wakes(enabled: true, asleep: true, synthetic: true), "a synthetic host never wakes the display")
check(R.wakeWait >= 2 && R.wakeWait <= 5, "the wait for a woken display is a few seconds (\(R.wakeWait))")
check(R.wakePoll > 0 && R.wakePoll <= 0.1, "the display is looked at often while waiting (\(R.wakePoll))")
check(R.wakePoll < R.wakeWait, "the poll is shorter than the wait")

// MARK: Words

eq(R.holdReason, "Sill is streaming to a device", "the assertion's name, as pmset lists it")
check(R.heldLine.hasPrefix("Display: ") && R.heldLine.contains("kept awake"), "the held line: \(R.heldLine)")
check(R.releasedLine.hasPrefix("Display: ") && R.releasedLine.contains("may sleep again"), "the released line: \(R.releasedLine)")
check(R.heldLine != R.releasedLine, "the two hold lines differ")

eq(R.wokeLine(lit: 0.84, locked: false), "Display: it was asleep; woke it for a device (lit in 0.8 s).", "woke, lit, unlocked")
eq(R.wokeLine(lit: 1.26, locked: true),
   "Display: it was asleep; woke it for a device (lit in 1.3 s). This Mac is locked: unlock it to see it from the device.",
   "woke, lit, locked: the lock named")
eq(R.wokeLine(lit: nil, locked: false), "Display: it was asleep; woke it for a device, but it had not lit 3 s later.", "woke, not lit in time")
check(R.wokeLine(lit: nil, locked: true).hasSuffix("This Mac is locked: unlock it to see it from the device."), "not lit and locked: both said")
check(R.wokeLine(lit: nil, locked: false).contains("\(Int(R.wakeWait)) s"), "the not-lit line names the wait")
check(!R.wokeLine(lit: 0.5, locked: false).contains("locked"), "unlocked: the lock not mentioned")

check(R.leftAsleepLine.hasPrefix("Display: ") && R.leftAsleepLine.contains("Keep display awake is off"), "the setting-off line names the setting: \(R.leftAsleepLine)")
check(R.leftAsleepLine.contains("sees nothing"), "the setting-off line says what the device gets")

print(failures == 0 ? "All passed." : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
