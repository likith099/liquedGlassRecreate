#import "ALGButtonComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@implementation ALGButtonComponentView {
  ALGButtonView *_button;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<ALGButtonComponentDescriptor>();
}
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGButtonProps>();
    _button = [[ALGButtonView alloc] initWithFrame:CGRectZero];
    self.contentView = _button;
    __weak ALGButtonComponentView *weakSelf = self;
    _button.onActivate = ^{
      ALGButtonComponentView *strongSelf = weakSelf;
      if (!strongSelf || !strongSelf->_eventEmitter) return;
      std::static_pointer_cast<const ALGButtonEventEmitter>(strongSelf->_eventEmitter)->onActivate({true});
    };
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGButtonProps>(props);
  NSString *scheme = p.colorScheme == ALGButtonColorScheme::Dark ? @"dark" : p.colorScheme == ALGButtonColorScheme::Light ? @"light" : @"system";
  [_button configure:@(p.title.c_str()) symbol:@(p.systemImage.c_str()) prominent:p.variant == ALGButtonVariant::Prominent
            disabled:p.disabled loading:p.loading tint:RCTUIColorFromSharedColor(p.glassTint) scheme:scheme
            label:@(p.controlLabel.c_str()) hint:@(p.controlHint.c_str()) identifier:@(p.controlTestID.c_str())];
  [super updateProps:props oldProps:oldProps];
}
+ (BOOL)shouldBeRecycled { return NO; }
@end
