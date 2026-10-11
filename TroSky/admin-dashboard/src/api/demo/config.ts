import { sessionStore } from '@/lib/storage'

const FAIL_KEY = 'trosky-admin:demo-fail'

/**
 * How the demo server behaves: 200-600 ms per answer in the browser (none
 * in tests), and an optional switch that makes every request fail, to show
 * the error states.
 */
export const demoConfig = {
  latency: [200, 600] as [number, number],
  failRequests: sessionStore.get(FAIL_KEY) === 'on',
}

export function setFailRequests(on: boolean): void {
  demoConfig.failRequests = on
  if (on) sessionStore.set(FAIL_KEY, 'on')
  else sessionStore.remove(FAIL_KEY)
}
