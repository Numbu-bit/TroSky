import type { ReactNode } from 'react'

// ── Status bar ───────────────────────────────────────────────────────────

export function StatusBar({ light = false }: { light?: boolean }) {
  const c = light ? 'white' : '#1D2027'
  return (
    <div className="flex items-center justify-between px-6 pt-3" style={{ height: 48 }}>
      <span style={{ fontSize: 14, fontWeight: 600, color: c, fontFamily: 'var(--heading)', letterSpacing: '-0.2px' }}>9:41</span>
      <div className="flex items-center gap-1.5">
        {/* Signal */}
        <svg width="17" height="12" viewBox="0 0 17 12" fill="none">
          <rect x="0" y="7" width="3" height="5" rx="1" fill={c} />
          <rect x="4.5" y="5" width="3" height="7" rx="1" fill={c} />
          <rect x="9" y="2" width="3" height="10" rx="1" fill={c} />
          <rect x="13.5" y="0" width="3" height="12" rx="1" fill={c} opacity="0.3" />
        </svg>
        {/* WiFi */}
        <svg width="16" height="12" viewBox="0 0 16 12" fill="none">
          <path d="M8 10.5a1 1 0 100-2 1 1 0 000 2z" fill={c} />
          <path d="M4.5 7.5C5.5 6.5 6.7 6 8 6s2.5.5 3.5 1.5" stroke={c} strokeWidth="1.5" strokeLinecap="round" />
          <path d="M1.5 5C3.2 3.2 5.5 2 8 2s4.8 1.2 6.5 3" stroke={c} strokeWidth="1.5" strokeLinecap="round" opacity="0.4" />
        </svg>
        {/* Battery */}
        <svg width="25" height="12" viewBox="0 0 25 12" fill="none">
          <rect x="0.5" y="0.5" width="21" height="11" rx="3.5" stroke={c} strokeOpacity="0.35" />
          <rect x="22" y="3.5" width="2.5" height="5" rx="1.5" fill={c} fillOpacity="0.4" />
          <rect x="2" y="2" width="17" height="8" rx="2" fill={c} />
        </svg>
      </div>
    </div>
  )
}

// ── Home indicator ───────────────────────────────────────────────────────

