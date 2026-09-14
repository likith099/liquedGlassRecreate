# Native toolbars

`GlassToolbar` hosts a UIKit `UIToolbar` on iOS and an Android `Toolbar`. Native bar items own taps, menu presentation, and feedback. iOS 26 supplies the system glass appearance; older iOS uses its standard toolbar. No navigation library or Expo Modules is required.

```tsx
import {GlassToolbar} from 'react-native-adaptive-liquid-glass';

<GlassToolbar
  items={[
    {id: 'save', title: 'Save', systemImage: 'square.and.arrow.down'},
    {kind: 'submenu', id: 'order', title: 'Order', systemImage: 'arrow.up.arrow.down', items: [
      {kind: 'section', id: 'sorting', title: 'Sort by', items: [
        {id: 'name', title: 'Name', checked: sort === 'name'},
        {id: 'recent', title: 'Most recent', checked: sort === 'recent'},
      ]},
    ]},
    {id: 'remove', title: 'Remove', destructive: true, placement: 'overflow'},
  ]}
  maxVisibleItems={2}
  onAction={id => {
    if (id === 'name' || id === 'recent') setSort(id);
    // Handle save/remove in your app.
  }}
/>
```

Define `sort` and `setSort` in the consuming component. `onAction` receives only enabled leaf IDs, never a section or submenu ID. Native and JavaScript guards reject disabled, removed, and stale actions. Checkmarks are controlled by `items`; selecting an action does not mutate them. Toolbar roots accept actions and submenus; sections belong inside menus. See [menu tree rules](menus.md#sections-and-submenus).

## Layout and overflow

The default host height is 64 points and minimum width is 64. Give the toolbar an explicit width or flex inside horizontal layouts. `maxVisibleItems` defaults to 3 and is an upper bound, not a fixed count; 0 sends everything to overflow. `placement="overflow"` always places that root item in the native overflow menu. Automatic items can also move there when space is limited. Overflow keeps the original relative order of hidden items.

UIKit uses native bar buttons and a native More actions menu; the host estimates the width of titles/SF Symbols to decide which items fit. Android uses its normal action-menu presenter, with an additional host-width budget because this toolbar may be narrower than the screen. The exact visible count can differ across platforms. A supplied iOS SF Symbol replaces the visible title on the bar, while the title remains the accessibility label and menu text. Android displays titles. Long labels remain available in overflow instead of being squeezed into the bar.

The component occupies its React layout frame. It does not attach itself to a navigation controller, pin itself to a screen edge, or add safe-area/keyboard insets; the consuming screen owns placement and insets. Larger text sizes and tight heights still need dedicated accessibility review.

## Appearance and state

- `mergingEnabled` defaults to false. On iOS 26, setting it true lets neighboring native bar items share their system background. This is toolbar background grouping, not the action cluster's expansion animation or a configurable merging distance.
- `forceFallback` uses an opaque toolbar background and hides shared glass item backgrounds on iOS 26; older iOS and Android keep their standard controls. Reduce Transparency also selects the opaque iOS appearance.
- `tintColor` changes the foreground accent. Destructive actions use the platform error color. It is not a press-highlight brightness control.
- `disabled` blocks all action delivery; item-level `disabled` applies to an action or submenu and its descendants. Android may still allow opening the overflow list to inspect disabled entries.
- `testID` identifies the native toolbar. iOS item identifiers append `-<id>` and overflow appends `-overflow`; Android exposes native action titles and its standard overflow accessibility label. The native item titles label individual controls; do not rely on a container accessibility label to replace them.

Changing items, disabling the host, detaching, or rebuilding for a changed toolbar width dismisses open menus. Native handlers retain a revision and recheck the current action tree before emitting. Unchanged props do not rebuild the item tree. There is no custom press animation or per-frame JavaScript rendering.

## Development and verification

Rebuild native apps after installing this batch because the shared `ALGMenu` Fabric spec gained toolbar props. The demo's **Toolbars and grouped menus** section exercises overflow, hierarchical menus, checkmarks, narrow width, fallback appearance, shared backgrounds, and replacement while a menu is open. The timer is a demo control, not package behavior.

The consolidated iOS test is `GlassInteractionTests/testToolbarAndMenuBatch`; Android uses `python3 scripts/verify-android-toolbar.py` after installing and launching a fresh demo. Current results and remaining coverage are tracked in [development](development.md).

Platform references: [UIToolbar](https://developer.apple.com/documentation/uikit/uitoolbar), [UIBarButtonItem shared backgrounds](https://developer.apple.com/documentation/uikit/uibarbuttonitem/sharesbackground), [Android Toolbar](https://developer.android.com/reference/android/widget/Toolbar), [Android action placement](https://developer.android.com/develop/ui/views/components/appbar/actions).
