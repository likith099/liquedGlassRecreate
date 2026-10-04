# Message menu presentation research

September 30, 2026. Scope: the 0.1.6 owner's collapsing entrance/exit, imperfect message lift and
occasional menu overlap. The native drag between rows is accepted and must be preserved.

## Which native API fits?

| Approach | What it provides | Suitability |
| --- | --- | --- |
| `UIContextMenuInteraction` + `UIMenu` | Long press, targeted content preview, native menu rows and gesture tracking | Best public foundation for message actions |
| `UIButton.menu` + `performPrimaryAction()` | A button's menu, with presentation tied to its anchor | Appropriate for toolbar buttons; a large invisible panel anchor has a different return morph |
| `UIEditMenuInteraction` | Editing commands around a text selection or target rectangle | Appropriate for selecting/copying text; does not supply the rich message preview interaction |
| SwiftUI `contextMenu(menuItems:preview:)` | A contextual menu with a custom preview | Another public entry point; no documented below-only placement control |
| Custom overlay and rows | App-controlled layout and animation | Would replace the accepted native drag tracking; conflicts with the package's native-component policy |

Apple's [context-menu sample](https://developer.apple.com/documentation/uikit/adding-context-menus-in-your-app)
separates the content preview controller from `UITargetedPreview`, which describes the transition
source. The [interaction documentation](https://developer.apple.com/documentation/uikit/uicontextmenuinteraction)
assigns menu interactions to UIKit. [WWDC19](https://developer.apple.com/videos/play/wwdc2019/224/)
introduces this model, and [WWDC20](https://developer.apple.com/videos/play/wwdc2020/10052/) explains
button menu presentation. A `UIMenu` is a menu description, not a freestanding view with an
app-controlled frame.

[Edit menus](https://developer.apple.com/documentation/uikit/uieditmenuinteraction) adapt to text
editing and input method. The [SwiftUI preview modifier](https://developer.apple.com/documentation/swiftui/view/contextmenu(menuitems:preview:))
does not document an alternative placement contract.

## Findings in 0.1.6

The `below` path returned an invisible view for highlight, a padded snapshot controller for the
opened preview, and the real content with an enlarged outline for dismissal. A separate 100 ms
animation hid the source; dismissal restored it before the return completed. These are mismatched
transition inputs, not an Apple guarantee of Messages behavior. They are a plausible contributor
to the reported morph; the report does not establish the sole cause in the consumer app.

The revised path uses the real content and the same visible path for highlight and dismissal,
including the iOS 16+ delegate methods. It removes the invisible stand-in and independent alpha
animation. UIKit owns the lift, source visibility and return. Preview-property changes invalidate
the current menu revision, and menu order is fixed on iOS 16+. Native rows, submenus, disabled
actions, material and drag tracking remain UIKit's.

Apple documents [visiblePath](https://developer.apple.com/documentation/uikit/uipreviewparameters/visiblepath)
in the source view's coordinates, and provides a [shared transition animator](https://developer.apple.com/documentation/uikit/uicontextmenuinteractionanimating)
for additional synchronized work. The package should not run a competing visibility timer.

## Limits that affect integration

Apple's [design guidance](https://developer.apple.com/design/human-interface-guidelines/context-menus)
explicitly allows a context menu above or below content. The inspected public SDK exposes no
below-only placement constraint, no supported replacement of the native menu's frame, and no
Messages Tapback accessory API. The separate preview generally gives UIKit more layout freedom;
its position is still a system decision. The clear preview margin remains a workaround for the
system preview controller's corner clipping, not an exact arbitrary-shape API.

Messages is a visual reference, not a published specification for third-party context menus.
Exact timing, reaction accessories, preview scaling and every OS-specific animation cannot be
promised from these APIs. A requirement for guaranteed below-only placement and pixel-identical
Messages behavior is not established by using Apple's menu rows.

Do not move the source by dismissing the keyboard in `onOpen`. Keep the source mounted through the
return and use `actionTiming="afterClose"` to defer destructive/navigation actions. Its default
remains immediate; accessibility actions without an open menu do not wait for dismissal.
`GlassMenuPanel.measure()` is a
prediction from measured system metrics; wrapped labels or another OS can change the real size.

## Verification

The revised iOS 26.5 code passed `testGlassMenuPanel` (83.5 s: short sent/received bubbles at three
screen positions), `testLongPressContextMenu` (58.5 s: actions, submenus, replacement and removal),
and `testConversationMenuTransitions` (41.6 s: three open/close cycles, original frame restored,
disabled action, deferred Copy, a 180 × 140 image preview without menu overlap, and deferred
Delete). The exported image capture was inspected. A 30 fps contact sheet from the short-bubble
dismissal shows the menu shrinking/fading with the bubble returning. This is a sampled visual
check, not a measurement of matching Messages' animation curves.

The combined diagnostic runs were **not all green**: separate synthesized drag probes left the
menu open without selecting an action. The identical downward-drag probe also failed against the
original 0.1.6 Swift and Fabric bridge (22.6 s, Xcode exit 65). Its endpoint matched Copy's reported
frame. This is not evidence of a regression introduced by the revision, nor proof that all manual
drag paths work. The unchanged UIKit gesture handling still requires owner/device acceptance.
macOS input-posting permission was unavailable for a separate real mouse-event check.

The non-gating diagnostic source is retained locally as
`artifacts/ConversationMenuDragProbe.swift.txt`, with original-code evidence in
`artifacts/b17-drag-baseline-retry.xcresult`. The shipping UI regression test independently asserts
actual selection by tap, deferred action execution, repeated close, and text/image geometry.
The iOS 18.6 regression run passed `testGlassMenuPanel`, `testLongPressContextMenu`,
`testIconButtonsAndProgrammaticMenu` and the conversation test. After introducing the public
`actionTiming` option, the conversation test passed again on 18.6 (33.8 s) and 26.5 (48.7 s),
both with Xcode exit 0. Final image captures on both versions were inspected. TypeScript checks
and all 21 Jest suites / 113 tests pass, including deferred actions, cancellation and fallback
ordering. These are focused checks, not a complete release qualification.

Android's arm64 Release build passed. The new conversation check passed repeated outside
dismissal, a disabled row, Copy after close, and image-source deletion. Its image capture was
inspected. An initial attempt could not find the last row while FlatList's initial positioning
settled; the demo now targets the last index and the Android check waits for it to become visible.
Evidence: `artifacts/b17-android-build-final.log`, `artifacts/b17-android-check-settled.log`,
`artifacts/b17-android-conversation.json` and `artifacts/b17-android-conversation.png`.
Android native menu code is unchanged. This check verifies lifecycle compatibility; it does not
measure completion of Android's source-return animation.

The local Messages app showed two empty mock conversations. A read-only capture found no bubble
to long press. Backed-up offline sample records did not appear in that simulator UI; its original
empty database was restored. No messages were sent. Consequently this session does **not** establish
a fresh side-by-side match with Messages. Earlier tracker observations are historical evidence,
not validation of this revision.

Current local evidence: `artifacts/b17-menu-first.xcresult`,
`artifacts/b17-conversation-isolate.xcresult`, `artifacts/b17-final-captures/`,
`artifacts/b17-dismiss-detail.jpg`, `artifacts/b17-menu-first.mp4`, `artifacts/b17-ios18.xcresult`,
`artifacts/b17-ios18-action-timing.xcresult`, `artifacts/b17-ios26-action-timing.xcresult`,
`artifacts/b17-ios18-final-captures/` and `artifacts/b17-ios26-final-captures/`. These are untracked artifacts.
Physical-device perception, spoken VoiceOver, keyboard transitions, very tall/wrapped content and
every screen size remain outside this evidence.

## 0.1.7 requirement review — October 3, 2026

R1: the public `UIContextMenuConfiguration`, `UIPreviewParameters`, and preview-controller APIs
have no exact preview/menu gap or container corner-radius setting. Clipping the snapshot first
cannot undo UIKit's additional outer clip. Keep the existing clear margin to preserve small and
asymmetric bubbles. A targeted preview can suppress its own shadow, but retargeting is a transition
target, not a menu layout constraint; the earlier jump experiment remains applicable. No new
retargeting or invisible stand-in is introduced. Exact 10 ±1 pt at all six requested positions is
not implemented. The existing `computeFocusMenuLayout` `menuGap` applies to calculated app-owned
frames; `GlassMenuPanel` now anchors a native menu and cannot guarantee the menu's actual rim.

R2: apply an empty [shadowPath](https://developer.apple.com/documentation/uikit/uipreviewparameters/shadowpath)
to the common targeted highlight/dismissal preview. The public API defaults to `visiblePath` when
that property is nil. The [preview provider](https://developer.apple.com/documentation/uikit/uicontextmenuconfiguration)
returns a separate controller; it has no public platter-shadow switch. `menuPlacement="system"`
avoids that separate custom controller and uses the shadowless targeted parameters, but UIKit then
chooses placement around the source. `below` retains its system platter shadow. No `previewShadow`
prop is added because it would imply control over that platter. The requested ±1-luma all-frame
acceptance and no-scaling promise are not established.

R2b: expose the existing native `colorScheme` field through `GlassContextMenu`. Set source-view
appearance before the interaction, then copy the source's resolved style to the snapshot, its host
and the preview controller before returning it. Targeted transitions use that same source. System
mode inherits the source hierarchy; explicit light/dark is independent of system appearance.
Android already resolves this field in its popup; the shared fallback now uses it as well.
Visual inspection found that UIKit menu rows follow the app window even when the preview has an
explicit style. Host apps should call `Appearance.setColorScheme` when overriding the app theme,
as ReqSer already does; the example demonstrates this. Per-component preview styling does not
change the app-wide window.
No private view hierarchy inspection or KVC is used.

See [0.1.7 verification](../release/verification-0.1.7.md) for current focused evidence and remaining
visual acceptance gaps; previous B17 results above are historical and are not rerun as a broad suite.
