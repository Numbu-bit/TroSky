/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string
  readonly VITE_DEMO_MODE?: string
  readonly VITE_ENABLED_MODULES?: string
  readonly VITE_LIVE_REFRESH_SECONDS?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