export function HomeBar({ light = false }: { light?: boolean }) {
  return (
    <div className="absolute bottom-2 left-1/2 -translate-x-1/2" style={{ width: 120, height: 5, background: light ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.18)', borderRadius: 3 }} />
  )
}

// ── Phone frame ──────────────────────────────────────────────────────────

export function PhoneFrame({ children, label }: { children: ReactNode; label?: string }) {
  return (
    <div className="flex flex-col items-center gap-4 shrink-0">
      <div
        className="relative"
        style={{
          width: 320,
          height: 694,
          borderRadius: 52,
          background: '#1A1A1A',
          boxShadow: '0 60px 120px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.06), inset 0 0 0 1px rgba(255,255,255,0.04)',
        }}
      >
        {/* Screen inset */}
        <div
          className="absolute overflow-hidden"
          style={{ inset: 4, borderRadius: 48, background: '#F5F7FA' }}
        >
          {/* Dynamic island */}
          <div
            className="absolute top-3 left-1/2 -translate-x-1/2 z-50 flex items-center justify-center"
            style={{ width: 100, height: 30, background: '#000', borderRadius: 20 }}
          >
            <div style={{ width: 10, height: 10, background: '#1C1C1E', borderRadius: '50%' }} />
          </div>
          {/* Content */}
          <div className="absolute inset-0 overflow-hidden">
            {children}
          </div>
        </div>

        {/* Physical buttons */}
        <div className="absolute" style={{ left: -3, top: 130, width: 3, height: 32, background: '#2A2A2A', borderRadius: '2px 0 0 2px' }} />
        <div className="absolute" style={{ left: -3, top: 172, width: 3, height: 32, background: '#2A2A2A', borderRadius: '2px 0 0 2px' }} />
        <div className="absolute" style={{ left: -3, top: 214, width: 3, height: 64, background: '#2A2A2A', borderRadius: '2px 0 0 2px' }} />
        <div className="absolute" style={{ right: -3, top: 170, width: 3, height: 80, background: '#2A2A2A', borderRadius: '0 2px 2px 0' }} />
      </div>
      {label && (
        <span style={{ fontSize: 11, fontWeight: 500, color: 'rgba(255,255,255,0.35)', letterSpacing: '0.06em', textTransform: 'uppercase', fontFamily: 'var(--body)' }}>
          {label}
        </span>
      )}
    </div>
  )
}

// ── Shared map components ────────────────────────────────────────────────

export function AcraMap({ height = 240 }: { height?: number }) {
  return (
    <div style={{ position: 'relative', width: '100%', height, overflow: 'hidden' }}>
      <iframe
        src="https://www.openstreetmap.org/export/embed.html?bbox=-0.2300%2C5.5500%2C-0.1400%2C5.6400&layer=mapnik&marker=5.5713%2C-0.2069"
        style={{ width: '100%', height: '100%', border: 'none', pointerEvents: 'none', display: 'block' }}
        scrolling="no"
        title="Accra map"
      />
      {/* User location dot overlay */}
      <svg width="100%" height="100%" viewBox="0 0 390 240" preserveAspectRatio="xMidYMid slice" style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        <circle cx="195" cy="120" r="24" fill="#0E9E6D" opacity="0.15" className="anim-pulse" />
        <circle cx="195" cy="120" r="14" fill="#0E9E6D" opacity="0.25" />
        <circle cx="195" cy="120" r="7" fill="#0E9E6D" />
        <circle cx="195" cy="120" r="3" fill="white" />
      </svg>
    </div>
  )
}

export function BusPin({ x, y, seats, amber = false }: { x: number; y: number; seats: number; amber?: boolean }) {
  const fill = amber ? '#F4B333' : '#0E9E6D'
  return (
    <g>
      <circle cx={x} cy={y} r="16" fill={fill} style={{ filter: `drop-shadow(0 3px 6px ${amber ? 'rgba(244,179,51,0.5)' : 'rgba(14,158,109,0.5)'})` }} />
      <path d="M-6,-5 h12 a2,2 0 0 1 2,2 v6 a2,2 0 0 1 -2,2 h-12 a2,2 0 0 1 -2,-2 v-6 a2,2 0 0 1 2,-2 z M-5,-2 h3 v4 h-3 z M1,-2 h3 v4 h-3 z" fill="white" opacity="0.9" transform={`translate(${x},${y})`} />
      {/* seat badge */}
      <rect x={x + 8} y={y - 22} width={seats > 9 ? 20 : 17} height={14} rx={7} fill={fill} />
      <text x={x + (seats > 9 ? 18 : 16.5)} y={y - 14} textAnchor="middle" fill="white" fontSize="8" fontWeight="700" fontFamily="Inter, sans-serif">{seats}</text>
    </g>
  )
}

// ── Utility ──────────────────────────────────────────────────────────────

export function Chip({ color, label }: { color: 'green' | 'amber' | 'gray' | 'red' | 'blue'; label: string }) {
  const map = {
    green: { bg: 'rgba(14,158,109,0.12)', text: '#0B7E57' },
    amber: { bg: 'rgba(244,179,51,0.15)', text: '#B8860B' },
    gray: { bg: '#E4E8EE', text: '#5B6472' },
    red: { bg: 'rgba(226,61,61,0.12)', text: '#C12B2B' },
    blue: { bg: 'rgba(31,111,178,0.12)', text: '#1557A0' },
  }
  const s = map[color]
  return (
    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold" style={{ background: s.bg, color: s.text }}>
      {label}
    </span>
  )
}
