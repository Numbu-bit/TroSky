/**
 * Browser storage, for per-viewer conveniences only (theme, data-saver,
 * the refresh token for this tab). Storage can be missing or throw (private
 * windows, blocked site data), so every access is guarded and callers get a
 * fallback instead of an exception.
 */

type Area = 'local' | 'session'

function area(kind: Area): Storage | null {
  try {
    return kind === 'local' ? window.localStorage : window.sessionStorage
  } catch {
    return null
  }
}

function read(kind: Area, key: string): string | null {
  try {
    return area(kind)?.getItem(key) ?? null
  } catch {
    return null
  }
}

function write(kind: Area, key: string, value: string | null): void {
  try {
    const store = area(kind)
    if (!store) return
    if (value === null) store.removeItem(key)
    else store.setItem(key, value)
  } catch {
    // Quota exceeded or storage disabled: the convenience is simply lost.
  }
}

export const sessionStore = {
  get: (key: string) => read('session', key),
  set: (key: string, value: string) => write('session', key, value),
  remove: (key: string) => write('session', key, null),
}

export const localStore = {
  get: (key: string) => read('local', key),
  set: (key: string, value: string) => write('local', key, value),
  remove: (key: string) => write('local', key, null),
}
