import { type ColumnDef } from '@tanstack/react-table'
import { Archive, MapPin, Pencil, Plus } from 'lucide-react'
import { useEffect, useId, useState } from 'react'
import { toast } from 'sonner'

import { ApiError, isApiError } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useStops } from '@/features/shared/reference'
import { usePage, useUrlState } from '@/lib/url-state'
import { useDebounced } from '@/lib/use-debounced'

import { useRetireStop } from './api'
import { StopDialog } from './StopDialog'

type Stop = Schemas['StopResponse']

/** What to say when a stop can't be retired: the routes that still use it. */
function retireFailure(error: unknown): Error {
  if (isApiError(error, 409) && error instanceof ApiError) {
    const routes = Array.isArray(error.details.routes) ? (error.details.routes as string[]) : []
    if (routes.length) {
      return new Error(
        `It is on ${routes.length === 1 ? 'an active route' : `${routes.length} active routes`}: ${routes.join(', ')}. Retire ${routes.length === 1 ? 'that route' : 'those routes'} first, or take the stop off them.`,
      )
    }
  }
  return error instanceof Error ? error : new Error('Could not retire the stop.')
}

/** Every active stop: search by name, add, edit (move) and retire. */
export function StopsPanel() {
  const [{ q }, update] = useUrlState({ q: '' })
  const [text, setText] = useState(q)
  const debounced = useDebounced(text, 300)
  const { page, limit, setPage } = usePage()
  const searching = q.trim().length >= 2
  const stops = useStops(q, { limit, page })
  const retire = useRetireStop()
  const [editing, setEditing] = useState<Stop | 'new' | null>(null)
  const searchId = useId()

  useEffect(() => {
    if (debounced !== q) update({ q: debounced })
    // Only the debounced text drives the URL.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debounced])

  const columns: ColumnDef<Stop, unknown>[] = [
    {
      header: 'Stop',
      cell: ({ row }) => (
        <div className="min-w-40">
          <p className="font-medium">{row.original.name}</p>
          {row.original.address ? (
            <p className="line-clamp-1 text-xs text-muted-foreground">{row.original.address}</p>
          ) : null}
        </div>
      ),
    },
    { header: 'Code', cell: ({ row }) => row.original.code ?? '—' },
    {
      header: 'Area',
      cell: ({ row }) => [row.original.city, row.original.region].filter(Boolean).join(', ') || '—',
    },
    {
      header: 'Where',
      cell: ({ row }) => (
        <a
          className="figure link-inline inline-flex items-center gap-1 text-sm"
          href={`https://www.openstreetmap.org/?mlat=${row.original.latitude}&mlon=${row.original.longitude}#map=17/${row.original.latitude}/${row.original.longitude}`}
          target="_blank"
          rel="noreferrer"
        >
          <MapPin className="size-3.5" aria-hidden />
          {row.original.latitude.toFixed(5)}, {row.original.longitude.toFixed(5)}
          <span className="sr-only">(opens OpenStreetMap)</span>
        </a>
      ),
    },
    {
      id: 'actions',
      header: () => <span className="sr-only">Actions</span>,
      cell: ({ row }) => (
        <div className="flex justify-end gap-1">
          <Button
            size="sm"
            variant="ghost"
            onClick={() => setEditing(row.original)}
            aria-label={`Edit ${row.original.name}`}
          >
            <Pencil aria-hidden /> Edit
          </Button>
          <ConfirmButton
            size="sm"
            variant="ghost"
            icon={Archive}
            label="Retire"
            title={`Retire ${row.original.name}?`}
            description="It disappears from search and new bookings. Past bookings keep it. Refused while an active route uses it."
            confirmLabel="Retire stop"
            destructive
            onConfirm={async () => {
              try {
                await retire.mutateAsync(row.original.id)
              } catch (error) {
                throw retireFailure(error)
              }
              toast.success(`${row.original.name} retired.`)
            }}
          />
        </div>
      ),
    },
  ]

  return (
    <>
      <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
        <div className="grid w-full max-w-sm gap-1.5">
          <Label htmlFor={searchId}>Search by name</Label>
          <Input
            id={searchId}
            type="search"
            value={text}
            placeholder="2 letters or more"
            onChange={(event) => setText(event.target.value)}
          />
        </div>
        <Button onClick={() => setEditing('new')}>
          <Plus aria-hidden /> New stop
        </Button>
      </div>
      <DataTable
        columns={columns}
        rows={stops.data?.items}
        total={searching ? undefined : stops.data?.total}
        getRowId={(row) => row.id}
        caption="Stops"
        isPending={stops.isPending}
        isError={stops.isError}
        error={stops.error}
        onRetry={() => void stops.refetch()}
        isFetching={stops.isFetching && !stops.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        empty={
          <EmptyState
            icon={MapPin}
            title={searching ? 'No stop has that name' : 'No stops yet'}
            description={searching ? 'Try part of the name.' : 'Add the first stop.'}
          />
        }
      />
      {searching && stops.data && stops.data.items.length >= limit ? (
        <p className="mt-2 text-xs text-muted-foreground">
          Showing the first {limit} matches. Type more of the name to narrow it.
        </p>
      ) : null}
      <StopDialog
        open={editing !== null}
        stop={editing === 'new' ? null : editing}
        onOpenChange={(open) => !open && setEditing(null)}
      />
    </>
  )
}
