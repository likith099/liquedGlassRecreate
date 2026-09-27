/**
 * @format
 */

import { AppRegistry, Appearance, Platform, Settings } from 'react-native';
import App from './App';
import { name as appName } from './app.json';

// UI tests pin the appearance with the launch argument `-ALGAppearance light|dark`, which iOS
// exposes through user defaults. It applies to UIKit views too, on every supported iOS version.
if (Platform.OS === 'ios') {
  const appearance = Settings.get('ALGAppearance');
  if (appearance === 'light' || appearance === 'dark') Appearance.setColorScheme(appearance);
}

AppRegistry.registerComponent(appName, () => App);
