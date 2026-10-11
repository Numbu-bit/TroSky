import { rmSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { loadEnv, type Plugin } from 'vite'
import { defineConfig } from 'vitest/config'

/** Real deployments don't carry demo mode's service worker (copied from public/). */
function dropDemoWorker(): Plugin {
  let outDir = 'dist'
  return {
    name: 'trosky:drop-demo-worker',
    apply: 'build',
    configResolved(config) {
      outDir = resolve(config.root, config.build.outDir)
    },
    closeBundle() {
      rmSync(resolve(outDir, 'mockServiceWorker.js'), { force: true })
    },
  }
}

export default defineConfig(({ command, mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const demo = env.VITE_DEMO_MODE === 'true'
  // Demo data must never reach a real deployment by accident: only a demo
  // build (--mode demo, "npm run build:demo") may have demo mode on.
  if (command === 'build' && mode !== 'demo' && demo) {
    throw new Error(
      `Refusing a "${mode}" build with VITE_DEMO_MODE=true. Use "npm run build:demo" for a demo deployment.`,
    )
  }
  return {
    plugins: [react(), tailwindcss(), ...(demo ? [] : [dropDemoWorker()])],
    resolve: {
      alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
    },
    server: {
      port: 5173,
      // In development the API is reached through this proxy, so the browser
      // only ever talks to one origin (no CORS set-up needed on the backend).
      proxy: {
        '/api': {
          target: env.VITE_API_PROXY_TARGET || 'http://127.0.0.1:8000',
          changeOrigin: true,
        },
      },
    },
    build: {
      target: 'es2022',
      sourcemap: true,
    },
    test: {
      globals: true,
      environment: 'jsdom',
      setupFiles: ['./src/test/setup.ts'],
      css: false,
      include: ['src/**/*.test.{ts,tsx}'],
      restoreMocks: true,
      // Above the tests' own 60 s wait for the page (src/test/setup.ts).
      testTimeout: 120_000,
      // jsdom tests are CPU-heavy: fewer workers contend less, and finish sooner.
      maxWorkers: '50%',
      env: {
        VITE_API_BASE_URL: 'http://localhost/api/v1',
        VITE_DEMO_MODE: 'false',
        VITE_ENABLED_MODULES:
          'dispatch,driver-performance,fleet,revenue,user-growth,complaints-insights,fraud,demand,reports,audit-log,settings,wallets,alerts,team',
      },
      coverage: {
        provider: 'v8',
        include: ['src/**/*.{ts,tsx}'],
        exclude: [
          'src/**/*.test.{ts,tsx}',
          'src/test/**',
          'src/api/schema.d.ts',
          'src/main.tsx',
          'src/vite-env.d.ts',
        ],
        thresholds: { lines: 80 },
      },
    },
  }
})
