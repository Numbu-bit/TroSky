import { Link, NavLink } from 'react-router'

import { formatNumber } from '@/lib/format'
import { cn } from '@/lib/utils'

export interface ScreenTab {
  to: string
  label: string
  /** Match the path exactly (the screen's first tab). */
  end?: boolean
  /** A count shown after the label, e.g. items waiting. */
  count?: number
  /** For tabs told apart by the query string: whether this one is showing. */
  active?: boolean
}

const tabClass = (active: boolean) =>
  cn(
    '-mb-px inline-flex shrink-0 items-center gap-1.5 border-b-2 px-3 py-2 text-sm font-medium',
    active
      ? 'border-brand text-foreground'
      : 'border-transparent text-muted-foreground hover:text-foreground',
  )

function Count({ value }: { value?: number }) {
  return value ? (
    <span className="figure rounded-full bg-muted px-1.5 text-xs text-muted-foreground">
      {formatNumber(value)}
    </span>
  ) : null
}

/** A screen's sections as links, so each has its own URL. Hidden when only one. */
export function ScreenTabs({ label, tabs }: { label: string; tabs: ScreenTab[] }) {
  if (tabs.length < 2) return null
  return (
    <nav aria-label={label} className="mb-4 flex gap-1 overflow-x-auto border-b">
      {tabs.map((tab) =>
        tab.active === undefined ? (
          <NavLink
            key={tab.to}
            to={tab.to}
            end={tab.end}
            className={({ isActive }) => tabClass(isActive)}
          >
            {tab.label}
            <Count value={tab.count} />
          </NavLink>
        ) : (
          <Link
            key={tab.to}
            to={tab.to}
            className={tabClass(tab.active)}
            aria-current={tab.active ? 'page' : undefined}
          >
            {tab.label}
            <Count value={tab.count} />
          </Link>
        ),
      )}
    </nav>
  )
}
