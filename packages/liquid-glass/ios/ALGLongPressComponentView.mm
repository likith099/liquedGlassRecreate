#import "ALGLongPressComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;

/// A long press around React children. Before it is recognised it stays out of the way: the
/// children's taps and an enclosing list's scroll win (moving more than allowableMovement fails
/// it). Once recognised it reports the children's frame in window points, cancels React Native's
/// touch so the children do not also fire onPress on release, and hands the same finger to the
/// most recently mounted menu panel until it lifts.
@interface ALGLongPressComponentView () <UIGestureRecognizerDelegate>
@end
@implementation ALGLongPressComponentView {
  UILongPressGestureRecognizer *_recognizer;
  ALGLongPressHaptic _haptic;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGLongPressComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGLongPressProps>();
    _recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handle:)];
    _recognizer.minimumPressDuration = 0.5;
    _recognizer.allowableMovement = 10;
    _recognizer.delegate = self;
    [self addGestureRecognizer:_recognizer];
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGLongPressProps>(props);
  _recognizer.minimumPressDuration = MAX(0, p.minimumDuration) / 1000.0;
  _recognizer.allowableMovement = p.allowableMovement;
  _recognizer.enabled = !p.disabled;
  _haptic = p.haptic;
  [super updateProps:props oldProps:oldProps];
}
- (void)impact {
  UIImpactFeedbackStyle style;
  switch (_haptic) {
    case ALGLongPressHaptic::Light: style = UIImpactFeedbackStyleLight; break;
    case ALGLongPressHaptic::Medium: style = UIImpactFeedbackStyleMedium; break;
    case ALGLongPressHaptic::Heavy: style = UIImpactFeedbackStyleHeavy; break;
    case ALGLongPressHaptic::Soft: style = UIImpactFeedbackStyleSoft; break;
    case ALGLongPressHaptic::Rigid: style = UIImpactFeedbackStyleRigid; break;
    default: return;
  }
  [[[UIImpactFeedbackGenerator alloc] initWithStyle:style] impactOccurred];
}
/// React Native's touch handler is a gesture recognizer on the root view; toggling it cancels the
/// JavaScript touch, so a Pressable under the finger does not fire onPress when it lifts.
- (void)cancelReactTouches {
  for (UIView *view = self.superview; view; view = view.superview) {
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
      if ([NSStringFromClass(recognizer.class) containsString:@"TouchHandler"] && recognizer.enabled) {
        recognizer.enabled = NO;
        recognizer.enabled = YES;
      }
    }
  }
}
- (void)handle:(UILongPressGestureRecognizer *)recognizer {
  CGPoint point = [recognizer locationInView:nil];
  ALGMenuPanelTracker *tracker = ALGMenuPanelTracker.shared;
  switch (recognizer.state) {
    case UIGestureRecognizerStateBegan: {
      [self impact];
      [self cancelReactTouches];
      [tracker begin];
      CGRect frame = [self convertRect:self.bounds toView:nil];
      if (_eventEmitter) {
        ALGLongPressEventEmitter::OnLongPress event{};
        event.x = frame.origin.x; event.y = frame.origin.y;
        event.width = frame.size.width; event.height = frame.size.height;
        std::static_pointer_cast<const ALGLongPressEventEmitter>(_eventEmitter)->onLongPress(event);
      }
      break;
    }
    case UIGestureRecognizerStateChanged: [tracker moveTo:point]; break;
    case UIGestureRecognizerStateEnded: [tracker endAt:point]; break;
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed: [tracker cancel]; break;
    default: break;
  }
}
// Never blocked by, and never blocking, React Native's own touch handler.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
  return [NSStringFromClass(other.class) containsString:@"TouchHandler"];
}
@end
