import {
  BadgeCheck,
  Banknote,
  BellRing,
  Bus,
  CarFront,
  ChartNoAxesCombined,
  FileSpreadsheet,
  Flame,
  Gauge,
  LayoutDashboard,
  MapPinned,
  MessageSquareWarning,
  RadioTower,
  ScanEye,
  ScrollText,
  Settings,
  ShieldAlert,
  Star,
  Ticket,
  TrendingUp,
  UserCog,
  Users,
  Wallet,
  Waypoints,
  type LucideIcon,
} from 'lucide-react'
import { lazy, type ComponentType, type LazyExoticComponent } from 'react'

import { isModuleEnabled, type ModuleKey } from '@/lib/modules'
import { hasAny, type Permission } from '@/lib/permissions'

export type NavGroup = 'monitor' | 'operate' | 'money' | 'support' | 'insights' | 'admin'

export const NAV_GROUPS: { key: NavGroup; label: string }[] = [
  { key: 'monitor', label: 'Monitor' },
  { key: 'operate', label: 'Operate' },
  { key: 'money', label: 'Money' },
  { key: 'support', label: 'Support' },
  { key: 'insights', label: 'Insights' },
  { key: 'admin', label: 'Administration' },
]

export interface Screen {
  key: string
  /** Under the app root, e.g. "trips" (its own sub-routes live inside it). */
  path: string
  label: string
  icon: LucideIcon
  group: NavGroup | null
  /** Any one of these opens the screen; none listed means any admin. */
  permissions: Permission[]
  /** Switched modules (spec section 7) appear only when switched on. */
  module?: ModuleKey
  Component: LazyExoticComponent<ComponentType>
}

