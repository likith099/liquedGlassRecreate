module.exports = {
  dependency: {platforms: {android: {
    componentDescriptors: ['ALGSliderComponentDescriptor', 'ALGMenuComponentDescriptor', 'ALGTabsComponentDescriptor', 'ALGControlsComponentDescriptor'],
    // Builds codegen output with the hand-written ALGControls shadow node (common/cpp).
    cmakeListsPath: '../android/src/main/jni/CMakeLists.txt',
  }}},
};
