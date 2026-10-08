import { Check, ChevronsUpDown } from 'lucide-react'
import { useState, type ReactNode } from 'react'

import { Button } from '@/components/ui/button'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { useDebounced } from '@/lib/use-debounced'
import { cn } from '@/lib/utils'

export interface PickerOption {
  value: string
  label: string
  hint?: string
}

/**
 * A searchable picker whose options come from the server: it asks for
 * what was typed (debounced 300 ms) instead of loading every record.
 */
export function SearchPicker({
  id,
  value,
  selectedLabel,
  onChange,
  useOptions,
  placeholder,
  searchPlaceholder = 'Search…',
  emptyText = 'Nothing found.',
  disabled,
  className,
  allowClear,
}: {
  id?: string
  value: string | null
  selectedLabel?: ReactNode
  onChange: (option: PickerOption | null) => void
  useOptions: (search: string, open: boolean) => { options: PickerOption[]; loading: boolean }
  placeholder: string
  searchPlaceholder?: string
  emptyText?: string
  disabled?: boolean
  className?: string
  allowClear?: boolean
}) {
  const [open, setOpen] = useState(false)
  const [search, setSearch] = useState('')
  const debounced = useDebounced(search, 300)
  const { options, loading } = useOptions(debounced, open)
  const current = options.find((option) => option.value === value)

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          id={id}
          variant="outline"
          role="combobox"
          aria-expanded={open}
          disabled={disabled}
          className={cn('w-full justify-between font-normal', className)}
        >
          <span className={cn('truncate', !value && 'text-muted-foreground')}>
            {value ? (selectedLabel ?? current?.label ?? placeholder) : placeholder}
          </span>
          <ChevronsUpDown className="opacity-50" aria-hidden />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-(--radix-popover-trigger-width) min-w-72 p-0" align="start">
        <Command shouldFilter={false}>
          <CommandInput placeholder={searchPlaceholder} value={search} onValueChange={setSearch} />
          <CommandList>
            <CommandEmpty>{loading ? 'Searching…' : emptyText}</CommandEmpty>
            <CommandGroup>
              {allowClear && value ? (
                <CommandItem
                  value="__clear__"
                  onSelect={() => {
                    onChange(null)
                    setOpen(false)
                  }}
                >
                  <span className="text-muted-foreground">Any</span>
                </CommandItem>
              ) : null}
              {options.map((option) => (
                <CommandItem
                  key={option.value}
                  value={option.value}
                  onSelect={() => {
                    onChange(option)
                    setOpen(false)
                  }}
                >
                  <Check
                    className={cn('size-4', option.value === value ? 'opacity-100' : 'opacity-0')}
                    aria-hidden
                  />
                  <span className="min-w-0">
                    <span className="block truncate">{option.label}</span>
                    {option.hint ? (
                      <span className="block truncate text-xs text-muted-foreground">
                        {option.hint}
                      </span>
                    ) : null}
                  </span>
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  )
}
