// Refresh openapi/openapi.json from a running backend (docs must be enabled
// there). Usage: API_ORIGIN=http://127.0.0.1:8000 npm run api:pull
import { writeFile } from 'node:fs/promises'

const origin = process.env.API_ORIGIN ?? 'http://127.0.0.1:8000'
const response = await fetch(`${origin}/openapi.json`)
if (!response.ok) {
  console.error(`Could not fetch ${origin}/openapi.json: ${response.status}`)
  process.exit(1)
}
const spec = await response.json()
await writeFile(new URL('../openapi/openapi.json', import.meta.url), JSON.stringify(spec, null, 1))
console.log(`openapi/openapi.json updated (${Object.keys(spec.paths).length} paths)`)
