import { Download, Table2, ChartSpline } from 'lucide-react'
import { useState, type ReactNode } from 'react'

import { Button } from '@/components/ui/button'
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { downloadCsv, type TableColumn } from '@/lib/csv'
import { cn } from '@/lib/utils'

/**
 * Every chart has a table view and a CSV download, and keeps its previous
 * render (dimmed) while it refetches.
 */
export function ChartCard<T>({
  title,
  description,
  rows,
  columns,
  csvName,
  isFetching,
  children,
  className,
}: {
  title: string
  description?: ReactNode
  rows: T[]
  columns: TableColumn<T>[]
  csvName: string
  isFetching?: boolean
  children: ReactNode
  className?: string
}) {
  const [asTable, setAsTable] = useState(false)
  return (
    <Card className={cn('gap-4', className)}>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        {description ? <CardDescription>{description}</CardDescription> : null}
        <CardAction className="flex gap-1">
          <Button
            variant="ghost"
            size="icon"
            aria-label={asTable ? 'Show as a chart' : 'Show as a table'}
            aria-pressed={asTable}
            onClick={() => setAsTable((current) => !current)}
          >
            {asTable ? <ChartSpline aria-hidden /> : <Table2 aria-hidden />}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            aria-label={`Download ${title} as CSV`}
            onClick={() => downloadCsv(rows, columns, csvName)}
          >
            <Download aria-hidden />
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent
        className={cn('transition-opacity', isFetching && 'opacity-60')}
        aria-busy={isFetching || undefined}
      >
        {asTable ? (
          <div className="max-h-80 overflow-auto rounded-md border">
            <table className="w-full text-sm">
              <caption className="sr-only">{title}</caption>
              <thead className="sticky top-0 bg-muted">
                <tr>
                  {columns.map((column) => (
                    <th
                      key={column.key}
                      scope="col"
                      className={cn(
                        'px-3 py-2 text-left font-medium',
                        column.align === 'right' && 'text-right',
                      )}
                    >
                      {column.label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((row, index) => (
                  <tr key={index} className="border-t">
                    {columns.map((column) => (
                      <td
                        key={column.key}
                        className={cn(
                          'px-3 py-1.5',
                          column.align === 'right' && 'figure text-right',
                        )}
                      >
                        {column.value(row)}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          children
        )}
      </CardContent>
    </Card>
  )
}
