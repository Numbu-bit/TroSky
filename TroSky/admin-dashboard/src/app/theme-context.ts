import { createContext, useContext } from 'react'

export type Theme = 'light' | 'dark' | 'system'

/** Kept in sync with public/theme-init.js, which applies it before React loads. */
export const THEME_KEY = 'trosky-admin:theme'

export interface ThemeContextValue {
  theme: Theme
  resolvedTheme: 'light' | 'dark'
  setTheme: (theme: Theme) => void
}

export const ThemeContext = createContext<ThemeContextValue | null>(null)

export function useTheme(): ThemeContextValue {
  const context = useContext(ThemeContext)
  if (!context) throw new Error('useTheme must be used inside <ThemeProvider>.')
  return context
}
