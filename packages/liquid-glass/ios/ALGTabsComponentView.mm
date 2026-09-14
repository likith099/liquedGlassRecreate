#import "ALGTabsComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@implementation ALGTabsComponentView {
  ALGTabsView *_tabs;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGTabsComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGTabsProps>();
    _tabs = [[ALGTabsView alloc] initWithFrame:CGRectZero];
    self.contentView = _tabs;
    __weak ALGTabsComponentView *weakSelf = self;
    _tabs.onSelectionChange = ^(NSString *identifier) {
      ALGTabsComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGTabsEventEmitter>(self->_eventEmitter)->onSelectionChange({std::string(identifier.UTF8String)});
    };
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGTabsProps>(props);
  // selectionRevision forces this transaction when React rejects a native tap.
  [_tabs configure:@(p.itemsJSON.c_str()) selectedValue:@(p.selectedValue.c_str()) disabled:p.disabled
    tint:RCTUIColorFromSharedColor(p.glassTint) identifier:@(p.controlTestID.c_str())];
  [super updateProps:props oldProps:oldProps];
}
+ (BOOL)shouldBeRecycled { return NO; }
@end
