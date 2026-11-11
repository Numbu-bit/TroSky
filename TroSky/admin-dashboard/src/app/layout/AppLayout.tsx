import { Suspense } from 'react'
import { Outlet, useLocation } from 'react-router'

import { PageSkeleton } from '@/components/feedback/states'
import { WidgetBoundary } from '@/components/feedback/WidgetBoundary'
import { SidebarInset, SidebarProvider } from '@/components/ui/sidebar'

import { LiveProvider } from '../live/LiveProvider'
import { AccountSearch } from './AccountSearch'
import { AppSidebar } from './AppSidebar'
import { LiveIndicator } from './LiveIndicator'
import { NotificationsMenu } from './NotificationsMenu'
import { SosBanner } from './SosBanner'
import { TopBar } from './TopBar'

export function AppLayout() {
  const { pathname } = useLocation()
  return (
    <LiveProvider>
      <SidebarProvider>
        <a
          href="#main"
          className="sr-only z-50 rounded-md bg-primary px-3 py-2 text-primary-foreground focus:not-sr-only focus:fixed focus:top-2 focus:left-2"
        >
          Skip to content
        </a>
        <AppSidebar />
        {/* SidebarInset is the page's one <main> landmark. min-w-0 keeps it to the
            space beside the sidebar: without it a wide page widens the whole window,
            and scrolling sideways slides the top bar over the sidebar. */}
        <SidebarInset id="main" tabIndex={-1} className="min-w-0 outline-none">
          <TopBar
            tools={
              <>
                <AccountSearch />
                <LiveIndicator />
                <NotificationsMenu />
              </>
            }
          />
          <SosBanner />
          {/* Anything still too wide scrolls here, under a top bar that stays put. */}
          <div className="min-w-0 flex-1 overflow-x-auto p-4 sm:p-6">
            {/* A new page starts without the last page's failure. */}
            <WidgetBoundary key={pathname} title="This page failed">
              <Suspense fallback={<PageSkeleton />}>
                <Outlet />
              </Suspense>
            </WidgetBoundary>
          </div>
        </SidebarInset>
      </SidebarProvider>
    </LiveProvider>
  )
}
