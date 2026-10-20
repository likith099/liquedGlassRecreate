#import "ALGPresenceComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
using namespace facebook::react;
@implementation ALGPresenceComponentView { BOOL _visible; BOOL _animated; NSInteger _generation; BOOL _appeared; }
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGPresenceComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame { if (self = [super initWithFrame:frame]) { _props = std::make_shared<const ALGPresenceProps>(); _visible = YES; _animated = YES; } return self; }
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGPresenceProps>(props);
  BOOL changed = _visible != p.visible;
  _visible = p.visible; _animated = p.transition == ALGPresenceTransition::Materialize;
  [super updateProps:props oldProps:oldProps];
  if (changed) [self animatePresence];
}
- (void)animatePresence {
  NSInteger generation = ++_generation;
  [self.layer removeAllAnimations];
  self.userInteractionEnabled = _visible;
  CGAffineTransform target = _visible ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.01, 0.01);
  void (^complete)(BOOL) = ^(BOOL finished) {
    if (generation != self->_generation || self->_visible) return;
    if (self->_eventEmitter) std::static_pointer_cast<const ALGPresenceEventEmitter>(self->_eventEmitter)->onExited({});
  };
  if (!_animated || !self.window || UIAccessibilityIsReduceMotionEnabled()) { self.transform = target; complete(YES); return; }
  // Ancestor alpha must remain 1: fading it disables a descendant's live glass compositing.
  [UIView animateWithDuration:_visible ? 0.35 : 0.12 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0
    options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
    animations:^{ self.transform = target; } completion:complete];
}
- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window && !_appeared) { _appeared = YES; if (_visible && _animated && !UIAccessibilityIsReduceMotionEnabled()) self.transform = CGAffineTransformMakeScale(0.5, 0.5); [self animatePresence]; }
  else if (!self.window && !_visible) [self animatePresence];
}
+ (BOOL)shouldBeRecycled { return NO; }
@end
