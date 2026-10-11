import { createContext, useContext } from 'react'

import type { Schemas } from '@/api/types'
import type { AdminRole, Permission } from '@/lib/permissions'

export type AdminMe = Schemas['AdminMeResponse']

export type AuthState =
  | { status: 'loading' }
  | { status: 'signed-out'; reason?: 'expired' | 'signed-out' }
  | { status: 'signed-in'; me: AdminMe; permissions: ReadonlySet<string> }

export interface AuthContextValue {
  state: AuthState
  login: (identifier: string, password: string) => Promise<void>
  logout: () => Promise<void>
}

export const AuthContext = createContext<AuthContextValue | null>(null)

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext)
  if (!context) throw new Error('useAuth must be used inside <AuthProvider>.')
  return context
}

export interface Session {
  me: AdminMe
  role: AdminRole
  permissions: ReadonlySet<string>
  /** Whether the admin holds at least one of ``required`` (none: anyone). */
  can: (...required: Permission[]) => boolean
}

/** The signed-in admin. Only for screens behind <RequireAuth>. */
export function useSession(): Session {
  const { state } = useAuth()
  if (state.status !== 'signed-in') throw new Error('useSession needs a signed-in admin.')
  const { me, permissions } = state
  return {
    me,
    role: me.role,
    permissions,
    can: (...required) => required.length === 0 || required.some((p) => permissions.has(p)),
  }
}

/** Raised when the credentials are right but the account is not an admin. */
export class NotOnTeamError extends Error {
  constructor() {
    super('This account isn’t on the TroSky admin team.')
    this.name = 'NotOnTeamError'
  }
}
