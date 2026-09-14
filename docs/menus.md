# Native menu buttons

`GlassMenuButton` presents a system menu from a native button. iOS 26 uses `UIButton.Configuration.glass()` and `UIMenu`; older iOS, Reduce Transparency, and `forceFallback` use a standard tinted UIKit button. Android uses `android.widget.Button` and `PopupMenu`. No Expo, custom modal menu, or extra glass layer is required.

```tsx
import {useState} from 'react';
import {GlassMenuButton} from 'react-native-adaptive-liquid-glass';

export function LibraryMenu() {
  const [favorite, setFavorite] = useState(false);
  return <GlassMenuButton
    title="Library actions"
    systemImage="ellipsis.circle"
    items={[
      {id: 'favorite', title: 'Favorite', systemImage: 'heart', checked: favorite},
      {id: 'share', title: 'Share', systemImage: 'square.and.arrow.up'},
      {id: 'unavailable', title: 'Unavailable', disabled: true},
      {id: 'remove', title: 'Remove', systemImage: 'trash', destructive: true},
    ]}
    onAction={id => {
      if (id === 'favorite') setFavorite(value => !value);
      // Handle other action IDs in your app.
    }}
  />;
}
```

The title and item IDs/titles must be nonempty, and IDs must be unique. Empty items disable the button. `disabled` blocks menu activation; item-level `disabled` keeps a visible unavailable entry. `checked` is controlled: the package emits the ID and your app updates the item. Leaving `checked` absent omits Android's checkbox. `destructive` marks the native action visually; selecting it only calls `onAction`. It does not perform a deletion.

`systemImage` is an iOS SF Symbol name, on both the trigger and individual items. Android displays the titles. `tintColor` changes the foreground accent; it does not recolor the menu material or apply the action cluster's neutral tint. Android applies it to enabled action text as well as the trigger; destructive actions retain the platform error color. `forceFallback` previews a standard iOS button while retaining the native menu. Android always uses its standard control. The system manages presentation and dismissal; controlled open state is not exposed.

## Sections and submenus

Existing flat `GlassMenuItem` actions remain compatible. `GlassMenuElement` adds two group types:

```tsx
const items: readonly GlassMenuElement[] = [
  {kind: 'submenu', id: 'sort', title: 'Sort', items: [
    {kind: 'section', id: 'order', title: 'Order', items: [
      {id: 'name', title: 'By name', checked: true},
      {id: 'recent', title: 'Most recent', checked: false},
    ]},
  ]},
];
```

Import the type from the package. Submenus require a title; sections can use an empty title for an untitled group. Every group must contain items. IDs must be unique across the complete tree, including group IDs. Only leaf action IDs produce callbacks. A disabled submenu blocks every descendant; its ID does not become an action.

The shared API supports one submenu level, up to 8 total tree levels including sections, and 256 elements. Submenus inside other submenus are rejected because Android's public SubMenu contract does not support them. UIKit renders sections inline; Android uses groups and disabled title rows, with native dividers on API 28+. Section title rows never emit actions. Groups can also be used in [toolbar menus](toolbars.md).

The default host height is 64 points with a 120-point minimum width. Set explicit width or flex in horizontal layouts and allow more room for long titles or large accessibility text. Native accessibility exposes the button label/hint, disabled items, and checkmarks. Use `accessibilityLabel`, `accessibilityHint`, and `testID` for the native trigger.

Native hosts dismiss an open menu when items change, the button becomes disabled, or the view detaches. Version checks reject stale selections, and the React wrapper also rejects unknown or disabled IDs. Unchanged items do not rebuild the menu. These controls do not participate in neighboring glass merging.

Rebuild both native applications after upgrading to a package containing this component. Fabric codegen and autolinking register `ALGMenu` alongside the existing slider on Android and the other iOS hosts. The demo's **Native menus** section exercises checked items, disabled entries, destructive appearance, and standard-button preview.

Implementation references: [Apple menu buttons](https://developer.apple.com/documentation/uikit/uicontrol/showsmenuasprimaryaction), [Android PopupMenu](https://developer.android.com/reference/android/widget/PopupMenu), [Android SubMenu limitations](https://developer.android.com/reference/android/view/SubMenu).

## Verification

The preceding flat-menu revision passed TypeScript checks, 19 JavaScript tests, and native UI tests on the iOS simulator, physical iPhone, and Android emulator. Current toolbar/hierarchy batch results are in the [development tracker](development.md); the earlier physical-iPhone result does not cover these additions. After building and opening a fresh Android demo, reproduce the flat regression with `python3 scripts/verify-android-menu.py`, or the consolidated batch with `python3 scripts/verify-android-toolbar.py`. Metro uses port 8093. Older iOS runtime testing and full VoiceOver/TalkBack review remain outstanding.
