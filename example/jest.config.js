module.exports = {
  preset: '@react-native/jest-preset',
  // Test the workspace package's TypeScript source rather than its compiled lib/ output.
  moduleNameMapper: {'^@likith99/react-native-adaptive-liquid-glass$': '<rootDir>/../packages/liquid-glass/src'},
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?|@react-navigation|react-native-screens|react-native-safe-area-context|react-freeze|use-latest-callback)/)',
  ],
};
