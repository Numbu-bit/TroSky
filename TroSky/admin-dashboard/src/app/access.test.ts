import { isModuleEnabled } from '@/lib/modules'
import { hasAny, PERMISSIONS } from '@/lib/permissions'

import { safeNext } from './auth/next'
import { canOpen, SCREENS, screenByKey, screenPath } from './screens'

describe('where to go after signing in', () => {
  it('stays inside the dashboard', () => {
    expect(safeNext('/trips?status=scheduled')).toBe('/trips?status=scheduled')
    expect(safeNext(null)).toBe('/overview')
    expect(safeNext('https://evil.example')).toBe('/overview')
    expect(safeNext('//evil.example')).toBe('/overview')
    expect(safeNext('/\\evil.example')).toBe('/overview')
    expect(safeNext('/login')).toBe('/overview')
  })
})

describe('permissions', () => {
  it('need any one of those listed', () => {
    const granted = new Set(['complaints:manage'])
    expect(hasAny(granted, ['complaints:manage', 'sos:review'])).toBe(true)
    expect(hasAny(granted, ['sos:review'])).toBe(false)
    expect(hasAny(granted, [])).toBe(true)
    expect(hasAny(granted, undefined)).toBe(true)
  })

  it('are the backend’s 23', () => {
    expect(PERMISSIONS).toHaveLength(23)
  })
})

describe('screens', () => {
  it('each open to those holding their permissions', () => {
    const everything = new Set<string>(PERMISSIONS)
    expect(SCREENS.every((screen) => canOpen(screen, everything))).toBe(true)
    const support = new Set(['complaints:manage'])
    expect(canOpen(screenByKey('complaints'), support)).toBe(true)
    expect(canOpen(screenByKey('payouts'), support)).toBe(false)
    expect(canOpen(screenByKey('overview'), new Set())).toBe(true)
  })

  it('have unique keys and paths', () => {
    expect(new Set(SCREENS.map((screen) => screen.key)).size).toBe(SCREENS.length)
    expect(new Set(SCREENS.map((screen) => screen.path)).size).toBe(SCREENS.length)
    expect(screenPath('trips')).toBe('/trips')
    expect(() => screenByKey('nope')).toThrow()
  })
})

describe('module switches', () => {
  it('show a module only when switched on, or in demo mode', () => {
    expect(isModuleEnabled('fraud', ['fraud'], false)).toBe(true)
    expect(isModuleEnabled('fraud', ['revenue'], false)).toBe(false)
    expect(isModuleEnabled('fraud', [], true)).toBe(true)
  })
})
