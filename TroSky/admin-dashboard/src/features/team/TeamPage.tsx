import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { type ColumnDef } from '@tanstack/react-table'
import { Pencil, UserMinus, UserPlus, Users } from 'lucide-react'
import { useId, useState } from 'react'
import { Link } from 'react-router'
import { toast } from 'sonner'

import { api, unwrap } from '@/api/client'
import { errorMessage, fieldErrors } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { formatRelative, maskEmail, maskPhone } from '@/lib/format'
import { PERMISSION_GROUPS, ROLE_LABELS, type AdminRole, type Permission } from '@/lib/permissions'
import { useNow } from '@/lib/use-now'

type Member = Schemas['TeamMemberResponse']
const RANK: Record<AdminRole, number> = { staff: 1, admin: 2, super_admin: 3 }

function useTeam() {
  return useQuery({ queryKey: ['team'], queryFn: () => unwrap(api.GET('/api/v1/admin/admins')) })
}

function useTeamMutation<V, R>(run: (variables: V) => Promise<R>) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['team'] })
      void queryClient.invalidateQueries({ queryKey: ['complaints', 'team'] })
      void queryClient.invalidateQueries({ queryKey: ['fraud', 'team'] })
    },
  })
}

/** Checkboxes for a staff member's permissions; only those you hold yourself (unless super admin). */
function PermissionPicker({
  value,
  onChange,
}: {
  value: Permission[]
  onChange: (value: Permission[]) => void
}) {
  const { role, permissions } = useSession()
  const id = useId()
  return (
    <fieldset className="space-y-3">
      <legend className="text-sm font-medium">What they may do</legend>
      {PERMISSION_GROUPS.map((group) => (
        <div key={group.title} className="space-y-1.5">
          <p className="text-xs font-semibold text-muted-foreground uppercase">{group.title}</p>
          <div className="grid gap-1.5 sm:grid-cols-2">
            {group.permissions.map((permission) => {
              const grantable = role === 'super_admin' || permissions.has(permission.code)
              return (
                <div key={permission.code} className="flex items-start gap-2">
                  <Checkbox
                    id={`${id}-${permission.code}`}
                    checked={value.includes(permission.code)}
                    disabled={!grantable}
                    onCheckedChange={(checked) =>
                      onChange(
                        checked === true
                          ? [...value, permission.code]
                          : value.filter((code) => code !== permission.code),
                      )
                    }
                  />
                  <Label
                    htmlFor={`${id}-${permission.code}`}
                    className="grid gap-0 text-sm leading-snug font-normal"
                  >
                    <span>{permission.label}</span>
                    <span className="figure text-xs text-muted-foreground">{permission.code}</span>
                  </Label>
                </div>
              )
            })}
          </div>
        </div>
      ))}
    </fieldset>
  )
}

function RoleSelect({
  id,
  value,
  onChange,
}: {
  id: string
  value: AdminRole
  onChange: (role: AdminRole) => void
}) {
  const { role } = useSession()
  return (
    <Select value={value} onValueChange={(next) => onChange(next as AdminRole)}>
      <SelectTrigger id={id}>
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {(['staff', 'admin', 'super_admin'] as AdminRole[])
          .filter((option) => RANK[option] <= RANK[role])
          .map((option) => (
            <SelectItem key={option} value={option}>
              {ROLE_LABELS[option]}
              {option === 'staff'
                ? ': only what is ticked'
                : option === 'admin'
                  ? ': everything but managing super admins'
                  : ': everything'}
            </SelectItem>
          ))}
      </SelectContent>
    </Select>
  )
}

