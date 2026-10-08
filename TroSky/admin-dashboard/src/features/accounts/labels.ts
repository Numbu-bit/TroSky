import type { Tone } from '@/components/status/StatusBadge'

export const ROLE_NAMES: Record<string, string> = {
  passenger: 'Passenger',
  driver: 'Driver',
  fleet_owner: 'Fleet owner',
  admin: 'Admin',
  super_admin: 'Super admin',
  staff: 'Staff',
}

/** Suspended (by an admin), closed (inactive) or active. */
export function accountStatus(account: { is_active: boolean; is_suspended: boolean }): {
  tone: Tone
  label: string
} {
  if (account.is_suspended) return { tone: 'danger', label: 'Suspended' }
  if (!account.is_active) return { tone: 'neutral', label: 'Closed' }
  return { tone: 'success', label: 'Active' }
}
