#import "ALGMenuComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@implementation ALGMenuComponentView {
  ALGMenuView *_menu;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGMenuComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGMenuProps>();
    _menu = [[ALGMenuView alloc] initWithFrame:CGRectZero];
    self.contentView = _menu;
    __weak ALGMenuComponentView *weakSelf = self;
    _menu.onAction = ^(NSString *identifier) {
      ALGMenuComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGMenuEventEmitter>(self->_eventEmitter)->onMenuAction({std::string(identifier.UTF8String)});
    };
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGMenuProps>(props);
  [_menu configure:@(p.title.c_str()) itemsJSON:@(p.itemsJSON.c_str()) symbol:@(p.systemImage.c_str())
    disabled:p.disabled tint:RCTUIColorFromSharedColor(p.glassTint) forceFallback:p.forceFallback
    label:@(p.controlLabel.c_str()) hint:@(p.controlHint.c_str()) identifier:@(p.controlTestID.c_str())
    toolbar:p.toolbar maxVisibleItems:p.maxVisibleItems mergingEnabled:p.mergingEnabled];
  [super updateProps:props oldProps:oldProps];
}
+ (BOOL)shouldBeRecycled { return NO; }
@end
