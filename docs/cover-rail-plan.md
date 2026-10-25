# The rail on the iPhone Duo's cover — the plan

2026-10-24. Branch `display-sleep` (uncommitted until Aman says). Aman, on his iPhone Duo with iOS
27.1 and a build from Xcode 27.1: "maybe we also move the keyboard and mouse and search buttons to
the duo side like on native apps", with a photo of Mail on the cover: its list in the 382 pt beside
the camera strip, and in the strip, under the clock and the battery ring, Back and More; at the
bottom, Search and Compose. His picks (2026-10-24): Keyboard and Mouse, then Apps (the drawer, with
its search field), Desktop and Settings; row 1 goes and Aa moves into Settings, as on an iPad.

The laptop split he also asked for ("Split View should scale the controls to be 1/2 screen and
display to be 1/2 screen when it's like a laptop") is docs/iphone-duo-plan.md's (b1), already built:
the picture above the fold's real band (0–455), the window bar, keys and trackpad from 496. It
compiles in only against the iOS 27.1 SDK; a 27.0 build runs in iOS's compatibility window
(871×669, sideways only) and never shows it.

## Facts

From docs/iphone-duo-plan.md (the iOS 27.1 simulator's probe; nothing here was measured on the
device yet): the cover upright is 466×678 pt; Sill gets a safe area of 84 at the right and 34 at the
bottom; the status bar shows there (decision 1 hid it on the inner display only), so the occlusions
are the camera (399.7, 29.3, 37×37) and the status box (382, 0, 84×170); with the status bar hidden
the box is 84×82. On its side the strip is at the left (678×466, leading 84) and the compact
landscape bar sits beside it, unchanged here. Mail's buttons in Aman's photo: about 46 pt round, the
first pair from about y 180, the last pair ending about 40 pt above the bottom edge.

Today's stream screen keeps the safe area but the bottom, so the phone's arrangement is laid out in
382×678 and the strip is black. `DuoLayout.of` reads any upright screen narrower than 600 pt as
`.outerPortrait`, and on a phone (`DuoLayout.phoneArrangement`) that is `PhonePortraitLayout`.

## Decisions

1. **Where the rail is known.** The stream screen's outer GeometryReader reads its trailing
   safe-area inset; on a phone held upright an inset of 60 pt or more is the cover's strip
   (`PhonePortraitLayout.rail(trailingInset:size:)`; a notch's insets are sideways, so no iPhone
   upright has one, and an iPad window that narrow is not the phone's arrangement). Then the screen
   takes the strip in (`ignoresSafeArea(edges: [.bottom, .trailing])`) and hands its width to the
   layout as `rail`. Nothing depends on the hinge or the fold: the rail is there from the first
   frame, and the harness's `-SillLayout 466x678` (trailing 84) draws it too.
2. **The page.** `PhonePortraitLayout(size:keyboard:rail:)`: every rect that was a function of the
   screen's width is now of the page's, `size.width − rail` (382 on the cover), so the picture, the
   strip, the keys and the trackpad are exactly what the 382 pt layout had. Row 1 is a row of no
   height under the picture's margin; the strip follows 10 pt under it (its thumbnails 24 pt from
   the picture, as from row 1's buttons before), and its 72 pt band goes to the trackpad (282 pt on
   the cover, 210 before). The Menus button keeps its place at the strip's end (a fifth of the row,
   under where Settings was). Larger Picture never applies (a hinge), and a keyboard given is ignored.
3. **The buttons** (`railButtons`, `RailButton` order): 44 pt round, centred across the strip (x 402
   on the cover); Keyboard and Mouse from 12 pt under the clock's block (`railTop` 170: the status
   box with the status bar showing; hidden, the box is 82 and the rail keeps its start, so nothing
   moves), 12 pt apart (182, 238); Apps, Desktop and Settings up from 12 pt above the home
   indicator (`railBottom` 46: 476, 532, 588, the last ending at 632 of 644). On a display too short
   for both groups the lower one gives way upward (none the cover is; `Tests/checks/phone-portrait`
   checks every height from 500). Symbols only (the strip is 84 pt): the accessibility labels and
   the Large Content Viewer name them.
