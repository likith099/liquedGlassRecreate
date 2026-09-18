/**
 * Default height for a native control host at the current system font scale.
 *
 * Native controls do not size Yoga from their intrinsic content, so each one needs an
 * explicit React height. Only the text inside a control grows with the font scale; its
 * icons, insets and touch padding do not. Scaling the whole default height therefore
 * leaves a large empty box around the label at accessibility text sizes, so this grows
 * only the share of the default height that the text occupies.
 *
 * `base` is the default height at font scale 1 and `text` is the line height the control
 * gives its label there. A caller's explicit `style.height` still wins over this.
 */
export default function adaptiveHeight(base: number, text: number, fontScale: number): number {
  return Math.round(base + text * (Math.max(1, fontScale) - 1));
}
