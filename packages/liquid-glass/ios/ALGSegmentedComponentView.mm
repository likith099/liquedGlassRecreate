#import "ALGSegmentedComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@implementation ALGSegmentedComponentView {
  ALGSegmentedView *_segmented;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<ALGSegmentedComponentDescriptor>();
}
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGSegmentedProps>();
    _segmented = [[ALGSegmentedView alloc] initWithFrame:CGRectZero];
    self.contentView = _segmented;
    __weak ALGSegmentedComponentView *weakSelf = self;
    _segmented.onSelectionChange = ^(NSString *value) {
      ALGSegmentedComponentView *strongSelf = weakSelf;
      if (!strongSelf || !strongSelf->_eventEmitter) return;
      std::static_pointer_cast<const ALGSegmentedEventEmitter>(strongSelf->_eventEmitter)->onSelectionChange({std::string(value.UTF8String)});
    };
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGSegmentedProps>(props);
  NSString *scheme = p.colorScheme == ALGSegmentedColorScheme::Dark ? @"dark" : p.colorScheme == ALGSegmentedColorScheme::Light ? @"light" : @"system";
  [_segmented configure:@(p.optionsJSON.c_str()) selectedValue:@(p.selectedValue.c_str()) disabled:p.disabled
               tint:RCTUIColorFromSharedColor(p.glassTint) scheme:scheme label:@(p.controlLabel.c_str()) identifier:@(p.controlTestID.c_str())];
  [super updateProps:props oldProps:oldProps];
}
+ (BOOL)shouldBeRecycled { return NO; }
@end
