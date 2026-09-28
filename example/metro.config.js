const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const path = require('path');
const packageName = '@likith99/react-native-adaptive-liquid-glass';
const packageSource = path.resolve(__dirname, '../packages/liquid-glass/src/index.ts');
const config = {
  watchFolders: [path.resolve(__dirname, '..')],
  resolver: {
    // Resolve only this workspace package to its TypeScript source, so edits need no build step.
    resolveRequest: (context, moduleName, platform) => moduleName === packageName
      ? {type: 'sourceFile', filePath: packageSource}
      : context.resolveRequest(context, moduleName, platform),
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
