import type {FocusMenuLayout, FocusMenuLayoutInput} from './types';

const clamp = (value: number, low: number, high: number) => Math.min(Math.max(value, low), high);

/**
 * Where a long-pressed message and its menu go so the menu is always directly below the message:
 * the message moves up only when the menu would not fit below it, moves down only when it is partly
 * under the header, and otherwise stays put; it never moves sideways. The menu hugs the message's
 * side (left edge for received, right edge for sent), clamped inside the safe area. A message too
 * tall to show with the menu is pinned above the menu with its top clipped under `topLimit`.
 * All values are window points. Give the returned `menu` frame to GlassMenuPanel as its style.
 */
export default function computeFocusMenuLayout(input: FocusMenuLayoutInput): FocusMenuLayout {
  const {bubble, isOwn, window, insets = {}, topLimit, menuHeight} = input;
  const gap = input.menuGap ?? 10;
  const topGap = input.topGap ?? 12;
  const edge = input.edge ?? 8;
  const width = input.menuWidth ?? Math.min(248, window.width - 32);
  const top = topLimit + topGap;
  const bottom = window.height - (insets.bottom ?? 0);
  const space = Math.max(0, bottom - top);
  const menuH = Math.min(menuHeight, space);
  const stack = bubble.height + gap + menuH;
  let bubbleY: number;
  let menuY: number;
  if (stack <= space) {
    bubbleY = clamp(bubble.y, top, bottom - stack);
    menuY = bubbleY + bubble.height + gap;
  } else {
    menuY = bottom - menuH;
    bubbleY = menuY - gap - bubble.height;
  }
  const minX = (insets.left ?? 0) + edge;
  const maxX = window.width - (insets.right ?? 0) - edge - width;
  const menuX = clamp(isOwn ? bubble.x + bubble.width - width : bubble.x, minX, Math.max(minX, maxX));
  return {
    bubble: {x: bubble.x, y: bubbleY, width: bubble.width, height: bubble.height},
    menu: {x: menuX, y: menuY, width, height: menuH},
    clipTop: topLimit,
  };
}
