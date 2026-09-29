#import "ALGMenuPanelComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/RCTComponentViewHelpers.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@interface ALGMenuPanelComponentView () <RCTALGMenuPanelViewProtocol>
@end
@implementation ALGMenuPanelComponentView {
  ALGMenuPanelView *_panel;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGMenuPanelComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGMenuPanelProps>();
    _panel = [[ALGMenuPanelView alloc] initWithFrame:CGRectZero];
    self.contentView = _panel;
    __weak ALGMenuPanelComponentView *weakSelf = self;
    _panel.onAction = ^(NSString *identifier) {
      ALGMenuPanelComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGMenuPanelEventEmitter>(self->_eventEmitter)->onMenuAction({std::string(identifier.UTF8String)});
    };
    _panel.onCancelTouch = ^{
      ALGMenuPanelComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGMenuPanelEventEmitter>(self->_eventEmitter)->onCancelTouch({});
    };
    _panel.onDismissed = ^{
      ALGMenuPanelComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGMenuPanelEventEmitter>(self->_eventEmitter)->onDismissed({});
    };
    _panel.onRequestClose = ^{
      ALGMenuPanelComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGMenuPanelEventEmitter>(self->_eventEmitter)->onRequestClose({});
    };
  }
  return self;
}
static NSString *SchemeName(ALGMenuPanelColorScheme scheme) {
  switch (scheme) {
    case ALGMenuPanelColorScheme::Light: return @"light";
    case ALGMenuPanelColorScheme::Dark: return @"dark";
    default: return @"system";
  }
}
static NSString *EdgeName(ALGMenuPanelAppearFrom edge) {
  switch (edge) {
    case ALGMenuPanelAppearFrom::Top: return @"top";
    case ALGMenuPanelAppearFrom::Bottom: return @"bottom";
    default: return @"none";
  }
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGMenuPanelProps>(props);
  [_panel configure:@(p.itemsJSON.c_str()) fontScale:p.fontScale colorScheme:SchemeName(p.colorScheme)
    disabled:p.disabled appearFrom:EdgeName(p.appearFrom) autoFocus:p.autoFocus modal:p.menuModal
    identifier:@(p.controlTestID.c_str())];
  [super updateProps:props oldProps:oldProps];
}
- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  RCTALGMenuPanelHandleCommand(self, commandName, args);
}
- (void)dismiss { [_panel dismiss]; }
+ (BOOL)shouldBeRecycled { return NO; }
@end
