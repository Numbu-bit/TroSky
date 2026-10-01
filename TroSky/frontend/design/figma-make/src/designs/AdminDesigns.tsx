import { useState } from 'react'
import { AreaChart, Area, BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts'
import troSkyLogo from '@/imports/WhatsApp_Image_2026-07-29_at_16.20.47.jpeg'

type AdminView = 'overview' | 'fleet' | 'drivers' | 'analytics' | 'fraud' | 'routes' | 'reports'

const revenueData = [
  { m: 'Feb', v: 38200 }, { m: 'Mar', v: 42100 }, { m: 'Apr', v: 39800 },
  { m: 'May', v: 51200 }, { m: 'Jun', v: 58400 }, { m: 'Jul', v: 66800 },
]
const userGrowthData = [
  { m: 'Feb', p: 8200, d: 420 }, { m: 'Mar', p: 10400, d: 480 },
  { m: 'Apr', p: 12100, d: 510 }, { m: 'May', p: 15800, d: 590 },
  { m: 'Jun', p: 19200, d: 640 }, { m: 'Jul', p: 24600, d: 720 },
]
const demandData = [
  { h: '5am', v: 120 }, { h: '6am', v: 380 }, { h: '7am', v: 860 },
  { h: '8am', v: 1240 }, { h: '9am', v: 680 }, { h: '10am', v: 340 },
  { h: '12pm', v: 420 }, { h: '3pm', v: 440 }, { h: '5pm', v: 1180 }, { h: '6pm', v: 940 },
]
const ratingDist = [
  { name: '5★', value: 58 }, { name: '4★', value: 28 },
  { name: '3★', value: 9 }, { name: '2★', value: 3 }, { name: '1★', value: 2 },
]
const RCOLS = ['#0E9E6D', '#1F6FB2', '#F4B333', '#E2924A', '#E23D3D']

const kpis = [
  { label: 'Active Buses', value: '184', delta: '+12 today', up: true, icon: '🚌', accent: '#0E9E6D' },
  { label: 'Active Trips', value: '347', delta: '+8% vs last wk', up: true, icon: '🗺️', accent: '#1F6FB2' },
  { label: 'Revenue Today', value: '₵66,840', delta: '+23% vs last wk', up: true, icon: '💰', accent: '#F4B333' },
  { label: 'Total Users', value: '25,320', delta: '+340 new today', up: true, icon: '👥', accent: '#0E9E6D' },
]

const fleetRows = [
  { id: 'GR-4821', driver: 'Akosua Boateng', route: 'Madina → Circle', occ: '9/14', status: 'moving' },
  { id: 'GR-1234', driver: 'Kofi Mensah', route: 'Legon → Osu', occ: '6/14', status: 'moving' },
  { id: 'GR-5519', driver: 'Ama Asante', route: 'Achimota → Tema', occ: '14/14', status: 'moving' },
  { id: 'GR-8821', driver: 'Yaw Boadu', route: '—', occ: '0/14', status: 'idle' },
  { id: 'GR-3310', driver: 'Abena Darkwa', route: '—', occ: '0/14', status: 'offline' },
  { id: 'GR-7712', driver: 'Kweku Frimpong', route: 'East Legon → Circle', occ: '11/14', status: 'moving' },
]

const driverRows = [
  { name: 'Akosua Boateng', rating: 4.9, trips: 1248, status: 'active', complaints: 0 },
  { name: 'Kofi Mensah', rating: 4.8, trips: 984, status: 'active', complaints: 1 },
  { name: 'Ama Asante', rating: 4.7, trips: 820, status: 'active', complaints: 0 },
  { name: 'Yaw Boadu', rating: 4.2, trips: 450, status: 'flagged', complaints: 4 },
  { name: 'Abena Darkwa', rating: 4.9, trips: 1102, status: 'active', complaints: 0 },
  { name: 'Kweku Frimpong', rating: 3.8, trips: 210, status: 'suspended', complaints: 7 },
]

const fraudAlerts = [
  { id: 'ALT-001', type: 'Speed Violation', desc: 'GR-4821 exceeded 80 km/h on Madina Rd', sev: 'medium', time: '07:32 AM', driver: 'Akosua Boateng' },
  { id: 'ALT-002', type: 'Duplicate Booking', desc: '3 identical bookings from single IP', sev: 'high', time: '06:58 AM', driver: 'N/A' },
  { id: 'ALT-003', type: 'Route Deviation', desc: 'GR-5519 deviated 2.3 km from route', sev: 'medium', time: '07:15 AM', driver: 'Ama Asante' },
  { id: 'ALT-004', type: 'Payment Anomaly', desc: '₵1,200 top-up flagged for review', sev: 'high', time: '06:40 AM', driver: 'N/A' },
  { id: 'ALT-005', type: 'Excess Cancels', desc: 'UID-8821 cancelled 8 trips in 1 hr', sev: 'low', time: '08:05 AM', driver: 'N/A' },
]

const topRoutes = [
  { route: 'Madina → Circle', trips: 840, rev: '₵12,040', demand: 95 },
  { route: 'Legon → Osu', trips: 620, rev: '₵8,680', demand: 82 },
  { route: 'Achimota → Tema', trips: 540, rev: '₵9,720', demand: 74 },
  { route: 'Kaneshie → Lapaz', trips: 410, rev: '₵5,330', demand: 60 },
  { route: 'East Legon → Circle', trips: 380, rev: '₵6,460', demand: 55 },
]

function StatusChip({ s }: { s: string }) {
  const m: Record<string, { bg: string; fg: string; t: string }> = {
    moving: { bg: 'rgba(14,158,109,0.1)', fg: '#0B7E57', t: '● Moving' },
    idle: { bg: 'rgba(244,179,51,0.12)', fg: '#B8860B', t: '● Idle' },
    offline: { bg: '#E4E8EE', fg: '#5B6472', t: '○ Offline' },
    active: { bg: 'rgba(14,158,109,0.1)', fg: '#0B7E57', t: '✓ Active' },
    flagged: { bg: 'rgba(244,179,51,0.12)', fg: '#B8860B', t: '⚠ Flagged' },
    suspended: { bg: 'rgba(226,61,61,0.1)', fg: '#C12B2B', t: '✕ Suspended' },
    high: { bg: 'rgba(226,61,61,0.1)', fg: '#C12B2B', t: '● High' },
    medium: { bg: 'rgba(244,179,51,0.12)', fg: '#B8860B', t: '● Medium' },
    low: { bg: 'rgba(14,158,109,0.1)', fg: '#0B7E57', t: '● Low' },
    open: { bg: 'rgba(226,61,61,0.1)', fg: '#C12B2B', t: '● Open' },
    'under review': { bg: 'rgba(244,179,51,0.12)', fg: '#B8860B', t: '🔍 Reviewing' },
    resolved: { bg: 'rgba(14,158,109,0.1)', fg: '#0B7E57', t: '✓ Resolved' },
    verified: { bg: 'rgba(14,158,109,0.1)', fg: '#0B7E57', t: '✓ Verified' },
    pending: { bg: 'rgba(244,179,51,0.12)', fg: '#B8860B', t: '⏳ Pending' },
  }
  const c = m[s] || m.low
  return <span style={{ background: c.bg, color: c.fg, fontSize: 11, fontWeight: 600, padding: '3px 10px', borderRadius: 20 }}>{c.t}</span>
}

function Card({ children, style = {} }: { children: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <div style={{ background: 'white', borderRadius: 20, boxShadow: '0 2px 16px rgba(0,0,0,0.06)', ...style }}>
      {children}
    </div>
  )
}

function AdminMap({ type = 'light' }: { type?: 'light' | 'demand' }) {
  const dark = type === 'demand'
  return (
    <div style={{ position: 'relative', width: '100%', height: 280, borderRadius: 14, overflow: 'hidden' }}>
      <iframe
        src="https://www.openstreetmap.org/export/embed.html?bbox=-0.2600%2C5.5200%2C-0.1100%2C5.6700&layer=mapnik"
        style={{ width: '100%', height: '100%', border: 'none', pointerEvents: 'none', display: 'block',
          filter: dark ? 'invert(90%) hue-rotate(180deg) brightness(0.75) saturate(0.85)' : 'none' }}
        scrolling="no"
        title="Accra overview map"
      />
      {/* Overlay: bus markers (light) or demand heat circles (dark) */}
      <svg width="100%" height="100%" viewBox="0 0 900 280" preserveAspectRatio="xMidYMid slice"
        style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        {dark ? (
          <>
            <circle cx="450" cy="140" r="80" fill="#F4B333" opacity="0.18" />
            <circle cx="450" cy="140" r="45" fill="#F4B333" opacity="0.14" />
            <circle cx="180" cy="90"  r="60" fill="#E23D3D" opacity="0.18" />
            <circle cx="180" cy="90"  r="32" fill="#E23D3D" opacity="0.14" />
            <circle cx="720" cy="190" r="55" fill="#E23D3D" opacity="0.15" />
            <circle cx="720" cy="140" r="50" fill="#F4B333" opacity="0.14" />
            {([['Madina Jct', 180, 90, '#E23D3D'], ['Circle', 450, 140, '#F4B333'], ['Airport', 720, 140, '#E23D3D'], ['Osu', 620, 190, '#F4B333']] as [string, number, number, string][]).map(([lbl, cx, cy, c]) => (
              <g key={lbl}>
                <circle cx={cx} cy={cy} r="9" fill={c} />
                <rect x={cx - 28} y={cy - 26} width="56" height="16" rx="8" fill="rgba(0,0,0,0.55)" />
                <text x={cx} y={cy - 15} textAnchor="middle" fill="white" fontSize="10" fontFamily="Inter, sans-serif">{lbl}</text>
              </g>
            ))}
          </>
        ) : (
          <>
            {([[120, 90, '#0E9E6D'], [380, 90, '#0E9E6D'], [560, 190, '#0E9E6D'], [720, 90, '#F4B333'], [290, 190, '#0E9E6D'], [800, 190, '#5B6472']] as [number, number, string][]).map(([cx, cy, fill], i) => (
              <g key={i}>
                <circle cx={cx} cy={cy} r="15" fill={fill} opacity="0.92" />
                <text x={cx} y={cy + 1} textAnchor="middle" dominantBaseline="middle" fontSize="13">🚌</text>
              </g>
            ))}
          </>
        )}
      </svg>
    </div>
  )
}

// ── Overview ─────────────────────────────────────────────────────────

function OverviewPanel() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <h1 style={{ fontSize: 26, fontWeight: 800, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>Overview</h1>
        <p style={{ fontSize: 13, color: '#5B6472' }}>Thursday, 31 Jul 2026 · Refreshed just now</p>
      </div>
      {/* KPIs */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
        {kpis.map(k => (
          <Card key={k.label} style={{ padding: '20px 20px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 14 }}>
              <div style={{ width: 40, height: 40, borderRadius: 12, background: `${k.accent}18`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>{k.icon}</div>
              <span style={{ fontSize: 11, fontWeight: 600, background: 'rgba(14,158,109,0.1)', color: '#0B7E57', padding: '3px 8px', borderRadius: 12 }}>↑ {k.up ? '+' : ''}</span>
            </div>
            <p style={{ fontSize: 28, fontWeight: 800, color: k.accent === '#F4B333' ? k.accent : '#1D2027', fontFamily: 'var(--heading)', lineHeight: 1, marginBottom: 4 }}>{k.value}</p>
            <p style={{ fontSize: 13, color: '#5B6472', marginBottom: 4 }}>{k.label}</p>
            <p style={{ fontSize: 11, fontWeight: 600, color: '#0E9E6D' }}>{k.delta}</p>
          </Card>
        ))}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 20 }}>
        <Card>
          <div style={{ padding: '18px 20px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <h3 style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)' }}>Live Fleet Map</h3>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: '#5B6472' }}>
              <div style={{ width: 7, height: 7, borderRadius: '50%', background: '#0E9E6D' }} />
              184 vehicles online
            </div>
          </div>
          <div style={{ padding: '0 16px 16px' }}><AdminMap /></div>
        </Card>
        <Card style={{ padding: '18px 18px' }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 14 }}>Recent Alerts</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {fraudAlerts.slice(0, 4).map(a => (
              <div key={a.id} style={{ background: '#F5F7FA', borderRadius: 12, padding: '10px 12px', display: 'flex', gap: 10 }}>
                <div style={{ width: 7, height: 7, borderRadius: '50%', background: a.sev === 'high' ? '#E23D3D' : '#F4B333', marginTop: 4, flexShrink: 0 }} />
                <div>
                  <p style={{ fontSize: 12, fontWeight: 600, color: '#1D2027' }}>{a.type}</p>
                  <p style={{ fontSize: 11, color: '#5B6472', marginTop: 1 }}>{a.desc}</p>
                  <p style={{ fontSize: 10, color: '#5B6472', marginTop: 2 }}>{a.time}</p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>
      <Card style={{ padding: '18px 20px' }}>
        <h3 style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 16 }}>Top Routes Today</h3>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              {['Route', 'Trips', 'Revenue', 'Demand'].map(h => (
                <th key={h} style={{ textAlign: 'left', paddingBottom: 10, paddingRight: 20, fontSize: 11, fontWeight: 600, color: '#5B6472', letterSpacing: '0.04em', borderBottom: '1px solid #E4E8EE' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {topRoutes.map((r, i) => (
              <tr key={i}>
                <td style={{ padding: '12px 20px 12px 0', fontSize: 13, fontWeight: 500, color: '#1D2027', borderBottom: '1px solid #E4E8EE' }}>{r.route}</td>
                <td style={{ padding: '12px 20px 12px 0', fontSize: 13, color: '#1D2027', borderBottom: '1px solid #E4E8EE' }}>{r.trips}</td>
                <td style={{ padding: '12px 20px 12px 0', fontSize: 13, fontWeight: 600, color: '#0E9E6D', borderBottom: '1px solid #E4E8EE' }}>{r.rev}</td>
                <td style={{ padding: '12px 0 12px 0', borderBottom: '1px solid #E4E8EE' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ width: 80, height: 6, borderRadius: 3, background: '#E4E8EE', overflow: 'hidden' }}>
                      <div style={{ height: '100%', borderRadius: 3, background: r.demand > 80 ? '#E23D3D' : r.demand > 60 ? '#F4B333' : '#0E9E6D', width: `${r.demand}%` }} />
                    </div>
                    <span style={{ fontSize: 12, color: '#5B6472' }}>{r.demand}%</span>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  )
}

// ── Fleet ─────────────────────────────────────────────────────────────

function FleetPanel() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
        <div>
          <h1 style={{ fontSize: 26, fontWeight: 800, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>Fleet Monitoring</h1>
          <p style={{ fontSize: 13, color: '#5B6472' }}>184 moving · 12 idle · 8 offline</p>
        </div>
        <button style={{ padding: '10px 20px', borderRadius: 12, background: '#0E9E6D', color: 'white', fontSize: 13, fontWeight: 600 }}>Export CSV</button>
      </div>
      <Card>
        <div style={{ padding: '18px 20px 14px' }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)' }}>Live Map</h3>
        </div>
        <div style={{ padding: '0 16px 16px' }}><AdminMap /></div>
      </Card>
      <Card style={{ padding: '18px 20px' }}>
        <h3 style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 16 }}>Vehicles</h3>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              {['Vehicle ID', 'Driver', 'Route', 'Occupancy', 'Status'].map(h => (
                <th key={h} style={{ textAlign: 'left', paddingBottom: 10, paddingRight: 20, fontSize: 11, fontWeight: 600, color: '#5B6472', letterSpacing: '0.04em', borderBottom: '1px solid #E4E8EE' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {fleetRows.map((r, i) => (
              <tr key={i}>
                <td style={{ padding: '12px 20px 12px 0', fontSize: 13, fontWeight: 700, color: '#12263B', borderBottom: '1px solid #E4E8EE' }}>{r.id}</td>
                <td style={{ padding: '12px 20px 12px 0', fontSize: 13, color: '#1D2027', borderBottom: '1px solid #E4E8EE' }}>{r.driver}</td>
                <td style={{ padding: '12px 20px 12px 0', fontSize: 13, color: '#5B6472', borderBottom: '1px solid #E4E8EE' }}>{r.route}</td>
                <td style={{ padding: '12px 20px 12px 0', borderBottom: '1px solid #E4E8EE' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ width: 60, height: 5, borderRadius: 3, background: '#E4E8EE', overflow: 'hidden' }}>
                      <div style={{ height: '100%', background: r.occ === '14/14' ? '#E23D3D' : parseInt(r.occ) > 8 ? '#F4B333' : '#0E9E6D', width: r.occ === '0/14' ? '0%' : `${(parseInt(r.occ) / 14) * 100}%` }} />
                    </div>
                    <span style={{ fontSize: 12, color: '#5B6472' }}>{r.occ}</span>
                  </div>
                </td>
                <td style={{ padding: '12px 0 12px 0', borderBottom: '1px solid #E4E8EE' }}><StatusChip s={r.status} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  )
}

// ── Analytics ─────────────────────────────────────────────────────────

function AnalyticsPanel() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <h1 style={{ fontSize: 26, fontWeight: 800, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>Performance Analytics</h1>
        <p style={{ fontSize: 13, color: '#5B6472' }}>Feb – Jul 2026</p>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        <Card style={{ padding: '20px 20px' }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>Revenue Over Time</h3>
          <p style={{ fontSize: 12, color: '#5B6472', marginBottom: 16 }}>Monthly revenue (₵)</p>
          <ResponsiveContainer width="100%" height={180}>
            <AreaChart data={revenueData}>
              <defs>
                <linearGradient id="rg" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#0E9E6D" stopOpacity={0.2} />
                  <stop offset="95%" stopColor="#0E9E6D" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#E4E8EE" />
              <XAxis dataKey="m" tick={{ fontSize: 11, fill: '#5B6472' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 11, fill: '#5B6472' }} axisLine={false} tickLine={false} tickFormatter={v => `₵${(v/1000).toFixed(0)}k`} />
              <Tooltip contentStyle={{ borderRadius: 12, border: 'none', boxShadow: '0 8px 24px rgba(0,0,0,0.12)', fontSize: 12 }} />
              <Area type="monotone" dataKey="v" stroke="#0E9E6D" strokeWidth={2.5} fill="url(#rg)" name="Revenue" />
            </AreaChart>
          </ResponsiveContainer>
        </Card>
        <Card style={{ padding: '20px 20px' }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>Hourly Demand</h3>
          <p style={{ fontSize: 12, color: '#5B6472', marginBottom: 16 }}>Weekday average trip requests</p>
          <ResponsiveContainer width="100%" height={180}>
            <BarChart data={demandData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#E4E8EE" />
              <XAxis dataKey="h" tick={{ fontSize: 10, fill: '#5B6472' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 11, fill: '#5B6472' }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={{ borderRadius: 12, border: 'none', boxShadow: '0 8px 24px rgba(0,0,0,0.12)', fontSize: 12 }} />
              <Bar dataKey="v" name="Requests" radius={[4, 4, 0, 0]}>
                {demandData.map((e, i) => (
                  <Cell key={i} fill={e.v > 800 ? '#E23D3D' : e.v > 500 ? '#F4B333' : '#0E9E6D'} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </Card>
        <Card style={{ padding: '20px 20px' }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>Driver Rating Distribution</h3>
          <p style={{ fontSize: 12, color: '#5B6472', marginBottom: 12 }}>720 active drivers</p>
          <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
            <ResponsiveContainer width={140} height={140}>
              <PieChart>
                <Pie data={ratingDist} cx="50%" cy="50%" innerRadius={36} outerRadius={62} dataKey="value" paddingAngle={2}>
                  {ratingDist.map((_, i) => <Cell key={i} fill={RCOLS[i]} />)}
                </Pie>
              </PieChart>
            </ResponsiveContainer>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {ratingDist.map((r, i) => (
                <div key={r.name} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={{ width: 10, height: 10, borderRadius: '50%', background: RCOLS[i] }} />
                  <span style={{ fontSize: 13, color: '#1D2027', fontWeight: 500, width: 28 }}>{r.name}</span>
                  <span style={{ fontSize: 12, color: '#5B6472' }}>{r.value}%</span>
                </div>
              ))}
            </div>
          </div>
        </Card>
        <Card style={{ padding: '20px 20px' }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>User Growth</h3>
          <p style={{ fontSize: 12, color: '#5B6472', marginBottom: 16 }}>Passengers &amp; drivers acquired</p>
          <ResponsiveContainer width="100%" height={180}>
            <LineChart data={userGrowthData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#E4E8EE" />
              <XAxis dataKey="m" tick={{ fontSize: 11, fill: '#5B6472' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 11, fill: '#5B6472' }} axisLine={false} tickLine={false} tickFormatter={v => `${(v/1000).toFixed(0)}k`} />
              <Tooltip contentStyle={{ borderRadius: 12, border: 'none', boxShadow: '0 8px 24px rgba(0,0,0,0.12)', fontSize: 12 }} />
              <Line type="monotone" dataKey="p" stroke="#0E9E6D" strokeWidth={2.5} dot={false} name="Passengers" />
              <Line type="monotone" dataKey="d" stroke="#1F6FB2" strokeWidth={2.5} dot={false} name="Drivers" />
            </LineChart>
          </ResponsiveContainer>
        </Card>
      </div>
    </div>
  )
}

// ── Fraud ─────────────────────────────────────────────────────────────

function FraudPanel() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <h1 style={{ fontSize: 26, fontWeight: 800, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>Fraud Detection</h1>
        <p style={{ fontSize: 13, color: '#5B6472' }}>AI-powered anomaly monitoring · 5 alerts today</p>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
        {[['🔴', 'High Severity', '2', 'rgba(226,61,61,0.06)'], ['🟡', 'Medium', '2', 'rgba(244,179,51,0.06)'], ['🟢', 'Low', '1', 'rgba(14,158,109,0.06)']].map(([icon, label, count, bg]) => (
          <Card key={label as string} style={{ padding: '20px 20px', background: bg as string, textAlign: 'center' }}>
            <span style={{ fontSize: 28, display: 'block', marginBottom: 6 }}>{icon as string}</span>
            <p style={{ fontSize: 28, fontWeight: 800, color: '#1D2027', fontFamily: 'var(--heading)', lineHeight: 1, marginBottom: 4 }}>{count as string}</p>
            <p style={{ fontSize: 13, color: '#5B6472' }}>{label as string}</p>
          </Card>
        ))}
      </div>
      <Card style={{ padding: '20px 20px' }}>
        <h3 style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 16 }}>Active Alerts</h3>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              {['ID', 'Type', 'Description', 'Driver/User', 'Time', 'Severity', 'Action'].map(h => (
                <th key={h} style={{ textAlign: 'left', paddingBottom: 10, paddingRight: 16, fontSize: 11, fontWeight: 600, color: '#5B6472', letterSpacing: '0.04em', borderBottom: '1px solid #E4E8EE' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {fraudAlerts.map((a, i) => (
              <tr key={i}>
                <td style={{ padding: '12px 16px 12px 0', fontSize: 11, fontFamily: 'monospace', color: '#5B6472', borderBottom: '1px solid #E4E8EE' }}>{a.id}</td>
                <td style={{ padding: '12px 16px 12px 0', fontSize: 13, fontWeight: 600, color: '#1D2027', borderBottom: '1px solid #E4E8EE' }}>{a.type}</td>
                <td style={{ padding: '12px 16px 12px 0', fontSize: 12, color: '#5B6472', maxWidth: 200, borderBottom: '1px solid #E4E8EE' }}>{a.desc}</td>
                <td style={{ padding: '12px 16px 12px 0', fontSize: 13, color: '#1D2027', borderBottom: '1px solid #E4E8EE' }}>{a.driver}</td>
                <td style={{ padding: '12px 16px 12px 0', fontSize: 12, color: '#5B6472', borderBottom: '1px solid #E4E8EE' }}>{a.time}</td>
                <td style={{ padding: '12px 16px 12px 0', borderBottom: '1px solid #E4E8EE' }}><StatusChip s={a.sev} /></td>
                <td style={{ padding: '12px 0 12px 0', borderBottom: '1px solid #E4E8EE' }}>
                  <div style={{ display: 'flex', gap: 12 }}>
                    <button style={{ fontSize: 12, fontWeight: 600, color: '#1F6FB2' }}>Review</button>
                    <button style={{ fontSize: 12, fontWeight: 500, color: '#5B6472' }}>Dismiss</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
      <Card style={{ padding: '20px 20px' }}>
        <h3 style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 14 }}>Driver Management</h3>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              {['Driver', 'Rating', 'Total Trips', 'Complaints', 'Status', 'Action'].map(h => (
                <th key={h} style={{ textAlign: 'left', paddingBottom: 10, paddingRight: 16, fontSize: 11, fontWeight: 600, color: '#5B6472', letterSpacing: '0.04em', borderBottom: '1px solid #E4E8EE' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {driverRows.map((d, i) => (
              <tr key={i}>
                <td style={{ padding: '10px 16px 10px 0', borderBottom: '1px solid #E4E8EE' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ width: 32, height: 32, borderRadius: '50%', background: '#F5F7FA', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>👤</div>
                    <span style={{ fontSize: 13, fontWeight: 500, color: '#1D2027' }}>{d.name}</span>
                  </div>
                </td>
                <td style={{ padding: '10px 16px 10px 0', fontSize: 13, fontWeight: 700, color: d.rating >= 4.5 ? '#0E9E6D' : d.rating >= 4 ? '#B8860B' : '#E23D3D', borderBottom: '1px solid #E4E8EE' }}>⭐ {d.rating}</td>
                <td style={{ padding: '10px 16px 10px 0', fontSize: 13, color: '#1D2027', borderBottom: '1px solid #E4E8EE' }}>{d.trips.toLocaleString()}</td>
                <td style={{ padding: '10px 16px 10px 0', fontSize: 13, fontWeight: 700, color: d.complaints > 3 ? '#E23D3D' : d.complaints > 0 ? '#B8860B' : '#0E9E6D', borderBottom: '1px solid #E4E8EE' }}>{d.complaints}</td>
                <td style={{ padding: '10px 16px 10px 0', borderBottom: '1px solid #E4E8EE' }}><StatusChip s={d.status} /></td>
                <td style={{ padding: '10px 0 10px 0', borderBottom: '1px solid #E4E8EE' }}>
                  <button style={{ fontSize: 12, fontWeight: 600, color: d.status === 'suspended' ? '#0E9E6D' : '#E23D3D' }}>
                    {d.status === 'suspended' ? 'Reactivate' : 'Suspend'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  )
}

// ── Demand map ────────────────────────────────────────────────────────

function DemandPanel() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <h1 style={{ fontSize: 26, fontWeight: 800, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>Demand Heat Map</h1>
        <p style={{ fontSize: 13, color: '#5B6472' }}>Identify high-demand corridors for route planning</p>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 20 }}>
        <Card>
          <div style={{ padding: '18px 20px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
            <h3 style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', flex: 1 }}>Accra Demand Map</h3>
            {['7am–9am', '12–2pm', '5–7pm'].map((t, i) => (
              <button key={t} style={{ padding: '6px 14px', borderRadius: 20, fontSize: 11, fontWeight: 600, background: i === 0 ? 'var(--navy)' : '#F5F7FA', color: i === 0 ? 'white' : '#5B6472' }}>{t}</button>
            ))}
          </div>
          <div style={{ padding: '0 16px 16px' }}><AdminMap type="demand" /></div>
          <div style={{ padding: '0 20px 16px', display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 80, height: 6, borderRadius: 3, background: 'linear-gradient(to right, rgba(14,158,109,0.6), #F4B333, #E23D3D)' }} />
            <span style={{ fontSize: 11, color: '#5B6472' }}>Low → High demand</span>
          </div>
        </Card>
        <Card style={{ padding: '18px 18px' }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 14 }}>Top Corridors</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {topRoutes.map((r, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, background: '#F5F7FA', borderRadius: 14, padding: '10px 14px' }}>
                <div style={{ width: 28, height: 28, borderRadius: '50%', background: i < 2 ? '#E23D3D' : '#F4B333', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>{i + 1}</div>
                <div style={{ flex: 1 }}>
                  <p style={{ fontSize: 12, fontWeight: 600, color: '#1D2027' }}>{r.route}</p>
                  <p style={{ fontSize: 11, color: '#5B6472' }}>{r.trips} trips/day</p>
                </div>
                <div style={{ width: 36, height: 36, borderRadius: '50%', background: r.demand > 80 ? 'rgba(226,61,61,0.1)' : 'rgba(244,179,51,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 700, color: r.demand > 80 ? '#E23D3D' : '#B8860B' }}>{r.demand}%</div>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  )
}

// ── Login ─────────────────────────────────────────────────────────────

function LoginPanel({ onLogin }: { onLogin: () => void }) {
  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'linear-gradient(160deg, #0d1a28 0%, #12263B 50%, #0a1820 100%)' }}>
      <div style={{ width: 420 }}>
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 10, background: 'white', borderRadius: 14, padding: '8px 16px 8px 10px', marginBottom: 16 }}>
            <img src={troSkyLogo} alt="TroSky" style={{ height: 36, objectFit: 'contain', display: 'block' }} />
            <span style={{ fontSize: 18, fontWeight: 800, color: '#0E9E6D', fontFamily: 'var(--heading)', letterSpacing: '-0.3px' }}>TroSky</span>
          </div>
          <h1 style={{ fontSize: 22, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)', marginBottom: 6 }}>Admin Console</h1>
          <p style={{ fontSize: 13, color: 'rgba(255,255,255,0.45)' }}>Sign in to your dashboard</p>
        </div>
        <div style={{ background: 'white', borderRadius: 24, padding: '28px 28px', boxShadow: '0 40px 80px rgba(0,0,0,0.4)' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginBottom: 20 }}>
            {[['Email address', 'admin@trosky.gh', 'text'], ['Password', '••••••••••', 'password']].map(([label, val, type]) => (
              <div key={label}>
                <p style={{ fontSize: 12, fontWeight: 600, color: '#5B6472', marginBottom: 8, letterSpacing: '0.04em' }}>{label.toUpperCase()}</p>
                <input defaultValue={val} type={type} style={{ width: '100%', height: 48, borderRadius: 12, border: '1.5px solid #E4E8EE', background: '#F5F7FA', padding: '0 16px', fontSize: 14, color: '#1D2027', boxSizing: 'border-box' }} />
              </div>
            ))}
          </div>
          <button onClick={onLogin} style={{ width: '100%', height: 52, borderRadius: 14, background: '#0E9E6D', color: 'white', fontSize: 15, fontWeight: 700, fontFamily: 'var(--heading)', boxShadow: '0 6px 20px rgba(14,158,109,0.35)' }}>
            Sign In
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Drivers Panel ─────────────────────────────────────────────────────

const verificationDocs = [
  { name: "Driver's License", status: 'verified' },
  { name: 'Vehicle Registration', status: 'verified' },
  { name: 'Police Clearance', status: 'verified' },
  { name: 'Vehicle Inspection', status: 'pending' },
]

function DriversPanel() {
  const [selectedDriver, setSelectedDriver] = useState(driverRows[0])

  const statCards = [
    { label: 'Total Drivers', value: '720', sub: '+12 this week', color: '#0E9E6D' },
    { label: 'Active Today', value: '614', sub: '85% utilisation', color: '#1F6FB2' },
    { label: 'Flagged', value: '4', sub: 'Needs review', color: '#F4B333' },
    { label: 'Suspended', value: '2', sub: 'Pending appeal', color: '#E23D3D' },
  ]

  return (
    <div style={{ padding: '32px 36px', background: '#F5F7FA', minHeight: '100vh' }}>
      <div style={{ marginBottom: 28 }}>
        <h1 style={{ fontSize: 26, fontWeight: 800, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>Driver Management</h1>
        <p style={{ fontSize: 13, color: '#5B6472' }}>Thursday, 31 Jul 2026 · 720 registered drivers</p>
      </div>

      {/* Stat cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16, marginBottom: 28 }}>
        {statCards.map(c => (
          <div key={c.label} style={{ background: 'white', borderRadius: 16, padding: '18px 20px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
            <div style={{ width: 36, height: 36, borderRadius: 10, background: c.color + '18', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
              <div style={{ width: 12, height: 12, borderRadius: '50%', background: c.color }} />
            </div>
            <p style={{ fontSize: 26, fontWeight: 800, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 2 }}>{c.value}</p>
            <p style={{ fontSize: 12, fontWeight: 600, color: '#5B6472', marginBottom: 2 }}>{c.label}</p>
            <p style={{ fontSize: 11, color: c.color, fontWeight: 500 }}>{c.sub}</p>
          </div>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 260px', gap: 20 }}>
        {/* Driver table */}
        <div style={{ background: 'white', borderRadius: 16, boxShadow: '0 2px 12px rgba(0,0,0,0.05)', overflow: 'hidden', minWidth: 0 }}>
          <div style={{ padding: '14px 16px 12px', borderBottom: '1px solid #E4E8EE', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
            <p style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)' }}>All Drivers</p>
            <div style={{ display: 'flex', gap: 8 }}>
              <input placeholder="Search driver..." style={{ fontSize: 12, padding: '5px 10px', borderRadius: 8, border: '1px solid #E4E8EE', outline: 'none', color: '#1D2027', width: 130 }} readOnly />
              <button style={{ padding: '5px 12px', borderRadius: 8, background: '#0E9E6D', color: 'white', fontSize: 12, fontWeight: 600, border: 'none', whiteSpace: 'nowrap' }}>+ Add Driver</button>
            </div>
          </div>
          <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', tableLayout: 'fixed', minWidth: 560 }}>
            <colgroup>
              <col style={{ width: '28%' }} />
              <col style={{ width: '10%' }} />
              <col style={{ width: '10%' }} />
              <col style={{ width: '12%' }} />
              <col style={{ width: '18%' }} />
              <col style={{ width: '22%' }} />
            </colgroup>
            <thead>
              <tr style={{ background: '#F5F7FA' }}>
                {['Driver', 'Rating', 'Trips', 'Issues', 'Status', 'Actions'].map(h => (
                  <th key={h} style={{ padding: '9px 12px', fontSize: 11, fontWeight: 700, color: '#5B6472', letterSpacing: '0.04em', textAlign: 'left', borderBottom: '1px solid #E4E8EE' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {driverRows.map((d, i) => (
                <tr key={i} onClick={() => setSelectedDriver(d)} style={{ cursor: 'pointer', background: selectedDriver.name === d.name ? 'rgba(14,158,109,0.04)' : 'transparent' }}>
                  <td style={{ padding: '10px 12px', borderBottom: '1px solid #E4E8EE', overflow: 'hidden' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <div style={{ width: 30, height: 30, borderRadius: '50%', background: 'linear-gradient(135deg,#0E9E6D,#1F6FB2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: 12, fontWeight: 700, flexShrink: 0 }}>{d.name[0]}</div>
                      <div style={{ minWidth: 0 }}>
                        <p style={{ fontSize: 12, fontWeight: 600, color: '#1D2027', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{d.name}</p>
                        <p style={{ fontSize: 10, color: '#5B6472' }}>GR-{4000 + i * 321}</p>
                      </div>
                    </div>
                  </td>
                  <td style={{ padding: '10px 12px', borderBottom: '1px solid #E4E8EE' }}>
                    <span style={{ fontSize: 12, color: '#F4B333' }}>★ </span>
                    <span style={{ fontSize: 12, fontWeight: 600, color: '#1D2027' }}>{d.rating}</span>
                  </td>
                  <td style={{ padding: '10px 12px', fontSize: 12, color: '#1D2027', borderBottom: '1px solid #E4E8EE' }}>{d.trips.toLocaleString()}</td>
                  <td style={{ padding: '10px 12px', fontSize: 12, borderBottom: '1px solid #E4E8EE', color: d.complaints > 3 ? '#E23D3D' : '#1D2027', fontWeight: d.complaints > 3 ? 700 : 400 }}>{d.complaints}</td>
                  <td style={{ padding: '10px 12px', borderBottom: '1px solid #E4E8EE' }}><StatusChip s={d.status} /></td>
                  <td style={{ padding: '10px 12px', borderBottom: '1px solid #E4E8EE' }}>
                    <div style={{ display: 'flex', gap: 4 }}>
                      <button style={{ padding: '3px 8px', borderRadius: 6, background: 'rgba(31,111,178,0.1)', color: '#1F6FB2', fontSize: 11, fontWeight: 600, border: 'none', cursor: 'pointer', whiteSpace: 'nowrap' }}>View</button>
                      {d.status !== 'suspended'
                        ? <button style={{ padding: '3px 8px', borderRadius: 6, background: 'rgba(226,61,61,0.08)', color: '#E23D3D', fontSize: 11, fontWeight: 600, border: 'none', cursor: 'pointer', whiteSpace: 'nowrap' }}>Suspend</button>
                        : <button style={{ padding: '3px 8px', borderRadius: 6, background: 'rgba(14,158,109,0.1)', color: '#0E9E6D', fontSize: 11, fontWeight: 600, border: 'none', cursor: 'pointer', whiteSpace: 'nowrap' }}>Reactivate</button>
                      }
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          </div>{/* end overflowX scroll wrapper */}
        </div>

        {/* Driver detail card */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ background: 'white', borderRadius: 16, padding: '20px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16, paddingBottom: 16, borderBottom: '1px solid #E4E8EE' }}>
              <div style={{ width: 52, height: 52, borderRadius: '50%', background: 'linear-gradient(135deg,#0E9E6D,#1F6FB2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: 20, fontWeight: 800 }}>{selectedDriver.name[0]}</div>
              <div>
                <p style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)' }}>{selectedDriver.name}</p>
                <StatusChip s={selectedDriver.status} />
              </div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
              {[['Trips', selectedDriver.trips.toLocaleString()], ['Rating', `★ ${selectedDriver.rating}`], ['Complaints', String(selectedDriver.complaints)], ['Earnings', '₵' + (selectedDriver.trips * 3.2).toFixed(0)]].map(([l, v]) => (
                <div key={l} style={{ background: '#F5F7FA', borderRadius: 10, padding: '10px 12px' }}>
                  <p style={{ fontSize: 10, color: '#5B6472', marginBottom: 3 }}>{l}</p>
                  <p style={{ fontSize: 16, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)' }}>{v}</p>
                </div>
              ))}
            </div>
            {/* Rating breakdown */}
            <p style={{ fontSize: 11, fontWeight: 700, color: '#5B6472', letterSpacing: '0.05em', marginBottom: 10 }}>PERFORMANCE</p>
            {[['Safety', 98], ['Punctuality', 94], ['Cleanliness', 92], ['Professionalism', 96]].map(([label, pct]) => (
              <div key={label} style={{ marginBottom: 8 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 3 }}>
                  <span style={{ fontSize: 12, color: '#3D4552' }}>{label}</span>
                  <span style={{ fontSize: 12, fontWeight: 600, color: '#1D2027' }}>{pct}%</span>
                </div>
                <div style={{ height: 5, borderRadius: 3, background: '#E4E8EE' }}>
                  <div style={{ height: 5, borderRadius: 3, background: '#0E9E6D', width: `${pct}%` }} />
                </div>
              </div>
            ))}
          </div>

          {/* Verification docs */}
          <div style={{ background: 'white', borderRadius: 16, padding: '16px 20px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
            <p style={{ fontSize: 13, fontWeight: 700, color: '#1D2027', marginBottom: 12 }}>Verification Documents</p>
            {verificationDocs.map(doc => (
              <div key={doc.name} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBlock: 8, borderBottom: '1px solid #F0F2F5' }}>
                <p style={{ fontSize: 12, color: '#3D4552' }}>{doc.name}</p>
                <StatusChip s={doc.status} />
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}

// ── Reports Panel ──────────────────────────────────────────────────────

const incidentReports = [
  { id: 'RPT-2041', type: 'Breakdown', driver: 'Yaw Boadu', route: 'Achimota → Tema', date: 'Today 07:14', status: 'open', severity: 'medium' },
  { id: 'RPT-2040', type: 'Passenger Complaint', driver: 'Kweku Frimpong', route: 'Madina → Circle', date: 'Today 06:50', status: 'under review', severity: 'high' },
  { id: 'RPT-2039', type: 'Accident', driver: 'Kofi Mensah', route: 'Legon → Osu', date: 'Yesterday 17:30', status: 'resolved', severity: 'high' },
  { id: 'RPT-2038', type: 'Road Hazard', driver: 'Akosua Boateng', route: 'Circle → Airport', date: 'Yesterday 15:12', status: 'resolved', severity: 'low' },
  { id: 'RPT-2037', type: 'Overspending', driver: 'Abena Darkwa', route: 'East Legon → Circle', date: 'Mon 09:40', status: 'resolved', severity: 'medium' },
]

function ReportsPanel() {
  const summaryCards = [
    { label: 'Open Reports', value: '6', color: '#E23D3D', icon: '🚨' },
    { label: 'Under Review', value: '3', color: '#F4B333', icon: '🔍' },
    { label: 'Resolved Today', value: '11', color: '#0E9E6D', icon: '✅' },
    { label: 'Avg. Resolution', value: '2.4h', color: '#1F6FB2', icon: '⏱️' },
  ]

  return (
    <div style={{ padding: '32px 36px', background: '#F5F7FA', minHeight: '100vh' }}>
      <div style={{ marginBottom: 28 }}>
        <h1 style={{ fontSize: 26, fontWeight: 800, color: '#1D2027', fontFamily: 'var(--heading)', marginBottom: 4 }}>Reports & Incidents</h1>
        <p style={{ fontSize: 13, color: '#5B6472' }}>Thursday, 31 Jul 2026 · All platform incidents and reports</p>
      </div>

      {/* Summary cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16, marginBottom: 28 }}>
        {summaryCards.map(c => (
          <div key={c.label} style={{ background: 'white', borderRadius: 16, padding: '18px 20px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)', display: 'flex', alignItems: 'center', gap: 14 }}>
            <div style={{ width: 44, height: 44, borderRadius: 12, background: c.color + '18', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, flexShrink: 0 }}>{c.icon}</div>
            <div>
              <p style={{ fontSize: 26, fontWeight: 800, color: '#1D2027', fontFamily: 'var(--heading)', lineHeight: 1 }}>{c.value}</p>
              <p style={{ fontSize: 12, color: '#5B6472', marginTop: 2 }}>{c.label}</p>
            </div>
          </div>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 240px', gap: 20 }}>
        {/* Incidents table */}
        <div style={{ background: 'white', borderRadius: 16, boxShadow: '0 2px 12px rgba(0,0,0,0.05)', overflow: 'hidden', minWidth: 0 }}>
          <div style={{ padding: '14px 16px 12px', borderBottom: '1px solid #E4E8EE', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
            <p style={{ fontSize: 15, fontWeight: 700, color: '#1D2027', fontFamily: 'var(--heading)' }}>Incident Reports</p>
            <div style={{ display: 'flex', gap: 8 }}>
              {['All', 'Open', 'Resolved'].map((f, i) => (
                <button key={f} style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, border: '1px solid', borderColor: i === 0 ? '#0E9E6D' : '#E4E8EE', background: i === 0 ? 'rgba(14,158,109,0.08)' : 'white', color: i === 0 ? '#0E9E6D' : '#5B6472', cursor: 'pointer' }}>{f}</button>
              ))}
            </div>
          </div>
          <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', tableLayout: 'fixed', minWidth: 640 }}>
            <colgroup>
              <col style={{ width: '10%' }} />
              <col style={{ width: '17%' }} />
              <col style={{ width: '14%' }} />
              <col style={{ width: '18%' }} />
              <col style={{ width: '12%' }} />
              <col style={{ width: '10%' }} />
              <col style={{ width: '13%' }} />
              <col style={{ width: '6%' }} />
            </colgroup>
            <thead>
              <tr style={{ background: '#F5F7FA' }}>
                {['ID', 'Type', 'Driver', 'Route', 'Time', 'Severity', 'Status', ''].map(h => (
                  <th key={h} style={{ padding: '9px 10px', fontSize: 11, fontWeight: 700, color: '#5B6472', letterSpacing: '0.04em', textAlign: 'left', borderBottom: '1px solid #E4E8EE' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {incidentReports.map((r, i) => (
                <tr key={i} style={{ background: 'white' }}>
                  <td style={{ padding: '10px 10px', fontSize: 11, color: '#5B6472', fontFamily: 'monospace', borderBottom: '1px solid #E4E8EE', whiteSpace: 'nowrap' }}>{r.id}</td>
                  <td style={{ padding: '10px 10px', fontSize: 12, fontWeight: 600, color: '#1D2027', borderBottom: '1px solid #E4E8EE', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.type}</td>
                  <td style={{ padding: '10px 10px', fontSize: 12, color: '#1D2027', borderBottom: '1px solid #E4E8EE', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.driver}</td>
                  <td style={{ padding: '10px 10px', fontSize: 11, color: '#5B6472', borderBottom: '1px solid #E4E8EE', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.route}</td>
                  <td style={{ padding: '10px 10px', fontSize: 11, color: '#5B6472', borderBottom: '1px solid #E4E8EE', whiteSpace: 'nowrap' }}>{r.date}</td>
                  <td style={{ padding: '10px 10px', borderBottom: '1px solid #E4E8EE' }}>
                    <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 6px', borderRadius: 6, whiteSpace: 'nowrap',
                      background: r.severity === 'high' ? 'rgba(226,61,61,0.1)' : r.severity === 'medium' ? 'rgba(244,179,51,0.12)' : 'rgba(14,158,109,0.1)',
                      color: r.severity === 'high' ? '#E23D3D' : r.severity === 'medium' ? '#B8860B' : '#0B7E57'
                    }}>{r.severity.toUpperCase()}</span>
                  </td>
                  <td style={{ padding: '10px 10px', borderBottom: '1px solid #E4E8EE' }}><StatusChip s={r.status} /></td>
                  <td style={{ padding: '10px 10px', borderBottom: '1px solid #E4E8EE' }}>
                    <button style={{ padding: '3px 8px', borderRadius: 6, background: 'rgba(31,111,178,0.08)', color: '#1F6FB2', fontSize: 11, fontWeight: 600, border: 'none', cursor: 'pointer', whiteSpace: 'nowrap' }}>View</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          </div>{/* end scroll wrapper */}
        </div>

        {/* Right column */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {/* Report types breakdown */}
          <div style={{ background: 'white', borderRadius: 16, padding: '18px 20px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
            <p style={{ fontSize: 13, fontWeight: 700, color: '#1D2027', marginBottom: 14 }}>Report Types — July</p>
            {[['Passenger Complaint', 34, '#E23D3D'], ['Breakdown', 18, '#F4B333'], ['Accident', 6, '#E23D3D'], ['Road Hazard', 22, '#1F6FB2'], ['Route Deviation', 14, '#0E9E6D']].map(([label, count, color]) => (
              <div key={label as string} style={{ marginBottom: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                  <span style={{ fontSize: 12, color: '#3D4552' }}>{label}</span>
                  <span style={{ fontSize: 12, fontWeight: 600, color: '#1D2027' }}>{count}</span>
                </div>
                <div style={{ height: 5, borderRadius: 3, background: '#E4E8EE' }}>
                  <div style={{ height: 5, borderRadius: 3, background: color as string, width: `${(count as number / 40) * 100}%` }} />
                </div>
              </div>
            ))}
          </div>

          {/* Export options */}
          <div style={{ background: 'white', borderRadius: 16, padding: '18px 20px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
            <p style={{ fontSize: 13, fontWeight: 700, color: '#1D2027', marginBottom: 12 }}>Export Reports</p>
            {[['📄', 'Full Incident Log', 'CSV'], ['📊', 'Driver Performance', 'PDF'], ['🗺️', 'Route Analytics', 'PDF'], ['💰', 'Revenue Report', 'XLSX']].map(([icon, label, fmt]) => (
              <div key={label as string} style={{ display: 'flex', alignItems: 'center', gap: 10, paddingBlock: 9, borderBottom: '1px solid #F0F2F5', cursor: 'pointer' }}>
                <span style={{ fontSize: 16 }}>{icon}</span>
                <p style={{ fontSize: 12, color: '#3D4552', flex: 1 }}>{label}</p>
                <span style={{ fontSize: 10, fontWeight: 700, background: '#E4E8EE', color: '#5B6472', borderRadius: 4, padding: '2px 6px' }}>{fmt}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}

// ── Nav items ─────────────────────────────────────────────────────────

const NAV: { id: AdminView; label: string; icon: string; badge?: number }[] = [
  { id: 'overview', label: 'Overview', icon: '📊' },
  { id: 'fleet', label: 'Fleet', icon: '🚌' },
  { id: 'drivers', label: 'Drivers', icon: '👥' },
  { id: 'analytics', label: 'Analytics', icon: '📈' },
  { id: 'fraud', label: 'Fraud', icon: '🔒', badge: 5 },
  { id: 'routes', label: 'Routes', icon: '🗺️' },
  { id: 'reports', label: 'Reports', icon: '📄' },
]

// ── Main export ───────────────────────────────────────────────────────

export default function AdminDesign() {
  const [view, setView] = useState<AdminView | 'login'>('login')

  if (view === 'login') return <LoginPanel onLogin={() => setView('overview')} />

  function renderPanel() {
    if (view === 'overview') return <OverviewPanel />
    if (view === 'fleet') return <FleetPanel />
    if (view === 'drivers') return <DriversPanel />
    if (view === 'analytics') return <AnalyticsPanel />
    if (view === 'fraud') return <FraudPanel />
    if (view === 'routes') return <DemandPanel />
    if (view === 'reports') return <ReportsPanel />
    return null
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: '#F5F7FA' }}>
      {/* Sidebar */}
      <aside style={{ width: 240, background: '#12263B', minHeight: '100vh', display: 'flex', flexDirection: 'column', flexShrink: 0 }}>
        <div style={{ padding: '20px 20px 16px', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6 }}>
            <div style={{ background: 'white', borderRadius: 10, padding: '4px 8px', display: 'inline-flex', alignItems: 'center' }}>
              <img src={troSkyLogo} alt="TroSky" style={{ height: 28, objectFit: 'contain', display: 'block' }} />
            </div>
            <div>
              <p style={{ fontSize: 14, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)', lineHeight: 1 }}>TroSky</p>
              <p style={{ fontSize: 10, color: 'rgba(255,255,255,0.35)', letterSpacing: '0.06em', marginTop: 2 }}>ADMIN CONSOLE</p>
            </div>
          </div>
        </div>
        <nav style={{ flex: 1, padding: '4px 10px' }}>
          {NAV.map(n => (
            <button key={n.id} onClick={() => setView(n.id)} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px', borderRadius: 12, marginBottom: 2, background: view === n.id ? 'rgba(255,255,255,0.1)' : 'transparent', border: view === n.id ? '1px solid rgba(255,255,255,0.06)' : '1px solid transparent', cursor: 'pointer' }}>
              <span style={{ fontSize: 17 }}>{n.icon}</span>
              <span style={{ fontSize: 13, fontWeight: 500, color: view === n.id ? 'white' : 'rgba(255,255,255,0.5)', flex: 1, textAlign: 'left' }}>{n.label}</span>
              {n.badge && <span style={{ width: 20, height: 20, borderRadius: '50%', background: '#E23D3D', color: 'white', fontSize: 10, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{n.badge}</span>}
            </button>
          ))}
        </nav>
        <div style={{ padding: '16px 20px', borderTop: '1px solid rgba(255,255,255,0.06)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 34, height: 34, borderRadius: '50%', background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>👨🏿‍💻</div>
            <div>
              <p style={{ fontSize: 13, fontWeight: 600, color: 'white' }}>Ebo Larbi</p>
              <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.35)' }}>Super Admin</p>
            </div>
          </div>
        </div>
      </aside>

      {/* Main content */}
      <main style={{ flex: 1, padding: '32px 36px', overflowY: 'auto', minHeight: '100vh' }}>
        {renderPanel()}
      </main>
    </div>
  )
}
