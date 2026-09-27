#import "ALGSearchFieldComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/RCTComponentViewHelpers.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"
using namespace facebook::react;
@interface ALGSearchFieldComponentView () <RCTALGSearchFieldViewProtocol>
@end
@implementation ALGSearchFieldComponentView {
  ALGSearchFieldView *_field;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider { return concreteComponentDescriptorProvider<ALGSearchFieldComponentDescriptor>(); }
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGSearchFieldProps>();
    _field = [[ALGSearchFieldView alloc] initWithFrame:CGRectZero];
    self.contentView = _field;
    __weak ALGSearchFieldComponentView *weakSelf = self;
    _field.onChangeText = ^(NSString *text, NSInteger eventCount) {
      ALGSearchFieldComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGSearchFieldEventEmitter>(self->_eventEmitter)->onSearchChange({std::string(text.UTF8String), (int)eventCount});
    };
    _field.onSubmit = ^(NSString *text) {
      ALGSearchFieldComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGSearchFieldEventEmitter>(self->_eventEmitter)->onSearchSubmit({std::string(text.UTF8String)});
    };
    _field.onFocus = ^{
      ALGSearchFieldComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGSearchFieldEventEmitter>(self->_eventEmitter)->onSearchFocus({});
    };
    _field.onBlur = ^{
      ALGSearchFieldComponentView *self = weakSelf;
      if (self && self->_eventEmitter) std::static_pointer_cast<const ALGSearchFieldEventEmitter>(self->_eventEmitter)->onSearchBlur({});
    };
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGSearchFieldProps>(props);
  [_field configure:@(p.value.c_str()) mostRecentEventCount:p.mostRecentEventCount placeholder:@(p.placeholder.c_str())
    disabled:p.disabled tint:RCTUIColorFromSharedColor(p.glassTint) scheme:@(toString(p.colorScheme).c_str())
    forceFallback:p.forceFallback label:@(p.controlLabel.c_str()) identifier:@(p.controlTestID.c_str())];
  [super updateProps:props oldProps:oldProps];
}
- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  RCTALGSearchFieldHandleCommand(self, commandName, args);
}
- (void)focus { [_field focusField]; }
- (void)blur { [_field blurField]; }
+ (BOOL)shouldBeRecycled { return NO; }
@end
