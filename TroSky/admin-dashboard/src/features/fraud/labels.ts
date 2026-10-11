import { CircleAlert, CircleCheck, CircleSlash, Search, type LucideIcon } from 'lucide-react'

import type { Tone } from '@/components/status/StatusBadge'

import type { FlagStatus, FraudAction, Severity } from './api'

export const FLAG_STATUS: Record<FlagStatus, { tone: Tone; label: string; icon: LucideIcon }> = {
  open: { tone: 'warning', label: 'Open', icon: CircleAlert },
  investigating: { tone: 'info', label: 'Being looked into', icon: Search },
  confirmed: { tone: 'danger', label: 'Confirmed fraud', icon: CircleCheck },
  false_positive: { tone: 'neutral', label: 'False alarm', icon: CircleSlash },
}

export const SEVERITY: Record<Severity, { tone: Tone; label: string }> = {
  critical: { tone: 'danger', label: 'Critical' },
  high: { tone: 'danger', label: 'High' },
  medium: { tone: 'warning', label: 'Medium' },
  low: { tone: 'neutral', label: 'Low' },
}

export const ACTIONS: Record<FraudAction, { label: string; done: string; destructive: boolean }> = {
  suspend_account: {
    label: 'Suspend the account',
    done: 'Account suspended and signed out everywhere.',
    destructive: true,
  },
  freeze_wallet: {
    label: 'Freeze the wallet',
    done: 'Wallet frozen: no payments or payouts leave it.',
    destructive: true,
  },
  unfreeze_wallet: { label: 'Unfreeze the wallet', done: 'Wallet unfrozen.', destructive: false },
  block_device: {
    label: 'Block the device',
    done: 'Device blocked: it can’t sign in.',
    destructive: true,
  },
  unblock_device: { label: 'Unblock the device', done: 'Device unblocked.', destructive: false },
}

/** "Open, or being looked into" */
export const OPEN_FILTER = 'open,investigating'

/** Minutes as a short period: "1 h", "7 days". */
export function windowLabel(minutes: number): string {
  if (minutes % (24 * 60) === 0) {
    const days = minutes / (24 * 60)
    return `${days} day${days === 1 ? '' : 's'}`
  }
  if (minutes % 60 === 0) return `${minutes / 60} h`
  return `${minutes} min`
}
