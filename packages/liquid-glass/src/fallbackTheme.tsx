import React, {createContext, useContext, useMemo} from 'react';
import {useColorScheme, type ColorValue} from 'react-native';

/** Colours for the opaque surfaces used on Android, in forceFallback mode, and by solid fallbacks. */
export interface GlassFallbackTheme {
  /** Surface fill for fallback surfaces, buttons, segmented tracks and menus. */
  surface?: {light: ColorValue; dark: ColorValue};
  /** Text and glyph colour on those surfaces. */
  foreground?: {light: ColorValue; dark: ColorValue};
}

const ThemeContext = createContext<GlassFallbackTheme>({});

/** Supplies fallback colours to every glass component below it. Unset colours keep the defaults. */
export function GlassFallbackThemeProvider({value, children}: {value: GlassFallbackTheme; children: React.ReactNode}) {
  const parent = useContext(ThemeContext);
  const merged = useMemo(() => ({...parent, ...value}), [parent, value]);
  return <ThemeContext.Provider value={merged}>{children}</ThemeContext.Provider>;
}

/**
 * Resolves themed fallback colours for a colour scheme. Unthemed colours are undefined, so each
 * component keeps its own default and the provider is purely an override.
 */
export function useFallbackColors(colorScheme: 'system' | 'light' | 'dark' = 'system'):
  {dark: boolean; surface: ColorValue | undefined; foreground: ColorValue | undefined} {
  const theme = useContext(ThemeContext);
  const system = useColorScheme();
  const dark = (colorScheme === 'system' ? system : colorScheme) === 'dark';
  return {
    dark,
    surface: theme.surface && (dark ? theme.surface.dark : theme.surface.light),
    foreground: theme.foreground && (dark ? theme.foreground.dark : theme.foreground.light),
  };
}
