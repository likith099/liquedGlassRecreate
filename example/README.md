# Liquid Glass Lab

Bare React Native 0.86 demo for the local `@likith99/react-native-adaptive-liquid-glass` package. Run the commands from the repository root:

```sh
npm install
cd example/ios && pod install && cd ../..
npm start
# Another terminal:
npm run ios -- --simulator 'iPhone 17 Pro'
# Or:
npm run android
```

Metro runs on 8093. iOS needs Xcode 26+. Android needs the Android SDK, Java, and an emulator/device. The library itself does not require Expo. See the root README and `docs/verification.md` for implementation scope and tested behavior.
