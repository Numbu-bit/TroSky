import { LogOut, MonitorSmartphone } from 'lucide-react'
import { Link } from 'react-router'

import { useAuth, useSession } from '@/app/auth/auth-context'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { ROLE_LABELS } from '@/lib/permissions'

function initials(name: string | null | undefined): string {
  if (!name) return 'A'
  const parts = name.trim().split(/\s+/)
  return ((parts[0]?.[0] ?? '') + (parts.length > 1 ? (parts.at(-1)?.[0] ?? '') : '')).toUpperCase()
}

export function ProfileMenu() {
  const { me, role } = useSession()
  const { logout } = useAuth()
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" className="h-9 gap-2 px-1.5" aria-label="Your account">
          <Avatar className="size-7">
            <AvatarFallback className="bg-navy text-xs font-semibold text-white">
              {initials(me.full_name)}
            </AvatarFallback>
          </Avatar>
          <span className="hidden max-w-36 truncate text-sm font-medium md:inline">
            {me.full_name ?? 'Admin'}
          </span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-60">
        <DropdownMenuLabel className="grid gap-0.5">
          <span className="truncate">{me.full_name ?? 'Admin'}</span>
          <span className="text-xs font-normal text-muted-foreground">{ROLE_LABELS[role]}</span>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuItem asChild>
          <Link to="/me/sessions">
            <MonitorSmartphone aria-hidden /> Where I’m signed in
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem onSelect={() => void logout()}>
          <LogOut aria-hidden /> Sign out
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
