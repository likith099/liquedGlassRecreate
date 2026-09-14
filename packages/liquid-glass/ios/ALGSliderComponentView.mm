#import "ALGSliderComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@implementation ALGSliderComponentView {
  ALGSliderView *_slider;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<ALGSliderComponentDescriptor>();
}
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGSliderProps>();
    _slider = [[ALGSliderView alloc] initWithFrame:CGRectZero];
    self.contentView = _slider;
    __weak ALGSliderComponentView *weakSelf = self;
    _slider.onChange = ^(double value) {
      ALGSliderComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGSliderEventEmitter>(self->_eventEmitter)->onSliderChange({value});
    };
    _slider.onStart = ^(double value) {
      ALGSliderComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGSliderEventEmitter>(self->_eventEmitter)->onSliderStart({value});
    };
    _slider.onComplete = ^(double value) {
      ALGSliderComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGSliderEventEmitter>(self->_eventEmitter)->onSliderComplete({value});
    };
    _slider.onCancel = ^(double value) {
      ALGSliderComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGSliderEventEmitter>(self->_eventEmitter)->onSliderCancel({value});
    };
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGSliderProps>(props);
  [_slider configure:p.value minimum:p.minimumValue maximum:p.maximumValue step:p.step disabled:p.disabled
                tint:RCTUIColorFromSharedColor(p.glassTint) label:@(p.controlLabel.c_str())
                hint:@(p.controlHint.c_str()) identifier:@(p.controlTestID.c_str())];
  [super updateProps:props oldProps:oldProps];
}
+ (BOOL)shouldBeRecycled { return NO; }
@end
