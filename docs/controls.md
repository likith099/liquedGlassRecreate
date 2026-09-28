# Native controls

`GlassButton`, `GlassSegmentedControl`, `GlassSlider`, `GlassSearchField` and `GlassExpandingTabs`
are system controls: UIKit or SwiftUI draws them on iOS, with Liquid Glass on iOS 26, and Android
uses its standard counterparts. All of them are controlled: React owns the value, and a change only
sticks when you update it in the callback.

## GlassButton

```tsx
<GlassButton title="Add to collection" systemImage="plus" variant="prominent"
  loading={saving} disabled={!canSave} onPress={save} />
```

| Prop | Behaviour |
| --- | --- |
| `title` | Required text. With a `title`, iOS 26 uses a native SwiftUI glass button. |
| `systemImage` | iOS SF Symbol. Android shows the title only. |
| `variant` | `'regular'` (default) or `'prominent'`. |
| `loading`, `disabled` | Both block activation; loading is announced. |
| `tintColor`, `colorScheme`, `forceFallback` | Tint, pinned appearance, and a preview of the standard button. |
| `onPress` | Called without arguments. |

The host is 64 points tall at standard text sizes and grows with the system font scale; an explicit
`style.height` wins. Give it a width or flex in horizontal rows. `<GlassButton>` with React children
still works and renders `GlassPressable`; prefer `GlassPressable` for custom content.

## GlassSegmentedControl

```tsx
const [filter, setFilter] = useState<string | null>('all');

<GlassSegmentedControl value={filter} onValueChange={setFilter} accessibilityLabel="Library filter"
  options={[
    {value: 'all', label: 'All'},
    {value: 'saved', label: 'Saved', count: 3, tintColor: '#FF2D55'},
    {value: 'shared', label: 'Shared', disabled: true},
  ]} />
```

- iOS uses `UISegmentedControl`, including the iOS 26 glass selection thumb; Android uses a button
  group with ripple.
- `null` clears the selection. Values must be unique and nonempty, and a selected value must exist.
  Options can be replaced or reordered. Tapping the selected option again does not call back.
- `count` shows after the label ("Saved 3"; above 99 shows "99+"). `tintColor` on an option colours
  it while selected; native iOS has one selected-segment colour, so it follows the selected option.
- Options stay side by side. Above a font scale of 1.3 both platforms use the React group, whose
  labels wrap instead of truncating. Short labels and few options work best.

## GlassSlider

```tsx
<GlassSlider value={level} minimumValue={0} maximumValue={100} step={10}
  onValueChange={setLevel}
  onSlidingComplete={value => console.log('Released at', value)}
  onSlidingCancel={value => console.log('Cancelled; controlled value', value)}
  accessibilityLabel="Level" />
```

- `UISlider` on iOS and `SeekBar` on Android. Defaults: range 0–1, continuous (`step={0}`), a
  52-point host. `disabled` blocks changes; `tintColor` colours the active track.
- The native control owns the thumb during a drag, then reconciles with React's latest `value`,
  including when the parent declined a change. `onSlidingCancel` reports the restored value; it
  also fires if the control is disabled, its range changes or it detaches mid-drag.
- Values clamp to the range and positive steps snap from `minimumValue`; the maximum stays
  reachable. Accessibility adjustment uses the step, or 5% of the range when continuous.
- There is no `forceFallback`; the platform slider is always used.

## GlassSearchField

```tsx
const search = useRef<GlassSearchFieldHandle>(null);

<GlassSearchField ref={search} value={query} onChangeText={setQuery}
  onSubmitEditing={runSearch} placeholder="Search" />
search.current?.focus();
```

- iOS uses `UISearchTextField` on glass (iOS 26) or blur, with the search accessibility trait and
  fast typing kept intact while React echoes the value. Android uses a `TextInput` on the opaque
  surface and does not capitalise queries.
- `onSubmitEditing` runs on the Search key and dismisses the keyboard. The ref also has `blur()`.
- `tintColor` sets the cursor, `colorScheme` pins the appearance, `forceFallback` shows the opaque
  field.

## GlassExpandingTabs

A row of icon pills where the selected pill grows to show its label.

```tsx
<GlassExpandingTabs value={section} onValueChange={setSection} onReselect={scrollToTop}
  options={[
    {value: 'overview', label: 'Overview', systemImage: 'square.grid.2x2', androidIcon: 'ic_overview', tintColor: '#0A84FF'},
    {value: 'favorites', label: 'Favorites', systemImage: 'heart', androidIcon: 'ic_favorite', tintColor: '#FF3B30'},
  ]} />
```

- iOS draws SwiftUI glass pills (iOS 26) or material pills. One spring drives each pill's width,
  label and colour together, without overshoot; Reduce Motion snaps. Android uses an animated
  fallback with the same geometry.
- Glass merging between pills is off unless you pass `mergingEnabled`. `material="tinted"` uses
  neutral plates instead of glass.
- `onReselect` fires when the selected pill is tapped again. Screen readers read every label, even
  on collapsed pills, with its position ("2 of 5").
- The row scrolls when it overflows; `contentInset` (default 16) sets the first and last pill's
  inset, and pills scroll under it. A selected pill scrolls into view.
- Give each option an `androidIcon` drawable; without it the Android pill is empty and a development
  warning names the option.

## Layout

These controls size to the React `style` you give them, not to their native content. Heights grow
with the system font scale; allow room for that, since a fixed parent height can clip. None of them
joins a glass merging group.
