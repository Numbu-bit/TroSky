import { type ColumnDef } from '@tanstack/react-table'
import { Download, MessageSquareWarning } from 'lucide-react'
import { useId, useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage } from '@/api/errors'
import { useSession } from '@/app/auth/auth-context'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { formatDateTime, formatRelative, maskPhone } from '@/lib/format'
import { isModuleEnabled } from '@/lib/modules'
import { usePage, useUrlState } from '@/lib/url-state'
import { useNow } from '@/lib/use-now'

import { useComplaints, type Complaint, type ComplaintCategory } from './api'
import { ComplaintStats } from './ComplaintStats'
import { CATEGORY, COMPLAINT_STATUS, NOT_CLOSED, PRIORITIES, PRIORITY } from './labels'
import { Due } from './Due'

const ANY = 'any'

const STATUS_FILTERS = [
  { value: NOT_CLOSED, label: 'Not closed' },
  { value: 'open', label: 'Open' },
  { value: 'in_review', label: 'In review' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'dismissed', label: 'Dismissed' },
  { value: ANY, label: 'Any status' },
]

const SORTS = [
  { value: '-created_at', label: 'Newest first' },
  { value: 'created_at', label: 'Oldest first' },
  { value: 'due_at', label: 'Due soonest' },
  { value: '-priority', label: 'Most urgent first' },
]

function FilterSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string
  value: string
  onChange: (value: string) => void
  options: { value: string; label: string }[]
}) {
  const id = useId()
  return (
    <div className="grid gap-1.5">
      <Label htmlFor={id}>{label}</Label>
      <Select value={value} onValueChange={onChange}>
        <SelectTrigger id={id}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {options.map((option) => (
            <SelectItem key={option.value} value={option.value}>
              {option.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  )
}

/** Complaints, newest first; with the insights module, triage and SLA figures. */
export function ComplaintsList() {
  const navigate = useNavigate()
  const { me } = useSession()
  const insights = isModuleEnabled('complaints-insights')
  const [filters, update] = useUrlState({
    status: NOT_CLOSED,
    priority: '',
    category: '',
    assigned: '',
    overdue: '',
    sort: '-created_at',
  })
  const { page, limit, setPage } = usePage()
  const query = { ...filters, status: filters.status === ANY ? '' : filters.status }
  const complaints = useComplaints(query, page, limit, me.id)
  const now = useNow(30_000)
  const [downloading, setDownloading] = useState(false)

  const columns: ColumnDef<Complaint, unknown>[] = [
    {
      header: 'Filed',
      cell: ({ row }) => (
        <div className="whitespace-nowrap">
          <p>{formatRelative(row.original.created_at, now)}</p>
          <p className="text-xs text-muted-foreground">{formatDateTime(row.original.created_at)}</p>
        </div>
      ),
    },
    {
      header: 'Complaint',
      cell: ({ row }) => (
        <div className="min-w-56">
          <Link
            to={`/complaints/${row.original.id}`}
            className="font-medium hover:underline"
            onClick={(event) => event.stopPropagation()}
          >
            {row.original.subject}
          </Link>
          <p className="text-xs text-muted-foreground">{CATEGORY[row.original.category]}</p>
        </div>
      ),
    },
    {
      header: 'From',
      cell: ({ row }) => (
        <div>
          <p>{row.original.filed_by_name ?? 'A passenger'}</p>
          <p className="figure text-xs text-muted-foreground">
            {maskPhone(row.original.filed_by_phone)}
          </p>
        </div>
      ),
    },
    {
      header: 'Priority',
      cell: ({ row }) => (
        <StatusBadge
          tone={PRIORITY[row.original.priority].tone}
          label={PRIORITY[row.original.priority].label}
        />
      ),
    },
    {
      header: 'Status',
      cell: ({ row }) => {
        const style = COMPLAINT_STATUS[row.original.status]
        return <StatusBadge tone={style.tone} label={style.label} icon={style.icon} />
      },
    },
    ...(insights
      ? ([
          {
            header: 'With',
            cell: ({ row }) =>
              row.original.assignee_name ?? (
                <span className="text-muted-foreground">Nobody yet</span>
              ),
          },
          {
            header: 'Due',
            cell: ({ row }) => <Due complaint={row.original} now={now} />,
          },
        ] satisfies ColumnDef<Complaint, unknown>[])
      : []),
  ]

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        '/api/v1/admin/complaints',
        {
          format: 'csv',
          complaint_status: query.status,
          priority: query.priority,
          category: query.category,
          assigned_to: query.assigned === 'me' ? me.id : undefined,
          unassigned: query.assigned === 'none' ? true : undefined,
          overdue: query.overdue === 'yes' ? true : undefined,
          sort: query.sort,
        },
        'complaints.csv',
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
        title="Complaints"
        description="From passengers. Resolve or dismiss each with a note."
        actions={
          <Button variant="outline" onClick={() => void download()} disabled={downloading}>
            <Download aria-hidden /> CSV
          </Button>
        }
      />
      {insights ? <ComplaintStats filter={filters} onFilter={(patch) => update(patch)} /> : null}
      <div
        className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-5"
        role="group"
        aria-label="Filters"
      >
        <FilterSelect
          label="Status"
          value={filters.status}
          onChange={(status) => update({ status })}
          options={STATUS_FILTERS}
        />
        {insights ? (
          <>
            <FilterSelect
              label="Priority"
              value={filters.priority || ANY}
              onChange={(priority) => update({ priority: priority === ANY ? null : priority })}
              options={[
                { value: ANY, label: 'Any priority' },
                ...PRIORITIES.map((value) => ({ value, label: PRIORITY[value].label })),
              ]}
            />
            <FilterSelect
              label="Category"
              value={filters.category || ANY}
              onChange={(category) => update({ category: category === ANY ? null : category })}
              options={[
                { value: ANY, label: 'Any category' },
                ...(Object.keys(CATEGORY) as ComplaintCategory[]).map((value) => ({
                  value,
                  label: CATEGORY[value],
                })),
              ]}
            />
            <FilterSelect
              label="With"
              value={filters.overdue ? 'overdue' : filters.assigned || ANY}
              onChange={(value) =>
                update({
                  assigned: value === 'me' || value === 'none' ? value : null,
                  overdue: value === 'overdue' ? 'yes' : null,
                })
              }
              options={[
                { value: ANY, label: 'Anyone' },
                { value: 'me', label: 'Me' },
                { value: 'none', label: 'Nobody yet' },
                { value: 'overdue', label: 'Overdue, anyone' },
              ]}
            />
            <FilterSelect
              label="Order"
              value={filters.sort}
              onChange={(sort) => update({ sort })}
              options={SORTS}
            />
          </>
        ) : null}
      </div>
      <DataTable
        columns={columns}
        rows={complaints.data?.items}
        total={complaints.data?.total}
        getRowId={(row) => row.id}
        caption="Complaints"
        isPending={complaints.isPending}
        isError={complaints.isError}
        error={complaints.error}
        onRetry={() => void complaints.refetch()}
        isFetching={complaints.isFetching && !complaints.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => navigate(`/complaints/${row.id}`)}
        empty={
          <EmptyState
            icon={MessageSquareWarning}
            title="No complaints match"
            description="Try another status or filter."
          />
        }
      />
    </>
  )
}
