#import "ALGExpandingTabsComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@implementation ALGExpandingTabsComponentView {
  ALGExpandingTabsView *_tabs;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGExpandingTabsComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGExpandingTabsProps>();
    _tabs = [[ALGExpandingTabsView alloc] initWithFrame:CGRectZero];
    self.contentView = _tabs;
    __weak ALGExpandingTabsComponentView *weakSelf = self;
    _tabs.onSelectionChange = ^(NSString *value) {
      ALGExpandingTabsComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGExpandingTabsEventEmitter>(self->_eventEmitter)->onSelectionChange({std::string(value.UTF8String)});
    };
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGExpandingTabsProps>(props);
  [_tabs configure:@(p.optionsJSON.c_str()) selectedValue:@(p.selectedValue.c_str()) disabled:p.disabled
    glass:p.material == ALGExpandingTabsMaterial::Glass mergingEnabled:p.mergingEnabled inset:p.contentInset
    tint:RCTUIColorFromSharedColor(p.glassTint) identifier:@(p.controlTestID.c_str())];
  [super updateProps:props oldProps:oldProps];
}
+ (BOOL)shouldBeRecycled { return NO; }
@end