function Invite({ onClose }: { onClose: () => void }) {
  const id = useId()
  const [name, setName] = useState('')
  const [phone, setPhone] = useState('')
  const [email, setEmail] = useState('')
  const [role, setRole] = useState<AdminRole>('staff')
  const [granted, setGranted] = useState<Permission[]>([])
  const [reason, setReason] = useState('')
  const [problem, setProblem] = useState<string | null>(null)
  const invite = useTeamMutation((body: Schemas['TeamInviteRequest']) =>
    unwrap(api.POST('/api/v1/admin/admins', { body })),
  )

  async function send() {
    if (name.trim().length < 2) return setProblem('Enter their full name.')
    if (!/^(\+233|0)\d{9}$/.test(phone.replace(/[\s-]/g, '')))
      return setProblem('Enter a Ghana phone number, like 024 123 4567.')
    if (role === 'staff' && !granted.length)
      return setProblem('Tick at least one thing a staff member may do.')
    setProblem(null)
    try {
      const result = await invite.mutateAsync({
        full_name: name.trim(),
        phone_number: phone.replace(/[\s-]/g, ''),
        email: email.trim() || null,
        role: role as 'admin' | 'staff',
        permissions: role === 'staff' ? granted : [],
        reason: reason.trim() || null,
      })
      toast.success(
        result.new_account
          ? `${result.member.full_name ?? 'They'} joined the team. A code to set a password was sent.`
          : `${result.member.full_name ?? 'They'} joined the team with their existing account.`,
      )
      onClose()
    } catch (error) {
      const fields = fieldErrors(error)
      setProblem(Object.values(fields)[0] ?? errorMessage(error))
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && !invite.isPending && onClose()}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>Add someone to the team</DialogTitle>
          <DialogDescription>
            An existing account joins as it is; someone new gets a code to set their password.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-3">
            <div className="grid gap-1.5">
              <Label htmlFor={`${id}-name`}>Full name</Label>
              <Input
                id={`${id}-name`}
                value={name}
                onChange={(event) => setName(event.target.value)}
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor={`${id}-phone`}>Phone</Label>
              <Input
                id={`${id}-phone`}
                inputMode="tel"
                value={phone}
                placeholder="024 123 4567"
                onChange={(event) => setPhone(event.target.value)}
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor={`${id}-email`}>Email (optional)</Label>
              <Input
                id={`${id}-email`}
                type="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
              />
            </div>
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor={`${id}-role`}>Role</Label>
            <RoleSelect
              id={`${id}-role`}
              value={role}
              onChange={(next) => setRole(next === 'super_admin' ? 'admin' : next)}
            />
          </div>
          {role === 'staff' ? <PermissionPicker value={granted} onChange={setGranted} /> : null}
          <div className="grid gap-1.5">
            <Label htmlFor={`${id}-reason`}>Why (for the audit log)</Label>
            <Textarea
              id={`${id}-reason`}
              value={reason}
              maxLength={1000}
              onChange={(event) => setReason(event.target.value)}
            />
          </div>
          {problem ? (
            <p role="alert" className="rounded-md bg-danger-soft p-2 text-sm text-danger-text">
              {problem}
            </p>
          ) : null}
        </div>
        <DialogFooter>
          <Button onClick={() => void send()} disabled={invite.isPending}>
            <UserPlus aria-hidden /> Add to the team
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function Edit({ member, onClose }: { member: Member; onClose: () => void }) {
  const id = useId()
  const [role, setRole] = useState<AdminRole>(member.role)
  const [granted, setGranted] = useState<Permission[]>(member.granted_permissions as Permission[])
  const [reason, setReason] = useState('')
  const [problem, setProblem] = useState<string | null>(null)
  const update = useTeamMutation((body: Schemas['TeamUpdateRequest']) =>
    unwrap(
      api.PATCH('/api/v1/admin/admins/{admin_id}', {
        params: { path: { admin_id: member.id } },
        body,
      }),
    ),
  )
  const name = member.full_name ?? maskPhone(member.phone_number)

  async function save() {
    if (role === 'staff' && !granted.length)
      return setProblem('Tick at least one thing a staff member may do.')
    setProblem(null)
    try {
      await update.mutateAsync({
        role,
        permissions: role === 'staff' ? granted : null,
        reason: reason.trim() || null,
      })
      toast.success(`${name}’s access changed.`)
      onClose()
    } catch (error) {
      const fields = fieldErrors(error)
      setProblem(Object.values(fields)[0] ?? errorMessage(error))
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && !update.isPending && onClose()}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>Change {name}’s access</DialogTitle>
          <DialogDescription>It applies the next time they load a page.</DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="grid gap-1.5">
            <Label htmlFor={`${id}-role`}>Role</Label>
            <RoleSelect id={`${id}-role`} value={role} onChange={setRole} />
          </div>
          {role === 'staff' ? <PermissionPicker value={granted} onChange={setGranted} /> : null}
          <div className="grid gap-1.5">
            <Label htmlFor={`${id}-reason`}>Why (for the audit log)</Label>
            <Textarea
              id={`${id}-reason`}
              value={reason}
              maxLength={1000}
              onChange={(event) => setReason(event.target.value)}
            />
          </div>
          {problem ? (
            <p role="alert" className="rounded-md bg-danger-soft p-2 text-sm text-danger-text">
              {problem}
            </p>
          ) : null}
        </div>
        <DialogFooter>
          <Button onClick={() => void save()} disabled={update.isPending}>
            Save access
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

/** The admin team: who has which role and permissions; add, change or remove. */
export default function TeamPage() {
  const { me, role: myRole } = useSession()
  const team = useTeam()
  const now = useNow(60_000)
  const [inviting, setInviting] = useState(false)
  const [editing, setEditing] = useState<Member | null>(null)
  const remove = useTeamMutation(({ id, reason }: { id: string; reason: string }) =>
    unwrap(
      api.PATCH('/api/v1/admin/admins/{admin_id}', {
        params: { path: { admin_id: id } },
        body: { active: false, reason },
      }),
    ),
  )

  const columns: ColumnDef<Member, unknown>[] = [
    {
      header: 'Member',
      cell: ({ row }) => (
        <div className="min-w-40">
          <p className="font-medium">
            {row.original.full_name ?? 'No name given'}
            {row.original.id === me.id ? (
              <span className="text-muted-foreground"> (you)</span>
            ) : null}
          </p>
          <p className="figure text-xs text-muted-foreground">
            {maskPhone(row.original.phone_number)} · {maskEmail(row.original.email)}
          </p>
        </div>
      ),
    },
    {
      header: 'Role',
      cell: ({ row }) => (
        <StatusBadge
          tone={row.original.role === 'staff' ? 'neutral' : 'info'}
          label={ROLE_LABELS[row.original.role]}
        />
      ),
    },
    {
      header: 'May do',
      cell: ({ row }) =>
        row.original.role === 'staff' ? (
          <ul className="max-w-80 text-xs">
            {row.original.granted_permissions.map((code) => (
              <li key={code}>
                {PERMISSION_GROUPS.flatMap((group) => group.permissions).find(
                  (permission) => permission.code === code,
                )?.label ?? code}
              </li>
            ))}
          </ul>
        ) : (
          <span className="text-sm text-muted-foreground">
            {row.original.role === 'super_admin'
              ? 'Everything'
              : 'Everything but managing super admins'}
          </span>
        ),
    },
    {
      header: 'Status',
      cell: ({ row }) =>
        row.original.is_suspended ? (
          <StatusBadge tone="danger" label="Suspended" />
        ) : row.original.is_active ? (
          <StatusBadge tone="success" label="Active" />
        ) : (
          <StatusBadge tone="neutral" label="Closed" />
        ),
    },
    {
      header: 'Last signed in',
      cell: ({ row }) =>
        row.original.last_login_at ? formatRelative(row.original.last_login_at, now) : 'Not yet',
    },
    {
      id: 'actions',
      header: () => <span className="sr-only">Actions</span>,
      cell: ({ row }) =>
        row.original.id !== me.id && RANK[row.original.role] <= RANK[myRole] ? (
          <div className="flex justify-end gap-1">
            <Button
              size="sm"
              variant="ghost"
              onClick={() => setEditing(row.original)}
              aria-label={`Change ${row.original.full_name ?? 'their'} access`}
            >
              <Pencil aria-hidden /> Access
            </Button>
            <ConfirmButton
              size="sm"
              variant="ghost"
              icon={UserMinus}
              label="Remove"
              title={`Take ${row.original.full_name ?? 'them'} off the team?`}
              description="Their admin role and permissions go, and they are signed out everywhere. Their account stays."
              confirmLabel="Remove from the team"
              destructive
              reason={{
                label: 'Why (for the audit log)',
                required: true,
                minLength: 5,
                maxLength: 1000,
              }}
              onConfirm={async (reason) => {
                await remove.mutateAsync({ id: row.original.id, reason })
                toast.success(`${row.original.full_name ?? 'They'} left the team.`)
              }}
            />
          </div>
        ) : null,
    },
  ]

  return (
    <>
      <PageHeader
        title="Admin team"
        description={
          <>
            Who can use this dashboard and what each may do. Your own devices are in{' '}
            <Link to="/me/sessions" className="link-inline">
              My sessions
            </Link>
            .
          </>
        }
        actions={
          <Button onClick={() => setInviting(true)}>
            <UserPlus aria-hidden /> Add someone
          </Button>
        }
      />
      <DataTable
        columns={columns}
        rows={team.data}
        getRowId={(row) => row.id}
        caption="Admin team"
        isPending={team.isPending}
        isError={team.isError}
        error={team.error}
        onRetry={() => void team.refetch()}
        empty={<EmptyState icon={Users} title="Nobody on the team" />}
      />
      {inviting ? <Invite onClose={() => setInviting(false)} /> : null}
      {editing ? <Edit key={editing.id} member={editing} onClose={() => setEditing(null)} /> : null}
    </>
  )
}
