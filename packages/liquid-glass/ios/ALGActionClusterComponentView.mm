#import "ALGActionClusterComponentView.h"
#import <react/renderer/components/AdaptiveLiquidGlassSpec/ComponentDescriptors.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/Props.h>
#import <react/renderer/components/AdaptiveLiquidGlassSpec/EventEmitters.h>
#import <React/RCTConversions.h>
#import "AdaptiveLiquidGlass-Swift.h"

using namespace facebook::react;

@implementation ALGActionClusterComponentView {
  ALGActionClusterView *_cluster;
}
+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<ALGActionClusterComponentDescriptor>();
}
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _props = std::make_shared<const ALGActionClusterProps>();
    _cluster = [[ALGActionClusterView alloc] initWithFrame:CGRectZero];
    self.contentView = _cluster;
    __weak ALGActionClusterComponentView *weakSelf = self;
    _cluster.onAction = ^(NSString *identifier) {
      ALGActionClusterComponentView *strongSelf = weakSelf;
      if (!strongSelf || !strongSelf->_eventEmitter) return;
      auto emitter = std::static_pointer_cast<const ALGActionClusterEventEmitter>(strongSelf->_eventEmitter);
      emitter->onAction({std::string(identifier.UTF8String)});
    };
    _cluster.onExpandedChange = ^(BOOL expanded) {
      ALGActionClusterComponentView *strongSelf = weakSelf;
      if (!strongSelf || !strongSelf->_eventEmitter) return;
      auto emitter = std::static_pointer_cast<const ALGActionClusterEventEmitter>(strongSelf->_eventEmitter);
      emitter->onExpandedChange({static_cast<bool>(expanded)});
    };
  }
  return self;
}
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<const ALGActionClusterProps>(props);
  [_cluster configure:[NSString stringWithUTF8String:p.actionsJSON.c_str()]
             expanded:p.expanded mergingEnabled:p.mergingEnabled spacing:p.spacing tint:RCTUIColorFromSharedColor(p.glassTint)
             material:p.material == ALGActionClusterMaterial::Clear ? @"clear" : @"regular"
             interactive:p.interactive
             duration:p.duration toggleLabel:[NSString stringWithUTF8String:p.toggleLabel.c_str()]];
  [super updateProps:props oldProps:oldProps];
}
+ (BOOL)shouldBeRecycled { return NO; }
@end
