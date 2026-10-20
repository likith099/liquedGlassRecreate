#import "ALGControlsComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@implementation ALGControlsComponentView { ALGControlsView *_controls; }
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGControlsComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGControlsProps>();
    _controls = [[ALGControlsView alloc] initWithFrame:CGRectZero]; self.contentView = _controls;
    __weak ALGControlsComponentView *weakSelf = self;
    _controls.onAction = ^(NSString *identifier, NSString *action) {
      ALGControlsComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGControlsEventEmitter>(self->_eventEmitter)->onControlAction({std::string(identifier.UTF8String), std::string(action.UTF8String)});
    };
    _controls.onContentSize = ^(double width, double height) {
      ALGControlsComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGControlsEventEmitter>(self->_eventEmitter)->onContentSize({width, height});
    };
  } return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGControlsProps>(props);
  [_controls configure:@(p.configJSON.c_str())];
  [super updateProps:props oldProps:oldProps];
}
- (void)updateLayoutMetrics:(LayoutMetrics const &)metrics oldLayoutMetrics:(LayoutMetrics const &)oldMetrics {
  CGRect previous = self.frame;
  [super updateLayoutMetrics:metrics oldLayoutMetrics:oldMetrics];
  CGRect target = self.frame;
  if (_controls.animatesLayout && previous.size.width > 0 && !CGRectEqualToRect(previous, target)) {
    self.frame = previous;
    [UIView animateWithDuration:_controls.layoutAnimationDuration delay:0 usingSpringWithDamping:_controls.layoutAnimationDamping initialSpringVelocity:0
      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{ self.frame = target; } completion:nil];
  }
}
+ (BOOL)shouldBeRecycled { return NO; }
@end
