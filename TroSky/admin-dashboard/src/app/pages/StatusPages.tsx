import { Compass, Lock, RefreshCw, TriangleAlert } from 'lucide-react'
import type { ReactNode } from 'react'
import { isRouteErrorResponse, Link, useRouteError } from 'react-router'

import { Button } from '@/components/ui/button'

function StatusPage({
  icon,
  title,
  children,
  action,
}: {
  icon: ReactNode
  title: string
  children: ReactNode
  action?: ReactNode
}) {
  return (
    <div className="mx-auto flex max-w-md flex-col items-center gap-3 py-16 text-center">
      <div className="rounded-full bg-muted p-4 text-muted-foreground">{icon}</div>
      <h1 className="text-xl">{title}</h1>
      <div className="text-sm text-muted-foreground">{children}</div>
      {action ?? (
        <Button asChild>
          <Link to="/overview">Go to Overview</Link>
        </Button>
      )}
    </div>
  )
}

export function ForbiddenPage() {
  return (
    <StatusPage
      icon={<Lock className="size-7" aria-hidden />}
      title="You don’t have access to this page"
    >
      Your account doesn’t include the permission this page needs. Ask a super admin if you should
      have it.
    </StatusPage>
  )
}

export function NotFoundPage() {
  return (
    <StatusPage icon={<Compass className="size-7" aria-hidden />} title="Page not found">
      The link may be old, or this part of the dashboard is switched off.
    </StatusPage>
  )
}

/** A route that crashed or a page chunk that failed to load. */
export function RouteErrorPage() {
  const error = useRouteError()
  const chunkFailed =
    error instanceof Error &&
    /dynamically imported module|Importing a module script failed|Failed to fetch/i.test(
      error.message,
    )
  if (isRouteErrorResponse(error) && error.status === 404) return <NotFoundPage />
  return (
    <StatusPage
      icon={<TriangleAlert className="size-7" aria-hidden />}
      title={chunkFailed ? 'This page couldn’t be loaded' : 'Something went wrong on this page'}
      action={
        <Button onClick={() => window.location.reload()}>
          <RefreshCw aria-hidden /> Reload
        </Button>
      }
    >
      {chunkFailed
        ? 'Check your connection, or reload: the dashboard may have been updated.'
        : 'Reload to try again. If it keeps happening, tell the platform team what you were doing.'}
    </StatusPage>
  )
}