export const SCREENS: Screen[] = [
  {
    key: 'overview',
    path: 'overview',
    label: 'Overview',
    icon: LayoutDashboard,
    group: 'monitor',
    permissions: [],
    Component: lazy(() => import('@/features/overview/OverviewPage')),
  },
  {
    key: 'live-map',
    path: 'live',
    label: 'Live map',
    icon: MapPinned,
    group: 'monitor',
    permissions: ['trips:monitor_live', 'trips:manage'],
    Component: lazy(() => import('@/features/live-map/LiveMapPage')),
  },
  {
    key: 'alerts',
    path: 'alerts',
    label: 'Alerts',
    icon: BellRing,
    group: 'monitor',
    permissions: [
      'sos:review',
      'complaints:manage',
      'drivers:approve',
      'vehicles:approve',
      'fraud:view',
      'fraud:manage',
      'trips:manage',
      'trips:monitor_live',
    ],
    module: 'alerts',
    Component: lazy(() => import('@/features/alerts/AlertsPage')),
  },
  {
    key: 'safety',
    path: 'safety',
    label: 'Safety',
    icon: ShieldAlert,
    group: 'monitor',
    permissions: ['sos:review', 'incidents:manage'],
    Component: lazy(() => import('@/features/safety/SafetyPage')),
  },
  {
    key: 'trips',
    path: 'trips',
    label: 'Trips',
    icon: Bus,
    group: 'operate',
    permissions: ['trips:manage', 'trips:monitor_live'],
    Component: lazy(() => import('@/features/trips/TripsScreen')),
  },
  {
    key: 'dispatch',
    path: 'dispatch',
    label: 'Dispatch',
    icon: RadioTower,
    group: 'operate',
    permissions: ['trips:manage', 'trips:monitor_live'],
    module: 'dispatch',
    Component: lazy(() => import('@/features/dispatch/DispatchPage')),
  },
  {
    key: 'network',
    path: 'network',
    label: 'Network',
    icon: Waypoints,
    group: 'operate',
    permissions: ['routes:manage'],
    Component: lazy(() => import('@/features/network/NetworkScreen')),
  },
  {
    key: 'approvals',
    path: 'approvals',
    label: 'Approvals',
    icon: BadgeCheck,
    group: 'operate',
    permissions: ['drivers:approve', 'vehicles:approve'],
    Component: lazy(() => import('@/features/approvals/ApprovalsScreen')),
  },
  {
    key: 'fleet',
    path: 'fleet',
    label: 'Fleet',
    icon: CarFront,
    group: 'operate',
    permissions: ['vehicles:approve', 'drivers:approve', 'trips:monitor_live', 'reports:view'],
    module: 'fleet',
    Component: lazy(() => import('@/features/fleet/FleetScreen')),
  },
  {
    key: 'bookings',
    path: 'bookings',
    label: 'Bookings & refunds',
    icon: Ticket,
    group: 'money',
    permissions: ['bookings:view_any', 'refunds:approve'],
    Component: lazy(() => import('@/features/bookings/BookingsScreen')),
  },
  {
    key: 'payouts',
    path: 'payouts',
    label: 'Payouts',
    icon: Banknote,
    group: 'money',
    permissions: ['withdrawals:review'],
    Component: lazy(() => import('@/features/payouts/PayoutsPage')),
  },
  {
    key: 'revenue',
    path: 'revenue',
    label: 'Revenue',
    icon: TrendingUp,
    group: 'money',
    permissions: ['payments:review', 'refunds:approve', 'reports:view'],
    module: 'revenue',
    Component: lazy(() => import('@/features/revenue/RevenuePage')),
  },
  {
    key: 'wallets',
    path: 'wallets',
    label: 'Wallets',
    icon: Wallet,
    group: 'money',
    permissions: ['wallet:adjust'],
    module: 'wallets',
    Component: lazy(() => import('@/features/wallets/WalletsPage')),
  },
  {
    key: 'complaints',
    path: 'complaints',
    label: 'Complaints',
    icon: MessageSquareWarning,
    group: 'support',
    permissions: ['complaints:manage'],
    Component: lazy(() => import('@/features/complaints/ComplaintsScreen')),
  },
  {
    key: 'accounts',
    path: 'accounts',
    label: 'Accounts',
    icon: Users,
    group: 'support',
    permissions: ['users:manage', 'users:suspend'],
    Component: lazy(() => import('@/features/accounts/AccountsScreen')),
  },
  {
    key: 'driver-ratings',
    path: 'driver-ratings',
    label: 'Driver ratings',
    icon: Star,
    group: 'insights',
    permissions: ['drivers:approve'],
    Component: lazy(() => import('@/features/driver-ratings/DriverRatingsPage')),
  },
  {
    key: 'driver-performance',
    path: 'driver-performance',
    label: 'Driver performance',
    icon: Gauge,
    group: 'insights',
    permissions: ['reports:view', 'drivers:approve'],
    module: 'driver-performance',
    Component: lazy(() => import('@/features/driver-performance/DriverPerformanceScreen')),
  },
  {
    key: 'user-growth',
    path: 'user-growth',
    label: 'User growth',
    icon: ChartNoAxesCombined,
    group: 'insights',
    permissions: ['reports:view'],
    module: 'user-growth',
    Component: lazy(() => import('@/features/user-growth/UserGrowthPage')),
  },
  {
    key: 'demand',
    path: 'demand',
    label: 'Demand map',
    icon: Flame,
    group: 'insights',
    permissions: ['reports:view'],
    module: 'demand',
    Component: lazy(() => import('@/features/demand/DemandPage')),
  },
  {
    key: 'reports',
    path: 'reports',
    label: 'Reports',
    icon: FileSpreadsheet,
    group: 'insights',
    permissions: ['reports:view'],
    module: 'reports',
    Component: lazy(() => import('@/features/reports/ReportsPage')),
  },
  {
    key: 'fraud',
    path: 'fraud',
    label: 'Fraud & risk',
    icon: ScanEye,
    group: 'insights',
    permissions: ['fraud:view', 'fraud:manage'],
    module: 'fraud',
    Component: lazy(() => import('@/features/fraud/FraudScreen')),
  },
  {
    key: 'team',
    path: 'team',
    label: 'Admin team',
    icon: UserCog,
    group: 'admin',
    permissions: ['admins:manage'],
    module: 'team',
    Component: lazy(() => import('@/features/team/TeamPage')),
  },
  {
    key: 'audit-log',
    path: 'audit-log',
    label: 'Audit log',
    icon: ScrollText,
    group: 'admin',
    permissions: ['audit_logs:view'],
    module: 'audit-log',
    Component: lazy(() => import('@/features/audit-log/AuditLogScreen')),
  },
  {
    key: 'settings',
    path: 'settings',
    label: 'Settings',
    icon: Settings,
    group: 'admin',
    permissions: ['system_settings:manage', 'feature_flags:manage'],
    module: 'settings',
    Component: lazy(() => import('@/features/settings/SettingsPage')),
  },
  {
    key: 'my-sessions',
    path: 'me/sessions',
    label: 'My sessions',
    icon: UserCog,
    group: null,
    permissions: [],
    Component: lazy(() => import('@/features/team/MySessionsPage')),
  },
]

/** Whether ``screen`` is switched on and open to an admin holding ``granted``. */
export function canOpen(screen: Screen, granted: ReadonlySet<string>): boolean {
  return (!screen.module || isModuleEnabled(screen.module)) && hasAny(granted, screen.permissions)
}

export function screenByKey(key: string): Screen {
  const screen = SCREENS.find((candidate) => candidate.key === key)
  if (!screen) throw new Error(`Unknown screen: ${key}`)
  return screen
}

/** "/trips" -- for links between screens. */
export function screenPath(key: string): string {
  return `/${screenByKey(key).path}`
}
