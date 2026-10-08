// Applies the saved theme before the app loads, so a dark-mode admin never
// sees a white flash. An external file, not inline, to keep the CSP strict.
// Keep the key in sync with src/app/theme.tsx.
;(function () {
  try {
    var saved = window.localStorage.getItem('trosky-admin:theme')
    var dark =
      saved === 'dark' ||
      (saved !== 'light' && window.matchMedia('(prefers-color-scheme: dark)').matches)
    if (dark) document.documentElement.classList.add('dark')
  } catch (e) {
    // Storage blocked: the app applies the device's theme once it loads.
  }
})()
