import { type ColumnDef } from '@tanstack/react-table'
import { Download, Search, Users } from 'lucide-react'
import { useId, useState } from 'react'
import { useLocation, useNavigate } from 'react-router'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage } from '@/api/errors'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { formatDate, formatRelative, maskEmail, maskPhone } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'
import { useDebounced } from '@/lib/use-debounced'
import { useNow } from '@/lib/use-now'

import { useAccounts, type Account } from './api'
import { accountStatus, ROLE_NAMES } from './labels'

const ANY = 'any'

/**
 * Find an account by name, phone or email, or browse them all. The search
 * text is kept in the page, not the address: it is personal data.
 */
export function AccountsList() {
  const navigate = useNavigate()
  const location = useLocation()
  const [text, setText] = useState(
    () => (location.state as { search?: string } | null)?.search ?? '',
  )
  const search = useDebounced(text, 300)
  const [filters, update] = useUrlState({ role: '', status: '', sort: '-created_at' })
  const { page, limit, setPage } = usePage()
  const accounts = useAccounts(search, filters, page, limit)
  const now = useNow(60_000)
  const [downloading, setDownloading] = useState(false)
  const ids = { search: useId(), role: useId(), status: useId(), sort: useId() }

  const columns: ColumnDef<Account, unknown>[] = [
    {
      header: 'Name',
      cell: ({ row }) => (
        <div className="min-w-40">
          <p className="font-medium">{row.original.full_name ?? 'No name given'}</p>
          <p className="figure text-xs text-muted-foreground">
            {maskPhone(row.original.phone_number)}
          </p>
        </div>
      ),
    },
    {
      header: 'Email',
      cell: ({ row }) => (
        <span className="text-sm text-muted-foreground">{maskEmail(row.original.email)}</span>
      ),
    },
    {
      header: 'Roles',
      cell: ({ row }) => (
        <span className="text-sm">
          {row.original.roles.map((role) => ROLE_NAMES[role] ?? role).join(', ') || '—'}
        </span>
      ),
    },
    {
      header: 'Status',
      cell: ({ row }) => {
        const status = accountStatus(row.original)
        return <StatusBadge tone={status.tone} label={status.label} />
      },
    },
    {
      header: 'Joined',
      cell: ({ row }) => (
        <span className="whitespace-nowrap">{formatDate(row.original.created_at)}</span>
      ),
    },
    {
      header: 'Last signed in',
      cell: ({ row }) =>
        row.original.last_login_at ? formatRelative(row.original.last_login_at, now) : 'Never',
    },
  ]

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        '/api/v1/admin/users',
        {
          format: 'csv',
          search: search.trim() || undefined,
          role: filters.role,
          status: filters.status,
          sort: filters.sort,
        },
        'accounts.csv',
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <>
      <PageHeader
        title="Accounts"
        description="Passengers, drivers and fleet owners. Search by name, phone number or email."
        actions={
          <Button variant="outline" onClick={() => void download()} disabled={downloading}>
            <Download aria-hidden /> CSV
          </Button>
        }
      />
      <div
        className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4"
        role="group"
        aria-label="Filters"
      >
        <div className="grid gap-1.5 sm:col-span-2 lg:col-span-1">
          <Label htmlFor={ids.search}>Search</Label>
          <div className="relative">
            <Search
              className="pointer-events-none absolute top-2.5 left-2.5 size-4 text-muted-foreground"
              aria-hidden
            />
            <Input
              id={ids.search}
              type="search"
              className="pl-8"
              value={text}
              autoComplete="off"
              placeholder="Name, 024… or email"
              onChange={(event) => {
                setText(event.target.value)
                setPage(1)
              }}
            />
          </div>
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={ids.role}>Role</Label>
          <Select
            value={filters.role || ANY}
            onValueChange={(role) => update({ role: role === ANY ? null : role })}
          >
            <SelectTrigger id={ids.role}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ANY}>Any role</SelectItem>
              <SelectItem value="passenger">Passengers</SelectItem>
              <SelectItem value="driver">Drivers</SelectItem>
              <SelectItem value="fleet_owner">Fleet owners</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={ids.status}>Status</Label>
          <Select
            value={filters.status || ANY}
            onValueChange={(status) => update({ status: status === ANY ? null : status })}
          >
            <SelectTrigger id={ids.status}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ANY}>Any status</SelectItem>
              <SelectItem value="active">Active</SelectItem>
              <SelectItem value="suspended">Suspended</SelectItem>
              <SelectItem value="inactive">Closed</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={ids.sort}>Order</Label>
          <Select value={filters.sort} onValueChange={(sort) => update({ sort })}>
            <SelectTrigger id={ids.sort}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="-created_at">Newest first</SelectItem>
              <SelectItem value="created_at">Oldest first</SelectItem>
              <SelectItem value="-last_login_at">Signed in most recently</SelectItem>
              <SelectItem value="full_name">Name, A to Z</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>
      <DataTable
        columns={columns}
        rows={accounts.data?.items}
        total={accounts.data?.total}
        getRowId={(row) => row.id}
        caption="Accounts"
        isPending={accounts.isPending}
        isError={accounts.isError}
        error={accounts.error}
        onRetry={() => void accounts.refetch()}
        isFetching={accounts.isFetching && !accounts.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => navigate(`/accounts/${row.id}`)}
        empty={
          <EmptyState
            icon={Users}
            title={search.trim() ? 'Nobody matches' : 'No accounts'}
            description={
              search.trim()
                ? 'Check the number or email, or try part of the name.'
                : 'Try other filters.'
            }
          />
        }
      />
    </>
  )
}
