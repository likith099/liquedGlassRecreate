#import "ALGMenuComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/RCTComponentViewHelpers.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@interface ALGMenuComponentView () <RCTALGMenuViewProtocol>
@end
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
    _menu.onPress = ^{
      ALGMenuComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGMenuEventEmitter>(self->_eventEmitter)->onButtonPress({});
    };
    _menu.onMenuOpen = ^{
      ALGMenuComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGMenuEventEmitter>(self->_eventEmitter)->onMenuOpen({});
    };
    _menu.onMenuClose = ^{
      ALGMenuComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGMenuEventEmitter>(self->_eventEmitter)->onMenuClose({});
    };
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGMenuProps>(props);
  [_menu setIcon:p.iconMode pointSize:p.symbolPointSize colorScheme:@(toString(p.colorScheme).c_str())
    prominent:p.iconVariant == ALGMenuIconVariant::Prominent];
  [_menu configure:@(p.title.c_str()) itemsJSON:@(p.itemsJSON.c_str()) symbol:@(p.systemImage.c_str())
    disabled:p.disabled tint:RCTUIColorFromSharedColor(p.glassTint) forceFallback:p.forceFallback
    label:@(p.controlLabel.c_str()) hint:@(p.controlHint.c_str()) identifier:@(p.controlTestID.c_str())
    toolbar:p.toolbar maxVisibleItems:p.maxVisibleItems mergingEnabled:p.mergingEnabled
    contextMenu:p.contextMenu previewCornerRadius:p.previewCornerRadius];
  _menu.previewCornerRadii = @[@(p.previewCornerTopLeft), @(p.previewCornerTopRight), @(p.previewCornerBottomLeft),
    @(p.previewCornerBottomRight)];
  [super updateProps:props oldProps:oldProps];
}
- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)child index:(NSInteger)index {
  [_menu.reactContentView insertSubview:child atIndex:index];
}
- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)child index:(NSInteger)index {
  [child removeFromSuperview];
}
- (void)layoutSubviews {
  [super layoutSubviews];
  // Yoga already includes the host padding in React child coordinates.
  _menu.frame = self.bounds;
}
- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  RCTALGMenuHandleCommand(self, commandName, args);
}
- (void)open { [_menu openMenu]; }
+ (BOOL)shouldBeRecycled { return NO; }
@end
