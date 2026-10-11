import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import { App } from './app/App'
import './index.css'

/**
 * Demo mode answers every request in the browser (Mock Service Worker).
 * The check is on the raw env value so that, in every other build, the
 * whole demo bundle is dropped as dead code.
 */
async function startDemoMode(): Promise<void> {
  if (import.meta.env.VITE_DEMO_MODE !== 'true') return
  const { startDemoWorker } = await import('./api/demo/browser')
  await startDemoWorker()
}

void startDemoMode().then(() => {
  const root = document.getElementById('root')
  if (!root) throw new Error('No #root element in index.html')
  createRoot(root).render(
    <StrictMode>
      <App />
    </StrictMode>,
  )
})
