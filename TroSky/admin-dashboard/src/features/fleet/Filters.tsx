import { Download, Search } from 'lucide-react'
import { useEffect, useId, useState, type ReactNode } from 'react'

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
import { useDebounced } from '@/lib/use-debounced'

import { ANY } from './labels'

/** A labelled select whose "any" choice clears the filter. */
export function FilterSelect({
  label,
  value,
  onChange,
  options,
  any,
}: {
  label: string
  value: string
  onChange: (value: string | null) => void
  options: { value: string; label: string }[]
  /** The label for no filter; leave out when there must be a value. */
  any?: string
}) {
  const id = useId()
  return (
    <div className="grid gap-1.5">
      <Label htmlFor={id}>{label}</Label>
      <Select value={value || ANY} onValueChange={(next) => onChange(next === ANY ? null : next)}>
        <SelectTrigger id={id}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {any ? <SelectItem value={ANY}>{any}</SelectItem> : null}
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

/** A search box that updates its filter 300 ms after typing stops. */
export function SearchFilter({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string
  value: string
  onChange: (value: string | null) => void
  placeholder: string
}) {
  const id = useId()
  const [text, setText] = useState(value)
  const debounced = useDebounced(text, 300)
  useEffect(() => {
    if (debounced !== value) onChange(debounced || null)
    // Only the debounced text drives the filter.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debounced])
  return (
    <div className="grid gap-1.5">
      <Label htmlFor={id}>{label}</Label>
      <div className="relative">
        <Search
          className="pointer-events-none absolute top-2.5 left-2.5 size-4 text-muted-foreground"
          aria-hidden
        />
        <Input
          id={id}
          type="search"
          className="pl-8"
          value={text}
          placeholder={placeholder}
          onChange={(event) => setText(event.target.value)}
        />
      </div>
    </div>
  )
}

export function CsvButton({ onClick, busy }: { onClick: () => void; busy: boolean }) {
  return (
    <Button variant="outline" onClick={onClick} disabled={busy}>
      <Download aria-hidden /> CSV
    </Button>
  )
}

export function FilterRow({ children }: { children: ReactNode }) {
  return (
    <div
      className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-[repeat(auto-fit,minmax(10rem,1fr))] lg:items-end"
      role="group"
      aria-label="Filters"
    >
      {children}
    </div>
  )
}
