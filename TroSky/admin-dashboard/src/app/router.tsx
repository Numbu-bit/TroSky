import { lazy, Suspense } from 'react'
import { Navigate, type RouteObject } from 'react-router'

import { FullPageSpinner } from '@/components/feedback/states'

import { RequireAuth, ScreenRoute } from './auth/guards'
import { AppLayout } from './layout/AppLayout'
import { NotFoundPage, RouteErrorPage } from './pages/StatusPages'
import { SCREENS } from './screens'

// Sign-in (with its form libraries) loads only when it is needed.
const LoginPage = lazy(() => import('./auth/LoginPage'))

/**
 * Every screen is its own lazily loaded chunk (see screens.ts); each has a
 * Suspense fallback (AppLayout) and an error page of its own.
 */
export const routes: RouteObject[] = [
  {
    errorElement: <RouteErrorPage />,
    children: [
      {
        path: 'login',
        element: (
          <Suspense fallback={<FullPageSpinner />}>
            <LoginPage />
          </Suspense>
        ),
      },
      {
        element: (
          <RequireAuth>
            <AppLayout />
          </RequireAuth>
        ),
        children: [
          { index: true, element: <Navigate to="/overview" replace /> },
          ...SCREENS.map((screen): RouteObject => ({
            path: `${screen.path}/*`,
            element: <ScreenRoute screen={screen} />,
            errorElement: <RouteErrorPage />,
          })),
          { path: '*', element: <NotFoundPage /> },
        ],
      },
    ],
  },
]
