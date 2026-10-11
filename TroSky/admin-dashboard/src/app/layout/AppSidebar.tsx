import { NavLink, useLocation } from 'react-router'

import { useSession } from '@/app/auth/auth-context'
import { NAV_GROUPS, SCREENS, canOpen } from '@/app/screens'
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarRail,
} from '@/components/ui/sidebar'

function Logo() {
  return (
    <div className="flex items-center gap-2 px-1 py-1.5">
      <img src="/favicon.svg" alt="" className="size-8 shrink-0 rounded-md" />
      <div className="grid leading-tight group-data-[collapsible=icon]:hidden">
        <span className="text-base font-bold text-sidebar-foreground">TroSky</span>
        <span className="text-xs text-sidebar-foreground/70">Admin dashboard</span>
      </div>
    </div>
  )
}

export function AppSidebar() {
  const { permissions } = useSession()
  const { pathname } = useLocation()
  const visible = SCREENS.filter((screen) => screen.group && canOpen(screen, permissions))

  return (
    <Sidebar collapsible="icon" aria-label="Main navigation">
      <SidebarHeader>
        <Logo />
      </SidebarHeader>
      <SidebarContent>
        {NAV_GROUPS.map((group) => {
          const items = visible.filter((screen) => screen.group === group.key)
          if (items.length === 0) return null
          return (
            <SidebarGroup key={group.key}>
              <SidebarGroupLabel className="text-sidebar-foreground/60">
                {group.label}
              </SidebarGroupLabel>
              <SidebarGroupContent>
                <SidebarMenu>
                  {items.map((screen) => {
                    const href = `/${screen.path}`
                    const active = pathname === href || pathname.startsWith(`${href}/`)
                    return (
                      <SidebarMenuItem key={screen.key}>
                        <SidebarMenuButton
                          asChild
                          isActive={active}
                          tooltip={screen.label}
                          className="relative data-[active=true]:font-semibold data-[active=true]:before:absolute data-[active=true]:before:inset-y-1 data-[active=true]:before:left-0 data-[active=true]:before:w-1 data-[active=true]:before:rounded-full data-[active=true]:before:bg-gold"
                        >
                          <NavLink to={href}>
                            <screen.icon aria-hidden />
                            <span>{screen.label}</span>
                          </NavLink>
                        </SidebarMenuButton>
                      </SidebarMenuItem>
                    )
                  })}
                </SidebarMenu>
              </SidebarGroupContent>
            </SidebarGroup>
          )
        })}
      </SidebarContent>
      <SidebarFooter className="px-3 pb-3 text-xs text-sidebar-foreground/60 group-data-[collapsible=icon]:hidden">
        Times in Africa/Accra
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