4. **Mouse on the phone** (new there: the bar's Mouse button was sideways only, 2026-10-23): the
   same `StreamScreen.mouseMode` (`Sill.mouseMode`, remembered), the same invisible
   `TrackpadView` over the picture with `pictureTravel`, the direct-touch overlay under it taking
   no touch. Only with the rail: the halves and an iPhone's row 1 have no Mouse button, so the
   state never shows there.
5. **The drawer and the Settings panel** open over the picture from the top (y 8), the page wide,
   to the trackpad's bottom; the panel grows from the page's top-trailing corner, beside the rail.
   The dim and the catcher cover the whole page and none of the strip, so the rail stays live while
   either is open, as row 1 did (Apps closes the drawer, Settings the panel). Aa is the panel's Text
   Size row there (`textScale` handed to `HostSettingsPanel` with the rail; a phone's row 1 keeps
   its Aa).
6. **The tour** keeps its phone cards: Keyboard, Apps and Settings carry the same targets in the
   rail (`RailTourTarget`), and a target that is not on screen (Aa) is dropped by TourOverlay, so
   the bar card lights the strip and Keyboard. Its words ("Aa and Keyboard in the first row") are
   not the rail's yet: a task of its own, with the check's models.
7. **VoiceOver** reads the page top to bottom (the picture, the windows, the keys, the trackpad),
   then the rail's five.
8. **Everything else is unchanged**: every iPhone (no strip upright), the cover on its side, the
   inner display's three poses, an iPad window; `Tests/checks/phone-portrait`'s earlier cases pass
   as they are (the 382 pt cover among them), and the layout with `rail` 0 is the same struct.

## What changed

`iOSClient/PhonePortraitLayout.swift` (`rail`, `railButtons`, `RailButton`, `hasRail`, `row1Band`,
`fixedHeight(rail:)`, `rail(trailingInset:size:)`, `railButtons(rail:size:)`);
`iOSClient/PortraitStreamScreen.swift` (`rail`, `mouseMode`, no row 1 with the rail, the rail's
buttons, Mouse mode over the picture pane, `RailTourTarget`); `iOSClient/StreamScreen.swift` (the
outer reader, the trailing inset taken in on the cover, `portrait(metrics:largerKeyboard:rail:)`, a
DEBUG `rail:` console line); `Tests/checks/phone-portrait` (18 checks and a grid, 13 mutants R1–R13;
M3, M5, M19 and M26 follow their lines). No wire change, nothing on the Mac.

## Untested

Nothing here compiled or ran: the session's shell on Aman's Mac is a Linux VM without Swift. For
Aman, on the Duo closed, upright, streaming:

- U1 The strip holds five round buttons: Keyboard and Mouse under the clock, Apps, Desktop and
  Settings by the thumb, none on the camera or the clock, the last clear of the home indicator;
  Xcode's console says `rail: the cover's 84 pt strip at the right holds …`.
- U2 The page: no row of buttons under the picture; the thumbnails right under it; the trackpad
  taller by that row.
- U3 Each button: Keyboard brings the keyboard (and Hide Keyboard above it); Mouse lights and the
  picture becomes a trackpad (the arrow, a tap's click, a swipe across the picture); again, touch;
  Apps opens the drawer over the picture and closes it; Desktop; Settings opens over the picture,
  with Text Size in This iPhone, and closes.
- U4 A long press on a rail button shows its name large; VoiceOver reads the page, then the rail.
- U5 The tour (Settings › Take the Tour): the cards point at the rail's Keyboard, Apps and Settings.
- U6 On its side, and open in every pose: nothing changed. An iPad and a plain iPhone: nothing
  changed.
- U7 If the strip's block is taller or shorter than 170 on the device (the probe's number), the
  first button sits on the clock or too low: say by how much, and `railTop` moves.
- U8 The harness: `-SillLayout 466x678` draws the rail (whether `ignoresSafeArea` reaches through
  the harness's `safeAreaPadding`); if not, the harness alone needs a stand-in.

## Progress

- 2026-10-24 Design and build, uncompiled; this document.
