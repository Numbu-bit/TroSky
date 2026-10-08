import { PERMISSIONS, type AdminRole, type Permission } from '@/lib/permissions'

export interface DemoAccount {
  id: string
  full_name: string
  phone_number: string
  email: string
  role: AdminRole
  permissions: Permission[]
  /** For the sign-in page's list. */
  summary: string
}

/** Every demo account signs in with this password. */
export const DEMO_PASSWORD = 'TroSky-demo-2026'

export const DEMO_ACCOUNTS: DemoAccount[] = [
  {
    id: '0b6f0f8e-5d0a-4c1e-9a51-6a3b2d000001',
    full_name: 'Abena Owusu',
    phone_number: '+233240000001',
    email: 'abena.owusu@trosky.test',
    role: 'super_admin',
    permissions: [...PERMISSIONS],
    summary: 'Super admin: everything, including the admin team',
  },
  {
    id: '0b6f0f8e-5d0a-4c1e-9a51-6a3b2d000002',
    full_name: 'Kwame Mensah',
    phone_number: '+233240000002',
    email: 'kwame.mensah@trosky.test',
    role: 'admin',
    permissions: [...PERMISSIONS],
    summary: 'Operations admin: every permission',
  },
  {
    id: '0b6f0f8e-5d0a-4c1e-9a51-6a3b2d000003',
    full_name: 'Esi Quaye',
    phone_number: '+233240000003',
    email: 'esi.quaye@trosky.test',
    role: 'staff',
    permissions: ['bookings:view_any', 'complaints:manage', 'reports:view', 'sos:review'],
    summary: 'Support staff: complaints, SOS, bookings (view) and reports only',
  },
]

export function accountByIdentifier(identifier: string): DemoAccount | undefined {
  const wanted = identifier.trim().toLowerCase()
  const local = wanted.replace(/\s/g, '').replace(/^0/, '+233')
  return DEMO_ACCOUNTS.find((account) => account.email === wanted || account.phone_number === local)
}

export function accountById(id: string): DemoAccount | undefined {
  return DEMO_ACCOUNTS.find((account) => account.id === id)
}

/** Admin team members who don't sign in to the demo: on the team list only. */
export interface TeamMember {
  id: string
  full_name: string
  phone_number: string
  email: string
  role: AdminRole
  permissions: Permission[]
  is_active: boolean
  is_suspended: boolean
  last_login_at: string | null
  created_at: string
}

export const TEAM_ONLY: TeamMember[] = [
  {
    id: '0b6f0f8e-5d0a-4c1e-9a51-6a3b2d000004',
    full_name: 'Yaw Boateng',
    phone_number: '+233240000004',
    email: 'yaw.boateng@trosky.test',
    role: 'staff',
    permissions: ['complaints:manage', 'bookings:view_any', 'incidents:manage'],
    is_active: true,
    is_suspended: false,
    last_login_at: '2026-10-03T16:20:00Z',
    created_at: '2026-02-11T09:00:00Z',
  },
  {
    id: '0b6f0f8e-5d0a-4c1e-9a51-6a3b2d000005',
    full_name: 'Akosua Darko',
    phone_number: '+233240000005',
    email: 'akosua.darko@trosky.test',
    role: 'staff',
    permissions: ['withdrawals:review', 'refunds:approve', 'payments:review'],
    is_active: true,
    is_suspended: false,
    last_login_at: '2026-10-02T11:05:00Z',
    created_at: '2026-04-02T09:00:00Z',
  },
]

// ------------------------------------------------------------ team changes
// The admin team page can add, change and remove members. Changes to a
// demo sign-in change what that sign-in may do; all of it resets with the
// demo (resetDemoTeam).
const ORIGINAL = DEMO_ACCOUNTS.map((account) => ({
  id: account.id,
  role: account.role,
  permissions: [...account.permissions],
}))
const ORIGINAL_TEAM_ONLY = TEAM_ONLY.map((member) => ({
  ...member,
  permissions: [...member.permissions],
}))
const added: TeamMember[] = []
const removed = new Set<string>()
/** When each demo sign-in last signed in (the backend's last_login_at). */
const signedIn = new Map<string, string>()

export function recordSignIn(id: string): void {
  signedIn.set(id, new Date().toISOString())
}

function signInMember(account: DemoAccount): TeamMember {
  return {
    id: account.id,
    full_name: account.full_name,
    phone_number: account.phone_number,
    email: account.email,
    role: account.role,
    permissions: account.permissions,
    is_active: true,
    is_suspended: false,
    last_login_at: signedIn.get(account.id) ?? null,
    created_at: '2025-09-01T09:00:00Z',
  }
}

/** Everyone on the admin team: the demo sign-ins, then the others. */
export function teamMembers(): TeamMember[] {
  return [...DEMO_ACCOUNTS.map(signInMember), ...TEAM_ONLY, ...added].filter(
    (member) => !removed.has(member.id),
  )
}

export function addTeamMember(member: TeamMember): void {
  removed.delete(member.id)
  added.push(member)
}

/** A new role, or the permissions a staff member holds. */
export function changeTeamMember(id: string, role: AdminRole, permissions: Permission[]): void {
  const account = DEMO_ACCOUNTS.find((candidate) => candidate.id === id)
  const member = account ?? [...TEAM_ONLY, ...added].find((candidate) => candidate.id === id)
  if (!member) return
  member.role = role
  member.permissions = role === 'staff' ? permissions : [...PERMISSIONS]
}

export function removeTeamMember(id: string): void {
  removed.add(id)
}

export function onTeam(id: string): boolean {
  return teamMembers().some((member) => member.id === id)
}

export function resetDemoTeam(): void {
  for (const original of ORIGINAL) {
    const account = DEMO_ACCOUNTS.find((candidate) => candidate.id === original.id)
    if (account) {
      account.role = original.role
      account.permissions = [...original.permissions]
    }
  }
  TEAM_ONLY.splice(
    0,
    TEAM_ONLY.length,
    ...ORIGINAL_TEAM_ONLY.map((member) => ({ ...member, permissions: [...member.permissions] })),
  )
  added.splice(0, added.length)
  removed.clear()
  signedIn.clear()
}
