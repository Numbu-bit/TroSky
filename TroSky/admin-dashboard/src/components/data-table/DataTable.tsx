import {
  flexRender,
  getCoreRowModel,
  useReactTable,
  type Cell,
  type ColumnDef,
  type RowData,
} from '@tanstack/react-table'
import { ArrowDown, ArrowUp, ArrowUpDown, ChevronLeft, ChevronRight } from 'lucide-react'
import type { ReactNode } from 'react'

import { EmptyState, ErrorState, TableSkeleton } from '@/components/feedback/states'
import { Button } from '@/components/ui/button'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { formatNumber } from '@/lib/format'
import { cn } from '@/lib/utils'

declare module '@tanstack/react-table' {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  interface ColumnMeta<TData extends RowData, TValue> {
    /** The API's sort key for this column, when the API sorts by it. */
    sortKey?: string
    align?: 'right'
    className?: string
  }
}

export interface Sorting {
  /** e.g. "-created_at" (descending) or "due_at". */
  value: string
  onChange: (value: string) => void
}

interface DataTableProps<T> {
  columns: ColumnDef<T, unknown>[]
  rows: T[] | undefined
  total?: number
  getRowId: (row: T) => string
  caption: string
  isPending: boolean
  isError: boolean
  error?: unknown
  onRetry?: () => void
  /** Refetching: the current rows stay, dimmed. */
  isFetching?: boolean
  empty?: ReactNode
  page?: number
  pageSize?: number
  onPageChange?: (page: number) => void
  sorting?: Sorting
  onRowClick?: (row: T) => void
  selectedId?: string | null
  className?: string
}

/**
 * A cell's content. ``flexRender`` would mount each inline cell function as
 * a component, and a new function every render means a new component: the
 * cell (and any dialog open in it) would be thrown away on each re-render.
 * Calling it keeps the cell; cell functions never use hooks.
 */
function renderCell<T>(cell: Cell<T, unknown>): ReactNode {
  const content = cell.column.columnDef.cell
  return typeof content === 'function' ? content(cell.getContext()) : content
}

/** A server-side table: the API filters, sorts and pages; this shows it. */
export function DataTable<T>({
  columns,
  rows,
  total,
  getRowId,
  caption,
  isPending,
  isError,
  error,
  onRetry,
  isFetching,
  empty,
  page = 1,
  pageSize = 20,
  onPageChange,
  sorting,
  onRowClick,
  selectedId,
  className,
}: DataTableProps<T>) {
  // eslint-disable-next-line react-hooks/incompatible-library -- TanStack Table's API is not memoisable
  const table = useReactTable({
    data: rows ?? [],
    columns,
    getRowId,
    getCoreRowModel: getCoreRowModel(),
    manualPagination: true,
    manualSorting: true,
  })

  if (isPending) return <TableSkeleton columns={Math.min(columns.length, 6)} />
  if (isError) return <ErrorState error={error} onRetry={onRetry} />
  if (!rows || rows.length === 0) {
    return (
      <>
        {empty ?? <EmptyState title="Nothing here" description="No records match these filters." />}
      </>
    )
  }

  const pages = total !== undefined ? Math.max(1, Math.ceil(total / pageSize)) : 1

  return (
    <div className={cn('space-y-3', className)}>
      <div
        className={cn(
          'overflow-x-auto rounded-lg border bg-card transition-opacity',
          isFetching && 'opacity-60',
        )}
        aria-busy={isFetching || undefined}
      >
        <Table>
          <caption className="sr-only">{caption}</caption>
          <TableHeader>
            {table.getHeaderGroups().map((group) => (
              <TableRow key={group.id}>
                {group.headers.map((header) => {
                  const meta = header.column.columnDef.meta
                  const sortKey = meta?.sortKey
                  const active = sorting && sortKey && sorting.value.replace(/^-/, '') === sortKey
                  const descending = active && sorting.value.startsWith('-')
                  const label = header.isPlaceholder
                    ? null
                    : flexRender(header.column.columnDef.header, header.getContext())
                  return (
                    <TableHead
                      key={header.id}
                      className={cn(meta?.align === 'right' && 'text-right', meta?.className)}
                      aria-sort={active ? (descending ? 'descending' : 'ascending') : undefined}
                    >
                      {sorting && sortKey ? (
                        <Button
                          variant="ghost"
                          size="sm"
                          className="-ml-2 h-8 px-2"
                          onClick={() =>
                            sorting.onChange(active && !descending ? `-${sortKey}` : sortKey)
                          }
                        >
                          {label}
                          {active ? (
                            descending ? (
                              <ArrowDown aria-hidden />
                            ) : (
                              <ArrowUp aria-hidden />
                            )
                          ) : (
                            <ArrowUpDown className="opacity-50" aria-hidden />
                          )}
                        </Button>
                      ) : (
                        label
                      )}
                    </TableHead>
                  )
                })}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {table.getRowModel().rows.map((row) => (
              <TableRow
                key={row.id}
                data-state={row.id === selectedId ? 'selected' : undefined}
                className={cn(onRowClick && 'cursor-pointer')}
                onClick={onRowClick ? () => onRowClick(row.original) : undefined}
              >
                {row.getVisibleCells().map((cell) => (
                  <TableCell
                    key={cell.id}
                    className={cn(
                      cell.column.columnDef.meta?.align === 'right' && 'figure text-right',
                      cell.column.columnDef.meta?.className,
                    )}
                  >
                    {renderCell(cell)}
                  </TableCell>
                ))}
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
      {total !== undefined && onPageChange ? (
        <Pager page={page} pages={pages} total={total} onPageChange={onPageChange} />
      ) : null}
    </div>
  )
}

export function Pager({
  page,
  pages,
  total,
  onPageChange,
}: {
  page: number
  pages: number
  total: number
  onPageChange: (page: number) => void
}) {
  return (
    <nav className="flex items-center justify-between gap-2 text-sm" aria-label="Pages">
      <p className="text-muted-foreground">
        {formatNumber(total)} {total === 1 ? 'record' : 'records'}
      </p>
      <div className="flex items-center gap-2">
        <Button
          variant="outline"
          size="sm"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
          aria-label="Previous page"
        >
          <ChevronLeft aria-hidden />
        </Button>
        <span className="figure tabular-nums" aria-current="page">
          Page {page} of {pages}
        </span>
        <Button
          variant="outline"
          size="sm"
          disabled={page >= pages}
          onClick={() => onPageChange(page + 1)}
          aria-label="Next page"
        >
          <ChevronRight aria-hidden />
        </Button>
      </div>
    </nav>
  )
}
