import { FlaskConical } from 'lucide-react'

import { ROLE_LABELS } from '@/lib/permissions'

import { DEMO_ACCOUNTS, DEMO_PASSWORD } from './accounts'

/** Demo mode only: one click fills the sign-in form with a demo account. */
export default function DemoAccounts({
  onPick,
}: {
  onPick: (identifier: string, password: string) => void
}) {
  return (
    <div className="space-y-2 rounded-md border border-dashed border-gold/60 bg-warning-soft/50 p-3">
      <p className="flex items-center gap-1.5 text-xs font-semibold text-warning-text">
        <FlaskConical className="size-3.5" aria-hidden /> Demo accounts (password {DEMO_PASSWORD})
      </p>
      <ul className="space-y-1">
        {DEMO_ACCOUNTS.map((account) => (
          <li key={account.id}>
            <button
              type="button"
              className="w-full rounded-md px-2 py-1.5 text-left text-sm hover:bg-card focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none"
              onClick={() => onPick(account.email, DEMO_PASSWORD)}
            >
              <span className="font-medium">{account.full_name}</span>
              <span className="text-muted-foreground"> · {ROLE_LABELS[account.role]}</span>
              <span className="block text-xs text-muted-foreground">{account.summary}</span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  )
}
