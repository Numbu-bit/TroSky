/**
 * Where to go after signing in: only a path within this app, so a crafted
 * link cannot send an admin elsewhere ("//evil.example", "/\evil.example").
 */
export function safeNext(next: string | null): string {
  if (!next || !next.startsWith('/') || next.startsWith('//') || next.startsWith('/\\')) {
    return '/overview'
  }
  return next === '/login' ? '/overview' : next
}
