/**
 * The backend's permissions (app.core.permissions.Permission). What the
 * signed-in admin holds comes from GET /admin/me; every menu item, route
 * and action button is gated on these codes, exactly as the API enforces
 * them (see README: permission -> screen map).
 */
export const PERMISSIONS = [
  'users:manage',
  'users:suspend',
  'drivers:approve',
  'vehicles:approve',
  'fleets:manage_own',
  'routes:manage',
  'trips:manage',
  'trips:monitor_live',
  'bookings:view_any',
  'payments:review',
  'refunds:approve',
  'withdrawals:review',
  'wallet:adjust',
  'complaints:manage',
  'incidents:manage',
  'sos:review',
  'reports:view',
  'system_settings:manage',
  'feature_flags:manage',
  'audit_logs:view',
  'fraud:view',
  'fraud:manage',
  'admins:manage',
] as const

export type Permission = (typeof PERMISSIONS)[number]

export type AdminRole = 'super_admin' | 'admin' | 'staff'

/**
 * Whether ``granted`` includes at least one of ``required``. No requirement
 * means any signed-in admin.
 */
export function hasAny(
  granted: ReadonlySet<string>,
  required: readonly Permission[] | undefined,
): boolean {
  if (!required || required.length === 0) return true
  return required.some((permission) => granted.has(permission))
}

export const ROLE_LABELS: Record<AdminRole, string> = {
  super_admin: 'Super admin',
  admin: 'Admin',
  staff: 'Staff',
}

/** What each permission lets an admin do, in groups, for the team page. */
export const PERMISSION_GROUPS: {
  title: string
  permissions: { code: Permission; label: string }[]
}[] = [
  {
    title: 'Operations',
    permissions: [
      { code: 'trips:manage', label: 'Run trips and answer for drivers' },
      { code: 'trips:monitor_live', label: 'Watch trips live' },
      { code: 'routes:manage', label: 'Change stops, routes and timetables' },
      { code: 'drivers:approve', label: 'Approve drivers' },
      { code: 'vehicles:approve', label: 'Approve vehicles' },
      { code: 'fleets:manage_own', label: 'Manage their own fleet' },
    ],
  },
  {
    title: 'Money',
    permissions: [
      { code: 'bookings:view_any', label: 'See and cancel any booking' },
      { code: 'payments:review', label: 'See payments' },
      { code: 'refunds:approve', label: 'Approve refunds and late cancellations' },
      { code: 'withdrawals:review', label: 'Decide payouts' },
      { code: 'wallet:adjust', label: 'Adjust wallets' },
    ],
  },
  {
    title: 'Support and safety',
    permissions: [
      { code: 'complaints:manage', label: 'Handle complaints' },
      { code: 'incidents:manage', label: 'Resolve incidents' },
      { code: 'sos:review', label: 'Handle SOS alerts' },
      { code: 'users:manage', label: 'Look up accounts and their devices' },
      { code: 'users:suspend', label: 'Suspend and reactivate accounts' },
      { code: 'fraud:view', label: 'See fraud flags' },
      { code: 'fraud:manage', label: 'Review fraud and act on accounts' },
    ],
  },
  {
    title: 'Platform',
    permissions: [
      { code: 'reports:view', label: 'See reports and analytics' },
      { code: 'audit_logs:view', label: 'See the audit log' },
      { code: 'system_settings:manage', label: 'Change platform settings' },
      { code: 'feature_flags:manage', label: 'Change feature flags' },
      { code: 'admins:manage', label: 'Manage the admin team' },
    ],
  },
]
