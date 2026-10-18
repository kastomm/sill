# The Mac's display while a device is connected

Branch `display-sleep` from main at 5c323e6 (2026-10-17). Aman: "when the screen goes black on the
Mac (display shuts off) then the Sill app doesn't work, it just shows a black screen. Also Sill
doesn't wake the computer from sleep." Host only: no wire change, nothing on the device.

## 1. What happens today

Sill holds the Mac from nothing but App Nap and, for a device connected from away, idle *system*
sleep (`AppModel.holdAppNapOff`: `.userInitiated` with a remote device, `.userInitiatedAllowingIdleSystemSleep`
at home). Nothing holds the *display*: after the Energy setting's minutes it goes dark whether or not
an iPad is streaming. A sleeping display is not composited, so ScreenCaptureKit delivers black frames
or none (which of the two macOS does was never measured: docs/reconnect-after-sleep-plan.md's R6),
and the device shows black. A device that connects while the display is already dark gets the same.

Waking the Mac itself from system sleep is a different matter: no app can do it from inside the
sleeping Mac, and an iOS app cannot send Wake-on-LAN over Wi-Fi in general. What works is the
Bonjour Sleep Proxy (an Apple TV, HomePod or another Mac on the network, with the Mac's "Wake for
network access" on): the sleeping Mac's Bonjour record stays registered and a connection to it wakes
it. Main already redials a listed Mac at 5, 10, 20 and 30 s (issue #69, PR #77) so that has a chance
to fire; this change adds nothing there. Holding the display awake while a device is connected also
keeps the Mac from idle system sleep, so a Mac left with a device connected stays reachable.

## 2. The change

- `HostConfig.keepDisplayAwake` (on in `standard`). The Mac's alone, like Share clipboard: absent from
  `StreamSettings`, `HostSettingsChange`, `DeviceSettings.accepted`, `applying` and `restartNeeded`;
  applied at once by `setTarget`, never between pipelines. The CLI's `--let-display-sleep` turns it
  off for a run; Sill.app saves it under `keepDisplayAwake` and shows it in Settings › General as
  "Keep the display awake while a device is connected".
- `DisplayPower` (Sources/SillHost/DisplayPower.swift, main actor): while the setting is on and at
  least one device is connected (`StreamServer.onClientCountChanged`, which counts home and remote
  clients alike), it holds one IOKit assertion, `kIOPMAssertionTypePreventUserIdleDisplaySleep`
  ("Sill is streaming to a device"), the kind a video player holds; released when the last device
  leaves, when the setting goes off, and at Quit. The display may still be put to sleep by hand
  (the power button, a hot corner, ⌃⇧⏏): an assertion only holds off *idle* sleep.
- Waking: when a device connects while the display is asleep (`CGDisplayIsAsleep` on the main
  display), `IOPMAssertionDeclareUserActivity` (`kIOPMUserActiveLocal`) wakes it, as a key press
  would, and `select` of a source waits up to 3 s for the display to light before capture starts, so
  the first picture is not a black one. One line: "Display: it was asleep; woke it for a device (lit
  in 0.8 s)." With the setting off nothing is woken, and one line says why the device sees nothing.
- The lock screen: a Mac set to require its password after display sleep shows the lock screen once
  woken, and only its owner can unlock it. Sill logs it ("… this Mac is locked: unlock it to see it
  from the device", `SessionLock`) and otherwise streams whatever macOS lets it capture.
- `DisplayPowerRule` (pure, Foundation only): whether to hold or release, whether to wake, the words;
  `Tests/checks/display-power`, in CI and its mutants matrix.
- A synthetic host (`--synthetic`, the test hosts) never touches the display: no assertion, no wake.

## 3. Open questions, with the default taken

1. Hold while connected, or only while a source streams? Connected: a device on the connect panel
   with nothing picked still shows thumbnails read from the screen, and a device left connected is
   what the owner wants reachable. (The idle host with nobody connected holds nothing, as before.)
2. The switch covers the hold and the wake together. Off is today's behaviour.
3. Nothing is sent to the device about a locked Mac: the host's log line only. A later change could
   carry it in the window list.
4. No restart of a running stream when the display wakes by itself later (the owner pressed a key):
   if capture had stopped (`capture.onStopped` → `select(.none)`), the device asks for the Desktop
   again by itself (`DiscoveryPolicy.autoDesktop`); if it ran on black frames, the next frames are
   the lit display's.

## 4. Untested, for Aman (nothing here could run: the linked shell is a Linux VM, no Swift)

1. Build (`swift build -c release`; `Scripts/make-app.sh --install --open`) and
   `Tests/checks/run-all.sh display-power away-quality` (then `--mutants` for display-power).
2. With the iPad streaming the Desktop, set System Settings › Lock Screen › "Turn display off" to
   1 minute and wait two: the display stays on. Sill.log: "Display: kept awake while a device is
   connected." once, and `pmset -g assertions` lists `PreventUserIdleDisplaySleep` named "Sill is
   streaming to a device". Disconnect: the line "Display: may sleep again", the assertion gone, the
   display dark a minute later.
3. Display asleep (`pmset displaysleepnow`, or wait), then connect from the iPad: the display lights
   within about a second, Sill.log "Display: it was asleep; woke it for a device (lit in N s)", and the
   picture on the iPad is the Desktop, not black. If the Mac asks for its password: the "this Mac is
   locked" line, and what the iPad shows (the lock screen, or black) decides open question 3.
4. Settings › General's switch off while streaming: the assertion gone at once (`pmset -g
   assertions`), the display dark after the minute, and the iPad's picture then (black, or frozen:
   R6's answer, for the plan's §1). Back on: held again at once.
5. The CLI: `swift run -c release SillHost` holds it with a device; `--let-display-sleep` never.
6. The Mac asleep (not just its display), the iPad trying: whether it wakes depends on a sleep proxy
   (`dns-sd -B _sleep-proxy._udp` on the Mac lists one) and "Wake for network access"; without one
   nothing in Sill can wake it (support.html says so).

## 5. Results

(none yet)
