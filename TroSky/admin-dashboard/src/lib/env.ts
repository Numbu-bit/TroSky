const raw = import.meta.env

function clamp(value: number, min: number, max: number): number {
  return Number.isFinite(value) ? Math.min(Math.max(value, min), max) : min
}

export const env = {
  /** e.g. "/api/v1" (dev proxy) or "https://api.example.com/api/v1". */
  apiBaseUrl: raw.VITE_API_BASE_URL || '/api/v1',
  demoMode: raw.VITE_DEMO_MODE === 'true',
  enabledModules: (raw.VITE_ENABLED_MODULES ?? '')
    .split(',')
    .map((key) => key.trim())
    .filter(Boolean),
  /** Live data refresh, 5-10 s (SRS FR-006). */
  liveRefreshSeconds: clamp(Number(raw.VITE_LIVE_REFRESH_SECONDS ?? 8), 5, 10),
} as const

/**
 * What the generated API paths (which start "/api/v1/...") are appended to:
 * the base URL without its "/api/v1" suffix. Empty for a same-origin API.
 */
export const apiOrigin = env.apiBaseUrl.replace(/\/api\/v1\/?$/, '')
