import { FlaskConical } from 'lucide-react'
import { lazy, Suspense, type ReactNode } from 'react'

import { Separator } from '@/components/ui/separator'
import { SidebarTrigger } from '@/components/ui/sidebar'
import { env } from '@/lib/env'

import { ProfileMenu } from './ProfileMenu'
import { ThemeToggle } from './ThemeToggle'

// Demo builds only: production bundles never include the demo controls.
const DemoMenu =
  import.meta.env.VITE_DEMO_MODE === 'true' ? lazy(() => import('@/api/demo/DemoMenu')) : null

/** Always visible in demo mode; opens the demo controls once they load. */
export function DemoBadge() {
  if (!env.demoMode) return null
  const badge = (
    <span
      className="inline-flex items-center gap-1 rounded-md bg-gold px-2 py-1 text-xs font-bold tracking-wide text-gold-foreground"
      title="Everything on screen is realistic fake data; nothing reaches the real platform."
    >
      <FlaskConical className="size-3.5" aria-hidden />
      DEMO DATA
    </span>
  )
  if (!DemoMenu) return badge
  return (
    <Suspense fallback={badge}>
      <DemoMenu />
    </Suspense>
  )
}

/** The bar above every page. ``tools`` holds search, live status and alerts. */
export function TopBar({ tools }: { tools?: ReactNode }) {
  return (
    <header className="sticky top-0 z-20 flex h-14 shrink-0 items-center gap-2 border-b bg-card/95 px-3 backdrop-blur supports-[backdrop-filter]:bg-card/80 sm:px-4">
      <SidebarTrigger aria-label="Show or hide the menu" />
      <Separator orientation="vertical" className="mx-1 !h-5" />
      <DemoBadge />
      <div className="flex min-w-0 flex-1 items-center justify-end gap-1 sm:gap-2">
        {tools}
        <ThemeToggle />
        <ProfileMenu />
      </div>
    </header>
  )
}
