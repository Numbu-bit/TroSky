import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { LogOut, MonitorSmartphone } from 'lucide-react'
import { toast } from 'sonner'

import { api, unwrap } from '@/api/client'
import { errorMessage } from '@/api/errors'
import { useAuth } from '@/app/auth/auth-context'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { EmptyState, QueryState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Card, CardContent } from '@/components/ui/card'
import { formatDateTime, formatRelative } from '@/lib/format'

const MY_SESSIONS = ['me', 'sessions'] as const

export default function MySessionsPage() {
  const queryClient = useQueryClient()
  const { logout } = useAuth()
  const sessions = useQuery({
    queryKey: MY_SESSIONS,
    queryFn: () => unwrap(api.GET('/api/v1/admin/me/sessions')),
  })
  const signOut = useMutation({
    mutationFn: (sessionId: string) =>
      unwrap(
        api.DELETE('/api/v1/admin/me/sessions/{session_id}', {
          params: { path: { session_id: sessionId } },
        }),
      ),
  })

  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader
        title="Where you’re signed in"
        description="Every device signed in to your admin account. Sign out any you don’t recognise."
      />
      <QueryState
        query={sessions}
        isEmpty={(list) => list.length === 0}
        empty={<EmptyState icon={MonitorSmartphone} title="No sessions" />}
      >
        {(list) => (
          <ul className="space-y-2">
            {list.map((session) => (
              <li key={session.id}>
                <Card className="py-4">
                  <CardContent className="flex flex-wrap items-center justify-between gap-3">
                    <div className="min-w-0 space-y-0.5">
                      <p className="flex items-center gap-2 font-medium">
                        {session.device_name ?? 'Unknown device'}
                        {session.is_current ? (
                          <StatusBadge tone="success" label="This device" />
                        ) : null}
                      </p>
                      <p className="truncate text-sm text-muted-foreground">
                        {session.ip_address ?? 'IP unknown'} · signed in{' '}
                        {formatDateTime(session.created_at)} · last active{' '}
                        {formatRelative(session.last_seen_at)}
                      </p>
                    </div>
                    <ConfirmButton
                      variant="outline"
                      size="sm"
                      icon={LogOut}
                      label="Sign out"
                      title={
                        session.is_current ? 'Sign out of this device?' : 'Sign out that device?'
                      }
                      description={
                        session.is_current
                          ? 'You’ll go back to the sign-in page.'
                          : 'Whoever uses it will have to sign in again.'
                      }
                      confirmLabel="Sign out"
                      onConfirm={async () => {
                        try {
                          await signOut.mutateAsync(session.id)
                        } catch (error) {
                          toast.error(errorMessage(error))
                          return
                        }
                        if (session.is_current) {
                          await logout()
                          return
                        }
                        toast.success('That device is signed out.')
                        await queryClient.invalidateQueries({ queryKey: MY_SESSIONS })
                      }}
                    />
                  </CardContent>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </QueryState>
    </div>
  )
}
