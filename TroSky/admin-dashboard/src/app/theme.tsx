import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'

import { localStore } from '@/lib/storage'

import { THEME_KEY, ThemeContext, type Theme } from './theme-context'

const DARK_QUERY = '(prefers-color-scheme: dark)'

function storedTheme(): Theme {
  const value = localStore.get(THEME_KEY)
  return value === 'light' || value === 'dark' ? value : 'system'
}

function systemDark(): boolean {
  return typeof window !== 'undefined' && window.matchMedia(DARK_QUERY).matches
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(storedTheme)
  const [prefersDark, setPrefersDark] = useState(systemDark)

  useEffect(() => {
    const media = window.matchMedia(DARK_QUERY)
    const onChange = () => setPrefersDark(media.matches)
    media.addEventListener('change', onChange)
    return () => media.removeEventListener('change', onChange)
  }, [])

  const resolvedTheme = theme === 'system' ? (prefersDark ? 'dark' : 'light') : theme

  useEffect(() => {
    document.documentElement.classList.toggle('dark', resolvedTheme === 'dark')
  }, [resolvedTheme])

  const setTheme = useCallback((next: Theme) => {
    setThemeState(next)
    if (next === 'system') localStore.remove(THEME_KEY)
    else localStore.set(THEME_KEY, next)
  }, [])

  const value = useMemo(
    () => ({ theme, resolvedTheme, setTheme }),
    [theme, resolvedTheme, setTheme],
  )
  return <ThemeContext value={value}>{children}</ThemeContext>
}
