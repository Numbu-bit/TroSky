import { useEffect, type ReactNode } from 'react'
import { Navigate, useLocation } from 'react-router'

import { ForbiddenPage, NotFoundPage } from '@/app/pages/StatusPages'
import { canOpen, type Screen } from '@/app/screens'
import { FullPageSpinner } from '@/components/feedback/states'
import { isModuleEnabled } from '@/lib/modules'

import { useAuth, useSession } from './auth-context'

/** Signed-out admins go to sign in, and come back here afterwards. */
export function RequireAuth({ children }: { children: ReactNode }) {
  const { state } = useAuth()
  const location = useLocation()
  if (state.status === 'loading') return <FullPageSpinner label="Checking your session" />
  if (state.status === 'signed-out') {
    const here = `${location.pathname}${location.search}`
    const comeBack = state.reason !== 'signed-out' && here !== '/' && here !== '/login'
    return <Navigate to={comeBack ? `/login?next=${encodeURIComponent(here)}` : '/login'} replace />
  }
  return <>{children}</>
}

/** A screen, if it is switched on and the admin may open it. */
export function ScreenRoute({ screen }: { screen: Screen }) {
  const { permissions } = useSession()

  useEffect(() => {
    document.title = `${screen.label} · TroSky Admin`
  }, [screen.label])

  if (screen.module && !isModuleEnabled(screen.module)) return <NotFoundPage />
  if (!canOpen(screen, permissions)) return <ForbiddenPage />
  return <screen.Component />
}
