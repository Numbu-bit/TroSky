import { env } from './env'

/**
 * Feature switches for the modules the spec planned (section 7). Every one
 * of them has endpoints in the backend today, so .env.example switches them
 * all on; leaving a key out of VITE_ENABLED_MODULES hides that module. In
 * demo mode they are all on.
 */
export const MODULE_KEYS = [
  'dispatch',
  'driver-performance',
  'fleet',
  'revenue',
  'user-growth',
  'complaints-insights',
  'fraud',
  'demand',
  'reports',
  'audit-log',
  'settings',
  'wallets',
  'alerts',
  'team',
] as const

export type ModuleKey = (typeof MODULE_KEYS)[number]

export function isModuleEnabled(
  key: ModuleKey,
  enabled: readonly string[] = env.enabledModules,
  demo: boolean = env.demoMode,
): boolean {
  return demo || enabled.includes(key)
}
