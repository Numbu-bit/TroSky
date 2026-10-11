import type { LucideIcon } from 'lucide-react'
import { useState, type ComponentProps } from 'react'

import { Button } from '@/components/ui/button'

import { ConfirmDialog, type ConfirmDialogProps } from './ConfirmDialog'

type ButtonProps = Pick<
  ComponentProps<typeof Button>,
  'variant' | 'size' | 'className' | 'disabled'
>

/** A button that asks before it acts. */
export function ConfirmButton({
  label,
  icon: Icon,
  variant,
  size,
  className,
  disabled,
  ...dialog
}: ButtonProps &
  Omit<ConfirmDialogProps, 'open' | 'onOpenChange'> & { label: string; icon?: LucideIcon }) {
  const [open, setOpen] = useState(false)
  return (
    <>
      <Button
        variant={variant}
        size={size}
        className={className}
        disabled={disabled}
        onClick={() => setOpen(true)}
      >
        {Icon ? <Icon aria-hidden /> : null}
        {label}
      </Button>
      <ConfirmDialog open={open} onOpenChange={setOpen} {...dialog} />
    </>
  )
}
