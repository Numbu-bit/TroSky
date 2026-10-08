import { type ColumnDef } from '@tanstack/react-table'
import { Pencil, Play } from 'lucide-react'
import { useId, useState } from 'react'
import { toast } from 'sonner'

import { errorMessage, fieldErrors } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
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
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import { formatDateTime } from '@/lib/format'

import { useRules, useScan, useUpdateRule, type Severity } from './api'
import { SEVERITY, windowLabel } from './labels'

type Rule = Schemas['FraudRuleResponse']

function EditRule({ rule, onClose }: { rule: Rule; onClose: () => void }) {
  const update = useUpdateRule()
  const id = useId()
  const [enabled, setEnabled] = useState(rule.enabled)
  const [threshold, setThreshold] = useState(rule.threshold)
  const [windowMinutes, setWindowMinutes] = useState(String(rule.window_minutes))
  const [severity, setSeverity] = useState<Severity>(rule.severity)
  const [reason, setReason] = useState('')
  const [problem, setProblem] = useState<string | null>(null)

  async function save() {
    setProblem(null)
    if (!(Number(threshold) > 0)) return setProblem('The threshold must be a number above 0.')
    if (!Number.isInteger(Number(windowMinutes)) || Number(windowMinutes) < 1) {
      return setProblem('The window is whole minutes, at least 1.')
    }
    try {
      await update.mutateAsync({
        key: rule.key,
        enabled,
        threshold,
        window_minutes: Number(windowMinutes),
        severity,
        reason: reason.trim() || null,
      })
      toast.success(`“${rule.title}” saved.`)
      onClose()
    } catch (error) {
      const fields = fieldErrors(error)
      setProblem(Object.values(fields)[0] ?? errorMessage(error))
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && !update.isPending && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{rule.title}</DialogTitle>
          <DialogDescription>
            A flag is raised when a finding passes the threshold within the window.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="flex items-center gap-3">
            <Switch id={`${id}-on`} checked={enabled} onCheckedChange={setEnabled} />
            <Label htmlFor={`${id}-on`}>
              {enabled ? 'On: the checks use this rule' : 'Off: nothing is flagged by it'}
            </Label>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="grid gap-1.5">
              <Label htmlFor={`${id}-threshold`}>Threshold ({rule.threshold_means})</Label>
              <Input
                id={`${id}-threshold`}
                inputMode="decimal"
                value={threshold}
                onChange={(event) => setThreshold(event.target.value)}
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor={`${id}-window`}>Window, in minutes</Label>
              <Input
                id={`${id}-window`}
                inputMode="numeric"
                value={windowMinutes}
                onChange={(event) => setWindowMinutes(event.target.value)}
              />
            </div>
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor={`${id}-severity`}>Severity</Label>
            <Select value={severity} onValueChange={(value) => setSeverity(value as Severity)}>
              <SelectTrigger id={`${id}-severity`}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {(Object.keys(SEVERITY) as Severity[]).map((value) => (
                  <SelectItem key={value} value={value}>
                    {SEVERITY[value].label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
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
            Save rule
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

/** The fraud rules: on or off, thresholds, windows, severities; and a run now. */
export function RulesPanel() {
  const rules = useRules(true)
  const scan = useScan()
  const [editing, setEditing] = useState<Rule | null>(null)

  const columns: ColumnDef<Rule, unknown>[] = [
    {
      header: 'Rule',
      cell: ({ row }) => (
        <div className="min-w-56">
          <p className="font-medium">{row.original.title}</p>
          <p className="text-xs text-muted-foreground">{row.original.key}</p>
        </div>
      ),
    },
    {
      header: 'On',
      cell: ({ row }) => (
        <StatusBadge
          tone={row.original.enabled ? 'success' : 'neutral'}
          label={row.original.enabled ? 'On' : 'Off'}
        />
      ),
    },
    {
      header: 'Threshold',
      cell: ({ row }) => (
        <span>
          <span className="figure">{row.original.threshold}</span>{' '}
          <span className="text-xs text-muted-foreground">{row.original.threshold_means}</span>
        </span>
      ),
    },
    { header: 'Within', cell: ({ row }) => windowLabel(row.original.window_minutes) },
    {
      header: 'Severity',
      cell: ({ row }) => (
        <StatusBadge
          tone={SEVERITY[row.original.severity].tone}
          label={SEVERITY[row.original.severity].label}
        />
      ),
    },
    {
      header: 'Changed',
      cell: ({ row }) =>
        row.original.changed ? (
          <span className="text-xs">
            Yes{row.original.updated_at ? `, ${formatDateTime(row.original.updated_at)}` : ''}
          </span>
        ) : (
          <span className="text-xs text-muted-foreground">Default</span>
        ),
    },
    {
      id: 'actions',
      header: () => <span className="sr-only">Actions</span>,
      cell: ({ row }) => (
        <Button
          size="sm"
          variant="ghost"
          onClick={() => setEditing(row.original)}
          aria-label={`Edit ${row.original.title}`}
        >
          <Pencil aria-hidden /> Edit
        </Button>
      ),
    },
  ]

  return (
    <>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-muted-foreground">
          The checks run on their own; run them now after changing a rule.
        </p>
        <Button
          variant="outline"
          disabled={scan.isPending}
          onClick={async () => {
            try {
              const result = await scan.mutateAsync()
              toast.success(
                `Checks done: ${result.raised} new flag${result.raised === 1 ? '' : 's'}, ${result.updated} seen again.`,
              )
            } catch (error) {
              toast.error(errorMessage(error))
            }
          }}
        >
          <Play aria-hidden /> Run the checks now
        </Button>
      </div>
      <DataTable
        columns={columns}
        rows={rules.data}
        getRowId={(row) => row.key}
        caption="Fraud rules"
        isPending={rules.isPending}
        isError={rules.isError}
        error={rules.error}
        onRetry={() => void rules.refetch()}
        empty={<EmptyState title="No rules" />}
      />
      {editing ? (
        <EditRule key={editing.key} rule={editing} onClose={() => setEditing(null)} />
      ) : null}
    </>
  )
}
