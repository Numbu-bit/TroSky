import { useQueryClient } from '@tanstack/react-query'
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { toast } from 'sonner'

import { api, onSessionEnded, refreshSession, unwrap } from '@/api/client'
import { isApiError } from '@/api/errors'
import { tokenStore } from '@/api/tokens'

import { AuthContext, NotOnTeamError, type AdminMe, type AuthState } from './auth-context'

async function fetchMe(): Promise<AdminMe> {
  return unwrap(api.GET('/api/v1/admin/me'))
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient()
  const [state, setState] = useState<AuthState>({ status: 'loading' })

  const signIn = useCallback((me: AdminMe) => {
    setState({ status: 'signed-in', me, permissions: new Set(me.permissions) })
  }, [])

  const endSession = useCallback(
    (reason: 'expired' | 'signed-out') => {
      tokenStore.clear()
      queryClient.clear()
      setState({ status: 'signed-out', reason })
    },
    [queryClient],
  )

  // A reload of this tab: the refresh token (sessionStorage) buys a new
  // access token, which says who is signed in.
  useEffect(() => {
    let cancelled = false
    async function restore() {
      if (!tokenStore.access && !(await refreshSession())) {
        if (!cancelled) setState({ status: 'signed-out' })
        return
      }
      try {
        const me = await fetchMe()
        if (!cancelled) signIn(me)
      } catch {
        tokenStore.clear()
        if (!cancelled) setState({ status: 'signed-out' })
      }
    }
    void restore()
    return () => {
      cancelled = true
    }
  }, [signIn])

  useEffect(() => {
    onSessionEnded(() => {
      toast.error('Your session has ended. Sign in again to carry on.')
      endSession('expired')
    })
    return () => onSessionEnded(() => {})
  }, [endSession])

  const login = useCallback(
    async (identifier: string, password: string) => {
      const pair = await unwrap(
        api.POST('/api/v1/auth/login', { body: { identifier: identifier.trim(), password } }),
      )
      tokenStore.set(pair)
      try {
        signIn(await fetchMe())
      } catch (error) {
        // Right password, wrong kind of account: leave nothing signed in.
        await api.POST('/api/v1/auth/logout').catch(() => undefined)
        tokenStore.clear()
        if (isApiError(error, 403)) throw new NotOnTeamError()
        throw error
      }
    },
    [signIn],
  )

  const logout = useCallback(async () => {
    await api.POST('/api/v1/auth/logout').catch(() => undefined)
    endSession('signed-out')
  }, [endSession])

  const value = useMemo(() => ({ state, login, logout }), [state, login, logout])
  return <AuthContext value={value}>{children}</AuthContext>
}
