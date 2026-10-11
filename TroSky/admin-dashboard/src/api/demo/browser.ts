import { setupWorker } from 'msw/browser'

import { getDb, index } from './db'
import { fraudState } from './db/fraud'
import { platformState } from './db/platform'
import { handlers } from './handlers'

/** Starts answering every API request in this browser tab with demo data. */
export async function startDemoWorker(): Promise<void> {
  // Build the demo platform before the app starts. The worker asks this page
  // about every request, scripts included, so building it on the first API
  // call would hold up whatever else was loading meanwhile.
  getDb()
  index()
  fraudState()
  platformState()
  const worker = setupWorker(...handlers)
  await worker.start({
    onUnhandledRequest: 'bypass',
    quiet: true,
    serviceWorker: { url: `${import.meta.env.BASE_URL}mockServiceWorker.js` },
  })
}
