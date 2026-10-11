import { useQueryClient } from '@tanstack/react-query'
import {
  Bus,
  ChevronDown,
  FlaskConical,
  MessageSquareWarning,
  RotateCcw,
  Siren,
  UserPlus,
} from 'lucide-react'
import { useState } from 'react'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

import { demoConfig, setFailRequests } from './config'
import { getDb } from './db'
import {
  addDemoComplaint,
  addDemoDriverApplication,
  addDemoVehicleApplication,
  raiseDemoSos,
} from './triggers'

/**
 * The DEMO DATA badge, which opens the demo controls: make something
 * happen (an SOS, an application) or make every request fail. Only in
 * demo builds.
 */
export default function DemoMenu() {
  const queryClient = useQueryClient()
  const [failing, setFailing] = useState(demoConfig.failRequests)
  const refresh = () => void queryClient.invalidateQueries()

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          size="sm"
          className="h-7 gap-1 bg-gold px-2 text-xs font-bold tracking-wide text-gold-foreground hover:bg-gold/90"
          title="Everything on screen is realistic fake data; nothing reaches the real platform."
        >
          <FlaskConical aria-hidden />
          DEMO DATA
          <ChevronDown className="opacity-70" aria-hidden />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-64">
        <DropdownMenuLabel className="text-xs font-normal text-muted-foreground">
          Fake data in this browser tab only. Make something happen:
        </DropdownMenuLabel>
        <DropdownMenuItem
          onSelect={() => {
            raiseDemoSos()
            refresh()
          }}
        >
          <Siren aria-hidden /> A passenger raises an SOS
        </DropdownMenuItem>
        <DropdownMenuItem
          onSelect={() => {
            const complaint = addDemoComplaint()
            toast.info(`New complaint: ${complaint.subject}`)
            refresh()
          }}
        >
          <MessageSquareWarning aria-hidden /> A passenger complains
        </DropdownMenuItem>
        <DropdownMenuItem
          onSelect={() => {
            const driver = addDemoDriverApplication()
            const name = getDb().users.find((user) => user.id === driver.user_id)?.full_name
            toast.info(`${name ?? 'A driver'} applied to drive.`)
            refresh()
          }}
        >
          <UserPlus aria-hidden /> A driver applies
        </DropdownMenuItem>
        <DropdownMenuItem
          onSelect={() => {
            const vehicle = addDemoVehicleApplication()
            toast.info(`${vehicle.registration_number} was added for approval.`)
            refresh()
          }}
        >
          <Bus aria-hidden /> A fleet owner adds a vehicle
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuCheckboxItem
          checked={failing}
          onCheckedChange={(checked) => {
            setFailRequests(checked)
            setFailing(checked)
            refresh()
          }}
        >
          Make every request fail
        </DropdownMenuCheckboxItem>
        <DropdownMenuItem onSelect={() => window.location.reload()}>
          <RotateCcw aria-hidden /> Start the demo again
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
