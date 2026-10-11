import '@testing-library/jest-dom/vitest'

import { cleanup, configure } from '@testing-library/react'
import { afterAll, afterEach, beforeAll, beforeEach, vi } from 'vitest'

import { demoConfig, setFailRequests } from '@/api/demo/config'
import { tokenStore } from '@/api/tokens'

import { resetDemo, server } from './server'

// ---- browser APIs jsdom lacks, which Radix, the sidebar and charts use ----
if (!window.matchMedia) {
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: (query: string) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => false,
    }),
  })
}

class ResizeObserverStub {
  observe() {}
  unobserve() {}
  disconnect() {}
}
globalThis.ResizeObserver ??= ResizeObserverStub as unknown as typeof ResizeObserver

Element.prototype.scrollIntoView ??= function scrollIntoView() {}
Element.prototype.hasPointerCapture ??= () => false
Element.prototype.releasePointerCapture ??= () => {}
window.HTMLElement.prototype.scrollTo ??= function scrollTo() {}
// No WebGL here: maps show their "can't draw maps" fallback, quietly.
HTMLCanvasElement.prototype.getContext = (() => null) as unknown as HTMLCanvasElement['getContext']
URL.createObjectURL ??= () => 'blob:test'
URL.revokeObjectURL ??= () => {}

// A file's first test is slow: its lazily loaded screens are transformed
// on first use, and its first request builds the demo platform. With
// coverage on and every worker busy, that first render can take over 30 s.
configure({ asyncUtilTimeout: 60_000 })

// ---- a fixed clock ----
// The demo platform is built from the current time (which trips are on the
// road, recent incidents and alerts), so tests saw different data depending
// on the hour they ran. Every test starts at the same instant instead. Only
// Date is faked, and it runs on from there, so timers and waits are real.
const TEST_NOW = new Date('2026-10-11T15:20:00Z')

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'], shouldAdvanceTime: true })
  vi.setSystemTime(TEST_NOW)
})

// ---- the demo API, answering instantly ----
demoConfig.latency = [0, 0]

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => {
  cleanup()
  server.resetHandlers()
  tokenStore.clear()
  setFailRequests(false)
  resetDemo()
  document.cookie = 'sidebar_state=; max-age=0'
  vi.useRealTimers()
})
afterAll(() => server.close())
