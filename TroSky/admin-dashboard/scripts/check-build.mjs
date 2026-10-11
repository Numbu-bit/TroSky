// Checks a production build in dist/ before it ships:
//   - no demo data: demo accounts, seed builders or the demo's service worker
//   - the JavaScript loaded up front (the entry and what it preloads) stays
//     within the spec's 250 KB gzipped budget; the rest loads per screen.
// Usage: node scripts/check-build.mjs [dist]
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { gzipSync } from 'node:zlib'

const dist = resolve(process.argv[2] ?? 'dist')
const BUDGET_KB = 250
// Strings only the demo carries (src/api/demo): its password, its accounts'
// email domain and its seed builder.
const DEMO_MARKERS = ['TroSky-demo-2026', '@trosky.test', 'buildDemoDb', 'setupWorker']

const problems = []

function files(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name)
    return statSync(path).isDirectory() ? files(path) : [path]
  })
}

if (!existsSync(join(dist, 'index.html'))) {
  console.error(`No build in ${dist}: run "npm run build" first.`)
  process.exit(1)
}

// ---- no demo data
if (existsSync(join(dist, 'mockServiceWorker.js'))) {
  problems.push('mockServiceWorker.js is in the build (demo mode only).')
}
for (const file of files(dist).filter((path) => /\.(js|html|css|json)$/.test(path))) {
  const text = readFileSync(file, 'utf8')
  for (const marker of DEMO_MARKERS) {
    if (text.includes(marker)) problems.push(`${file} contains demo data ("${marker}").`)
  }
}

// ---- initial JavaScript
const html = readFileSync(join(dist, 'index.html'), 'utf8')
const initial = [
  ...html.matchAll(/<script[^>]+type="module"[^>]+src="([^"]+)"/g),
  ...html.matchAll(/<link[^>]+rel="modulepreload"[^>]+href="([^"]+)"/g),
].map((match) => match[1])
let total = 0
for (const src of new Set(initial)) {
  const size = gzipSync(readFileSync(join(dist, src.replace(/^\//, ''))), { level: 9 }).length
  total += size
  console.log(`  ${(size / 1024).toFixed(1).padStart(7)} KB  ${src}`)
}
console.log(
  `  ${(total / 1024).toFixed(1).padStart(7)} KB  initial JavaScript, gzipped (budget ${BUDGET_KB} KB)`,
)
if (total > BUDGET_KB * 1024) {
  problems.push(
    `Initial JavaScript is ${(total / 1024).toFixed(1)} KB gzipped, over ${BUDGET_KB} KB.`,
  )
}

if (problems.length) {
  console.error(`\nThe build is not fit to ship:\n- ${problems.join('\n- ')}`)
  process.exit(1)
}
console.log('\nNo demo data, and within budget.')
