import { useState, useEffect } from 'react'
import { StatusBar, HomeBar, Chip } from './Shared'
import troSkyLogo from '@/imports/WhatsApp_Image_2026-07-29_at_16.20.47.jpeg'

// ── QR Code SVG (finder-pattern accurate, data modules pseudo-random) ────────
function QRCodeSvg({ size = 160, seed = 42, color = '#12263B' }: { size?: number; seed?: number; color?: string }) {
  const n = 21
  const cs = size / n
  const dark = (r: number, c: number): boolean => {
    // Top-left finder
    if (r < 7 && c < 7) {
      if (r === 0 || r === 6 || c === 0 || c === 6) return true
      if (r >= 2 && r <= 4 && c >= 2 && c <= 4) return true
      return false
    }
    // Top-right finder
    if (r < 7 && c >= n - 7) {
      const cc = c - (n - 7)
      if (r === 0 || r === 6 || cc === 0 || cc === 6) return true
      if (r >= 2 && r <= 4 && cc >= 2 && cc <= 4) return true
      return false
    }
    // Bottom-left finder
    if (r >= n - 7 && c < 7) {
      const rr = r - (n - 7)
      if (rr === 0 || rr === 6 || c === 0 || c === 6) return true
      if (rr >= 2 && rr <= 4 && c >= 2 && c <= 4) return true
      return false
    }
    // Timing patterns
    if (r === 6 && c > 7 && c < n - 7) return c % 2 === 0
    if (c === 6 && r > 7 && r < n - 7) return r % 2 === 0
    // Data modules
    return (r * 31 + c * 17 + seed) % 5 < 2
  }
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ display: 'block' }}>
      <rect width={size} height={size} fill="white" />
      {Array.from({ length: n }, (_, r) =>
        Array.from({ length: n }, (_, c) =>
          dark(r, c) ? <rect key={`${r}-${c}`} x={c * cs} y={r * cs} width={cs} height={cs} fill={color} /> : null
        )
      )}
    </svg>
  )
}


function DriverMap({ dark = false, showRoute = false }: { dark?: boolean; showRoute?: boolean }) {
  const h = dark ? 260 : 220
  return (
    <div style={{ position: 'relative', width: '100%', height: h, overflow: 'hidden', flexShrink: 0 }}>
      <iframe
        src="https://www.openstreetmap.org/export/embed.html?bbox=-0.2200%2C5.5600%2C-0.1500%2C5.6300&layer=mapnik"
        style={{ width: '100%', height: '100%', border: 'none', pointerEvents: 'none', display: 'block',
          filter: dark ? 'invert(90%) hue-rotate(180deg) brightness(0.75) saturate(0.85)' : 'none' }}
        scrolling="no"
        title="Driver map"
      />
      {/* Overlays: route line + bus marker */}
      <svg width="100%" height="100%" viewBox={`0 0 390 ${h}`} preserveAspectRatio="xMidYMid slice"
        style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        {showRoute && (
          <path d="M195,240 Q195,190 220,160 Q250,130 310,110" stroke="#0E9E6D" strokeWidth="4" fill="none" strokeDasharray="10 5" opacity="0.95" />
        )}
        <circle cx="195" cy="110" r="22" fill="#0E9E6D" opacity="0.2" />
        <circle cx="195" cy="110" r="14" fill="#0E9E6D" />
        <text x="195" y="114" textAnchor="middle" dominantBaseline="middle" fontSize="14">🚌</text>
      </svg>
    </div>
  )
}

// ── D1: Driver Home ───────────────────────────────────────────────────

export function D1_DriverHome() {
  const [online, setOnline] = useState(true)
  const [hasPassenger, setHasPassenger] = useState(true)
  const canGoOffline = !hasPassenger
  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      <div style={{ background: 'linear-gradient(180deg, var(--navy) 0%, #1a3a5c 100%)', paddingBottom: 16, paddingLeft: 18, paddingRight: 18 }}>
        <StatusBar light />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)', marginBottom: 2 }}>Driver Dashboard</p>
            <h2 style={{ fontSize: 20, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)' }}>Akosua Boateng</h2>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, background: online ? 'rgba(14,158,109,0.2)' : 'rgba(255,255,255,0.08)', borderRadius: 20, padding: '8px 14px', border: `1px solid ${online ? 'rgba(14,158,109,0.4)' : 'rgba(255,255,255,0.1)'}` }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: online ? 'var(--green)' : '#5B6472' }} />
            <span style={{ fontSize: 13, fontWeight: 600, color: 'white' }}>{online ? 'Online' : 'Offline'}</span>
          </div>
        </div>
      </div>

      <div style={{ position: 'relative' }}>
        <DriverMap />
        <div style={{ position: 'absolute', bottom: 12, left: '50%', transform: 'translateX(-50%)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
          <button
            onClick={() => { if (!online || canGoOffline) setOnline(p => !p) }}
            style={{ padding: '12px 28px', borderRadius: 25, fontSize: 14, fontWeight: 700, fontFamily: 'var(--heading)', backdropFilter: 'blur(8px)', transition: 'all 0.2s',
              background: !online ? 'var(--green)' : canGoOffline ? 'rgba(226,61,61,0.9)' : 'rgba(90,100,114,0.85)',
              color: 'white',
              boxShadow: !online ? '0 6px 20px rgba(14,158,109,0.4)' : canGoOffline ? '0 6px 20px rgba(226,61,61,0.4)' : 'none',
              cursor: (!online || canGoOffline) ? 'pointer' : 'not-allowed',
              opacity: (online && !canGoOffline) ? 0.7 : 1,
            }}>
            {online ? 'Go Offline' : 'Go Online'}
          </button>
          {online && !canGoOffline && (
            <div style={{ background: 'rgba(18,26,38,0.82)', backdropFilter: 'blur(8px)', borderRadius: 10, padding: '4px 12px', display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ fontSize: 10 }}>🚫</span>
              <span style={{ fontSize: 10, fontWeight: 600, color: 'rgba(255,255,255,0.85)' }}>Drop off passengers first</span>
            </div>
          )}
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 14px 8px' }}>
        {/* Stats grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10, marginBottom: 14 }}>
          {[['🚌', "Today's Trips", '8'], ['💰', 'Earnings', '₵186'], ['⭐', 'Rating', '4.9']].map(([icon, label, val]) => (
            <div key={label} style={{ background: 'white', borderRadius: 16, padding: '12px 10px', textAlign: 'center', boxShadow: '0 2px 10px rgba(0,0,0,0.05)' }}>
              <span style={{ fontSize: 20, display: 'block', marginBottom: 4 }}>{icon}</span>
              <p style={{ fontSize: 16, fontWeight: 800, color: 'var(--ink)', fontFamily: 'var(--heading)', marginBottom: 1 }}>{val}</p>
              <p style={{ fontSize: 10, color: 'var(--txt-2)' }}>{label}</p>
            </div>
          ))}
        </div>

        {online && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {hasPassenger ? (
              /* ── Trip active: QR boarding mode, no new requests ── */
              <>
                <div style={{ background: 'rgba(14,158,109,0.07)', borderRadius: 14, padding: '10px 14px', border: '1.5px solid rgba(14,158,109,0.2)', display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--green)' }} />
                  <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--green)', flex: 1 }}>3 passengers on board · Madina → Circle</span>
                  <button onClick={() => setHasPassenger(false)} style={{ fontSize: 10, fontWeight: 700, color: 'white', background: 'var(--green)', border: 'none', borderRadius: 8, padding: '4px 10px', cursor: 'pointer' }}>Drop Off</button>
                </div>
                {/* QR boarding card — replaces ride request while trip is active */}
                <div style={{ background: 'white', borderRadius: 18, padding: '16px', border: '1.5px solid rgba(31,111,178,0.25)', boxShadow: '0 4px 20px rgba(31,111,178,0.08)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                    <div style={{ width: 40, height: 40, borderRadius: 12, background: 'rgba(31,111,178,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>📲</div>
                    <div>
                      <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>QR Boarding Active</p>
                      <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>New passengers scan your QR code to board</p>
                    </div>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'center', padding: '4px 0 8px' }}>
                    <div style={{ borderRadius: 12, overflow: 'hidden', border: '3px solid rgba(14,158,109,0.2)', padding: 6, background: 'white' }}>
                      <QRCodeSvg size={96} seed={7} />
                    </div>
                  </div>
                  <p style={{ fontSize: 10, color: 'var(--txt-2)', textAlign: 'center' }}>Trip ID: TSKY-2026-8431 · Show to boarding passengers</p>
                </div>
              </>
            ) : (
              /* ── No active trip: show incoming ride request ── */
              <div onClick={() => setHasPassenger(true)} style={{ background: 'white', borderRadius: 18, padding: '14px 16px', border: '1.5px solid rgba(14,158,109,0.25)', boxShadow: '0 4px 20px rgba(14,158,109,0.1)', display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer' }}>
                <div style={{ width: 44, height: 44, borderRadius: 14, background: 'rgba(14,158,109,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>📍</div>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
                    <div style={{ width: 7, height: 7, borderRadius: '50%', background: 'var(--green)' }} />
                    <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>New Ride Request</span>
                  </div>
                  <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>Madina → Circle · 3 passengers boarding</p>
                </div>
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M7 4l6 6-6 6" stroke="#C0C8D2" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Tab bar */}
      <div style={{ display: 'flex', background: 'white', borderTop: '1px solid var(--border)', height: 60 }}>
        {[['🏠','Home',true],['🗺️','Trips',false],['💰','Earnings',false],['👤','Profile',false]].map(([icon, label, active]) => (
          <div key={label as string} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2 }}>
            <span style={{ fontSize: 18 }}>{icon as string}</span>
            <span style={{ fontSize: 10, fontWeight: 500, color: active ? 'var(--green)' : 'var(--txt-2)' }}>{label as string}</span>
            {active && <div style={{ width: 16, height: 3, borderRadius: 2, background: 'var(--green)' }} />}
          </div>
        ))}
      </div>
      <HomeBar />
    </div>
  )
}

// ── D2: Ride Request → QR Boarding (once accepted, no more requests) ──────────

export function D2_RideRequest() {
  const [count, setCount] = useState(22)
  const [pax, setPax] = useState(4)
  const [accepted, setAccepted] = useState(false)
  const [boarded, setBoarded] = useState(3)

  useEffect(() => {
    if (accepted) return
    const t = setInterval(() => {
      setCount(c => Math.max(0, c - 1))
      if (pax < 8) setPax(p => p + 1)
    }, 1000)
    return () => clearInterval(t)
  }, [accepted, pax])

  // Simulate passengers scanning QR after acceptance
  useEffect(() => {
    if (!accepted) return
    const t = setInterval(() => {
      setBoarded(b => Math.min(14, b + 1))
    }, 2200)
    return () => clearInterval(t)
  }, [accepted])

  const boardedNames = ['Kwame A.', 'Ama O.', 'Yaw K.', 'Efua T.', 'Kofi O.', 'Abena M.', 'Sena D.', 'Nana B.', 'Akua F.', 'Kojo P.', 'Adwoa R.', 'Kwesi T.', 'Maame Y.', 'Fiifi G.']

  if (accepted) {
    return (
      <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
        <div style={{ background: 'linear-gradient(180deg, #0B7E57 0%, var(--green) 100%)', paddingBottom: 16, paddingLeft: 18, paddingRight: 18 }}>
          <StatusBar light />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div>
              <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.6)', marginBottom: 2 }}>Trip Accepted · Madina → Circle</p>
              <h2 style={{ fontSize: 19, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Show QR to Passengers</h2>
            </div>
            <div style={{ background: 'rgba(255,255,255,0.15)', borderRadius: 14, padding: '8px 12px', textAlign: 'center' }}>
              <p style={{ fontSize: 22, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)', lineHeight: 1 }}>{boarded}</p>
              <p style={{ fontSize: 9, color: 'rgba(255,255,255,0.7)' }}>BOARDED</p>
            </div>
          </div>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 8px', display: 'flex', flexDirection: 'column', gap: 14 }}>
          {/* Driver QR code */}
          <div style={{ background: 'white', borderRadius: 22, padding: '20px 20px 16px', boxShadow: '0 6px 24px rgba(0,0,0,0.08)', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <p style={{ fontSize: 12, color: 'var(--txt-2)', marginBottom: 2 }}>Your Boarding QR Code</p>
            <p style={{ fontSize: 11, color: '#0E9E6D', fontWeight: 600, marginBottom: 14 }}>Passengers scan this to board</p>
            <div style={{ borderRadius: 16, overflow: 'hidden', border: '4px solid rgba(14,158,109,0.18)', padding: 8, background: 'white', boxShadow: '0 2px 12px rgba(14,158,109,0.12)' }}>
              <QRCodeSvg size={148} seed={31} color="#12263B" />
            </div>
            <div style={{ marginTop: 12, background: 'rgba(14,158,109,0.07)', borderRadius: 10, padding: '7px 18px', textAlign: 'center' }}>
              <p style={{ fontSize: 11, fontWeight: 700, color: '#0B7E57', fontFamily: 'monospace', letterSpacing: '0.05em' }}>TSKY-2026-8431</p>
            </div>
          </div>

          {/* No new requests notice */}
          <div style={{ background: 'rgba(31,111,178,0.06)', border: '1px solid rgba(31,111,178,0.2)', borderRadius: 14, padding: '11px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ fontSize: 16 }}>🔒</span>
            <p style={{ fontSize: 12, color: '#1F6FB2', fontWeight: 500, lineHeight: 1.4 }}>No new ride requests while a trip is active. Passengers board by scanning your QR code.</p>
          </div>

          {/* Live boarding list */}
          <div style={{ background: 'white', borderRadius: 18, padding: '14px 14px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>Boarded Passengers</p>
              <Chip color="green" label={`${boarded} / 14`} />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
              {boardedNames.slice(0, boarded).map((name, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, paddingTop: 8, paddingBottom: 8, borderTop: i > 0 ? '1px solid var(--border)' : 'none', animation: i === boarded - 1 ? 'none' : undefined }}>
                  <div style={{ width: 28, height: 28, borderRadius: '50%', background: 'linear-gradient(135deg,#0E9E6D,#1F6FB2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: 11, fontWeight: 700, flexShrink: 0 }}>{name[0]}</div>
                  <p style={{ flex: 1, fontSize: 12, fontWeight: 500, color: 'var(--txt)' }}>{name}</p>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                    <span style={{ fontSize: 10, color: '#0B7E57', fontWeight: 600 }}>Scanned QR</span>
                    <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><circle cx="7" cy="7" r="6" fill="#0E9E6D"/><path d="M4 7l2 2 4-3" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <button style={{ width: '100%', height: 52, borderRadius: 16, background: 'var(--navy)', border: 'none', color: 'white', fontSize: 14, fontWeight: 700, fontFamily: 'var(--heading)' }}>
            Start Trip ({boarded} on board)
          </button>
        </div>
        <HomeBar />
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      <div style={{ background: 'var(--navy)', paddingBottom: 14, paddingLeft: 18, paddingRight: 18 }}>
        <StatusBar light />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <h2 style={{ fontSize: 18, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)' }}>Incoming Request</h2>
          <div style={{ width: 52, height: 52, borderRadius: '50%', background: count > 10 ? 'var(--amber)' : 'var(--red)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 16px rgba(0,0,0,0.3)' }}>
            <span style={{ fontSize: 20, fontWeight: 800, color: 'var(--ink)', fontFamily: 'var(--heading)' }}>{count}</span>
          </div>
        </div>
      </div>

      <DriverMap />

      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 14px' }}>
        <div style={{ background: 'white', borderRadius: 20, padding: '16px 18px', boxShadow: '0 4px 20px rgba(0,0,0,0.08)', marginBottom: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', paddingBottom: 14, borderBottom: '1px solid var(--border)', marginBottom: 14 }}>
            <div>
              <p style={{ fontSize: 11, color: 'var(--txt-2)', marginBottom: 2 }}>Route</p>
              <p style={{ fontSize: 18, fontWeight: 800, color: 'var(--ink)', fontFamily: 'var(--heading)' }}>Madina → Circle</p>
              <p style={{ fontSize: 12, color: 'var(--txt-2)', marginTop: 2 }}>14.2 km · Est. 52 min</p>
            </div>
            <div style={{ textAlign: 'right' }}>
              <p style={{ fontSize: 11, color: 'var(--txt-2)', marginBottom: 2 }}>Estimated earning</p>
              <p style={{ fontSize: 24, fontWeight: 800, color: 'var(--green)', fontFamily: 'var(--heading)' }}>₵28.50</p>
            </div>
          </div>

          {/* Passenger fill indicator */}
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
              <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>Passengers boarding</span>
              <Chip color="green" label={`${pax} / 14`} />
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {Array.from({ length: 14 }, (_, i) => (
                <div key={i} style={{ width: 30, height: 30, borderRadius: '50%', background: i < pax ? 'var(--green)' : 'var(--border)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, transition: 'background 0.3s' }}>
                  {i < pax ? '👤' : ''}
                </div>
              ))}
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 10 }}>
          <button style={{ flex: 1, height: 52, borderRadius: 26, background: 'rgba(226,61,61,0.08)', color: 'var(--red)', fontSize: 14, fontWeight: 700, border: '1.5px solid rgba(226,61,61,0.25)' }}>Decline</button>
          <button onClick={() => setAccepted(true)} style={{ flex: 2, height: 52, borderRadius: 26, background: 'var(--green)', color: 'white', fontSize: 14, fontWeight: 700, fontFamily: 'var(--heading)', boxShadow: '0 6px 20px rgba(14,158,109,0.35)', cursor: 'pointer', border: 'none' }}>Accept Trip</button>
        </div>
      </div>
      <HomeBar />
    </div>
  )
}

// ── D3: Active Route ──────────────────────────────────────────────────

export function D3_ActiveRoute() {
  const manifest = [
    { name: 'Kwame A.', seat: 4, pickup: 'Madina Jct', drop: 'Circle', boarded: true },
    { name: 'Abena M.', seat: 7, pickup: 'Shiashie', drop: 'Circle', boarded: false },
    { name: 'Yaw K.', seat: 2, pickup: 'Madina Jct', drop: 'Airport', boarded: true },
    { name: 'Efua T.', seat: 11, pickup: 'East Legon', drop: 'Circle', boarded: false },
    { name: 'Kofi O.', seat: 5, pickup: 'Madina Jct', drop: 'Osu', boarded: true },
  ]
  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      <div style={{ background: 'var(--navy)', paddingBottom: 14, paddingLeft: 18, paddingRight: 18 }}>
        <StatusBar light />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <h2 style={{ fontSize: 17, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)' }}>Active Route</h2>
            <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)' }}>Madina → Circle · 5 passengers</p>
          </div>
          <button style={{ padding: '8px 14px', borderRadius: 20, background: 'var(--amber)', color: 'var(--ink)', fontSize: 12, fontWeight: 700 }}>
            📷 Scan QR
          </button>
        </div>
      </div>

      <div style={{ position: 'relative', height: 180, overflow: 'hidden', flexShrink: 0 }}>
        <DriverMap dark={false} showRoute />
        <div style={{ position: 'absolute', top: 10, right: 10, background: 'rgba(18,26,38,0.9)', borderRadius: 10, padding: '6px 12px', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.06)' }}>
          <span style={{ fontSize: 12, fontWeight: 600, color: 'white' }}>ETA 08:05</span>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: 12, position: 'relative', zIndex: 1 }}>
        <div style={{ background: 'white', borderRadius: 20, padding: '12px 12px', boxShadow: '0 2px 12px rgba(0,0,0,0.06)' }}>
          <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)', marginBottom: 10, paddingLeft: 2 }}>Passenger Manifest</p>
          {manifest.map((p, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, paddingTop: 9, paddingBottom: 9, borderTop: i > 0 ? '1px solid var(--border)' : 'none' }}>
              <div style={{ width: 30, height: 30, borderRadius: '50%', background: p.boarded ? 'rgba(14,158,109,0.1)' : 'rgba(244,179,51,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, flexShrink: 0 }}>👤</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ fontSize: 12, fontWeight: 600, color: 'var(--txt)', lineHeight: 1.4 }}>{p.name}</p>
                <p style={{ fontSize: 10, color: 'var(--txt-2)', lineHeight: 1.4 }}>Seat {p.seat} · {p.pickup} → {p.drop}</p>
              </div>
              <div style={{ flexShrink: 0 }}><Chip color={p.boarded ? 'green' : 'amber'} label={p.boarded ? '✓ Boarded' : '⏳ Waiting'} /></div>
            </div>
          ))}
        </div>

        <div style={{ display: 'flex', gap: 10 }}>
          <button style={{ flex: 1, height: 50, borderRadius: 25, background: 'rgba(14,158,109,0.08)', color: 'var(--green)', fontSize: 13, fontWeight: 700, border: '1.5px solid rgba(14,158,109,0.25)' }}>Start Trip</button>
          <button style={{ flex: 1, height: 50, borderRadius: 25, background: 'var(--green)', color: 'white', fontSize: 13, fontWeight: 700, fontFamily: 'var(--heading)', boxShadow: '0 4px 16px rgba(14,158,109,0.3)' }}>Complete Trip</button>
        </div>
      </div>
      <HomeBar />
    </div>
  )
}

// ── D4: Earnings ──────────────────────────────────────────────────────

export function D4_Earnings() {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
  const vals = [186, 210, 145, 230, 195, 280, 168]
  const maxV = Math.max(...vals)

  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      <div style={{ background: 'var(--navy)', paddingBottom: 16, paddingLeft: 18, paddingRight: 18 }}>
        <StatusBar light />
        <h2 style={{ fontSize: 22, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Earnings</h2>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 14px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* Balance card */}
        <div style={{ borderRadius: 24, background: 'linear-gradient(135deg, var(--navy) 0%, #1F3A5A 60%, #1F6FB2 100%)', padding: '20px 20px', boxShadow: '0 12px 40px rgba(18,38,59,0.3)', position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -40, right: -40, width: 140, height: 140, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.06)' }} />
          <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', marginBottom: 4 }}>Available Balance</p>
          <p style={{ fontSize: 38, fontWeight: 800, color: 'var(--amber)', fontFamily: 'var(--heading)', lineHeight: 1, marginBottom: 4 }}>₵1,414.00</p>
          <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.4)', marginBottom: 16 }}>This week · Jul 25–31, 2026</p>
          <button style={{ padding: '10px 24px', borderRadius: 20, background: 'var(--green)', color: 'white', fontSize: 13, fontWeight: 700 }}>
            Withdraw to MoMo
          </button>
        </div>

        {/* Bar chart */}
        <div style={{ background: 'white', borderRadius: 20, padding: '16px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
            <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>This Week</p>
            <div style={{ display: 'flex', gap: 4, background: 'var(--bg)', borderRadius: 10, padding: 3 }}>
              {['Daily', 'Weekly'].map((f, i) => (
                <div key={f} style={{ padding: '5px 12px', borderRadius: 8, fontSize: 11, fontWeight: 600, background: i === 0 ? 'var(--navy)' : 'transparent', color: i === 0 ? 'white' : 'var(--txt-2)' }}>{f}</div>
              ))}
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, height: 110 }}>
            {days.map((d, i) => (
              <div key={d} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                <div style={{ width: '100%', borderRadius: '6px 6px 0 0', background: i === 5 ? 'var(--amber)' : i === 6 ? 'rgba(14,158,109,0.3)' : 'var(--green)', height: `${(vals[i] / maxV) * 88}px`, transition: 'all 0.4s' }} />
                <span style={{ fontSize: 10, color: 'var(--txt-2)', fontWeight: 500 }}>{d}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Trips */}
        <div style={{ background: 'white', borderRadius: 20, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)', marginBottom: 12 }}>Today — 4 trips</p>
          {[['Madina → Circle','07:15','8 pax','₵24.50'],['Circle → Osu','08:30','6 pax','₵18.00'],['Osu → Airport','09:45','4 pax','₵14.00'],['Madina → Circle','12:00','11 pax','₵34.00']].map(([r,t,p,f], i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, paddingTop: 10, paddingBottom: 10, borderTop: i > 0 ? '1px solid var(--border)' : 'none' }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: 'rgba(14,158,109,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>🚌</div>
              <div style={{ flex: 1 }}>
                <p style={{ fontSize: 13, fontWeight: 500, color: 'var(--txt)' }}>{r}</p>
                <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>{t} · {p}</p>
              </div>
              <div style={{ textAlign: 'right' }}>
                <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)' }}>{f}</p>
                <Chip color="green" label="Paid" />
              </div>
            </div>
          ))}
        </div>
      </div>
      <HomeBar />
    </div>
  )
}

// ── D5: Driver Profile / Verification ─────────────────────────────────

export function D5_DriverProfile() {
  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      <div style={{ background: 'linear-gradient(160deg, var(--navy) 0%, #1F3A5A 100%)', paddingBottom: 24, paddingLeft: 18, paddingRight: 18 }}>
        <StatusBar light />
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ position: 'relative' }}>
            <div style={{ width: 64, height: 64, borderRadius: '50%', background: 'rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 30, border: '2px solid rgba(255,255,255,0.2)' }}>👩🏿‍💼</div>
            <div style={{ position: 'absolute', bottom: 2, right: 2, width: 18, height: 18, borderRadius: '50%', background: 'var(--green)', border: '2px solid white', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="8" height="8" viewBox="0 0 8 8" fill="none"><path d="M1.5 4l2 2 3-3" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </div>
          </div>
          <div>
            <h2 style={{ fontSize: 19, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)', marginBottom: 2 }}>Akosua Boateng</h2>
            <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', marginBottom: 4 }}>+233 024 553 7712</p>
            <Chip color="green" label="✓ Verified Driver" />
          </div>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 14px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {/* Ratings */}
        <div style={{ background: 'white', borderRadius: 20, padding: '16px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)', marginBottom: 14 }}>Driver Ratings</p>
          <div style={{ display: 'flex', alignItems: 'center', gap: 20 }}>
            <div style={{ textAlign: 'center' }}>
              <p style={{ fontSize: 42, fontWeight: 800, color: 'var(--amber)', fontFamily: 'var(--heading)', lineHeight: 1 }}>4.9</p>
              <p style={{ fontSize: 11, color: 'var(--txt-2)', marginTop: 2 }}>Overall</p>
            </div>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
              {[['Safety', 4.9], ['Cleanliness', 4.8], ['Professionalism', 5.0]].map(([k, v]) => (
                <div key={k as string} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontSize: 12, color: 'var(--txt-2)', width: 90 }}>{k as string}</span>
                  <div style={{ flex: 1, height: 6, borderRadius: 3, background: 'var(--border)', overflow: 'hidden' }}>
                    <div style={{ height: '100%', borderRadius: 3, background: 'var(--amber)', width: `${(Number(v) / 5) * 100}%` }} />
                  </div>
                  <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--ink)', width: 28 }}>{v as number}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Documents */}
        <div style={{ background: 'white', borderRadius: 20, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)', marginBottom: 12 }}>Documents</p>
          {[["Driver's Licence", 'approved'], ["Vehicle Registration", 'approved'], ["Police Clearance", 'approved'], ["Insurance Certificate", 'pending']].map(([doc, status], i) => (
            <div key={doc} style={{ display: 'flex', alignItems: 'center', gap: 12, paddingTop: 10, paddingBottom: 10, borderTop: i > 0 ? '1px solid var(--border)' : 'none' }}>
              <span style={{ fontSize: 18 }}>📄</span>
              <span style={{ flex: 1, fontSize: 13, color: 'var(--txt)', fontWeight: 400 }}>{doc}</span>
              <Chip color={status === 'approved' ? 'green' : 'amber'} label={status === 'approved' ? '✓ Approved' : '⏳ Pending'} />
            </div>
          ))}
        </div>

        {/* Vehicle */}
        <div style={{ background: 'white', borderRadius: 20, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)', marginBottom: 12 }}>Vehicle</p>
          {[['Vehicle', 'Toyota HiAce Minibus'], ['Plate', 'GR-4821-21'], ['Capacity', '14 passengers'], ['Status', '✓ Approved']].map(([k, v], i) => (
            <div key={k} style={{ display: 'flex', justifyContent: 'space-between', paddingTop: 8, paddingBottom: 8, borderTop: i > 0 ? '1px solid var(--border)' : 'none' }}>
              <span style={{ fontSize: 13, color: 'var(--txt-2)' }}>{k}</span>
              <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--txt)' }}>{v}</span>
            </div>
          ))}
        </div>
      </div>
      <HomeBar />
    </div>
  )
}

// ── D6 · Driver QR Code Display (passengers scan this to board) ──────────────
export function D6_QRScanner() {
  const [boarded, setBoarded] = useState(5)
  const capacity = 14

  const recent = [
    { name: 'Ama Owusu', seat: '2A', time: 'just now', paid: '₵6.00' },
    { name: 'Kwame Asante', seat: '1C', time: '1 min ago', paid: '₵6.00' },
    { name: 'Efua Tetteh', seat: '3B', time: '2 min ago', paid: '₵6.00' },
  ]

  useEffect(() => {
    const t = setInterval(() => setBoarded(b => Math.min(capacity, b + 1)), 3000)
    return () => clearInterval(t)
  }, [])

  return (
    <div style={{ width: '100%', height: '100%', background: '#0D1420', display: 'flex', flexDirection: 'column' }}>
      <StatusBar light />

      {/* Header */}
      <div style={{ padding: '4px 20px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <p style={{ fontSize: 18, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Your Boarding QR</p>
          <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)', marginTop: 2 }}>Madina → Circle · 08:30 AM</p>
        </div>
        <div style={{ background: 'rgba(14,158,109,0.2)', border: '1px solid rgba(14,158,109,0.35)', borderRadius: 12, padding: '8px 12px', textAlign: 'center' }}>
          <p style={{ fontSize: 20, fontWeight: 800, color: '#0E9E6D', fontFamily: 'var(--heading)', lineHeight: 1 }}>{boarded}/{capacity}</p>
          <p style={{ fontSize: 9, color: 'rgba(255,255,255,0.5)', marginTop: 1 }}>ON BOARD</p>
        </div>
      </div>

      {/* QR Code panel */}
      <div style={{ margin: '0 20px', background: 'white', borderRadius: 22, padding: '18px', display: 'flex', flexDirection: 'column', alignItems: 'center', position: 'relative', overflow: 'hidden' }}>
        {/* Pulse ring */}
        <div style={{ position: 'absolute', inset: 0, borderRadius: 22, border: '2px solid rgba(14,158,109,0.3)', pointerEvents: 'none' }} />
        <p style={{ fontSize: 11, color: '#A0AAB4', marginBottom: 10, fontWeight: 600, letterSpacing: '0.04em' }}>SHOW THIS TO BOARDING PASSENGERS</p>
        <div style={{ borderRadius: 14, overflow: 'hidden', border: '3px solid rgba(14,158,109,0.25)', padding: 6 }}>
          <QRCodeSvg size={152} seed={31} color="#12263B" />
        </div>
        <div style={{ marginTop: 12, background: '#F0F7F4', borderRadius: 8, padding: '6px 16px' }}>
          <p style={{ fontSize: 12, fontWeight: 700, color: '#0B7E57', fontFamily: 'monospace', letterSpacing: '0.1em' }}>TSKY-2026-8431</p>
        </div>
        <p style={{ fontSize: 10, color: '#A0AAB4', marginTop: 6, textAlign: 'center' }}>Passengers scan this to confirm boarding · Trip refreshes after completion</p>
      </div>

      {/* Stats */}
      <div style={{ margin: '12px 20px 0', display: 'flex', gap: 8 }}>
        {[['Boarded', boarded, '#0E9E6D'], ['Waiting', capacity - boarded, '#F4B333'], ['Capacity', capacity, 'rgba(255,255,255,0.6)']].map(([l, v, c]) => (
          <div key={l as string} style={{ flex: 1, background: 'rgba(255,255,255,0.06)', borderRadius: 12, padding: '10px 8px', textAlign: 'center' }}>
            <p style={{ fontSize: 20, fontWeight: 800, color: c as string, fontFamily: 'var(--heading)', lineHeight: 1 }}>{v as number}</p>
            <p style={{ fontSize: 9, color: 'rgba(255,255,255,0.4)', marginTop: 3 }}>{l as string}</p>
          </div>
        ))}
      </div>

      {/* Live boarding feed */}
      <div style={{ margin: '12px 20px 0', flex: 1, overflow: 'hidden' }}>
        <p style={{ fontSize: 10, fontWeight: 700, color: 'rgba(255,255,255,0.35)', letterSpacing: '0.07em', marginBottom: 8 }}>RECENTLY BOARDED</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {recent.map((p, i) => (
            <div key={i} style={{ background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(14,158,109,0.15)', borderRadius: 12, padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 34, height: 34, borderRadius: '50%', background: 'linear-gradient(135deg,#0E9E6D,#1F6FB2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: 13, fontWeight: 700, flexShrink: 0 }}>{p.name[0]}</div>
              <div style={{ flex: 1 }}>
                <p style={{ fontSize: 12, fontWeight: 600, color: 'white' }}>{p.name} · Seat {p.seat}</p>
                <p style={{ fontSize: 10, color: 'rgba(255,255,255,0.45)' }}>Scanned QR · {p.time} · {p.paid}</p>
              </div>
              <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="9" r="8" fill="#0E9E6D" opacity="0.9"/><path d="M5 9l2.5 2.5L13 6.5" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </div>
          ))}
        </div>
      </div>

      <div style={{ padding: '10px 20px 12px', display: 'flex', gap: 10 }}>
        <button style={{ flex: 1, height: 48, borderRadius: 14, background: 'rgba(255,255,255,0.08)', border: '1px solid rgba(255,255,255,0.12)', color: 'rgba(255,255,255,0.8)', fontSize: 13, fontWeight: 600 }}>
          Manual Entry
        </button>
        <button style={{ flex: 2, height: 48, borderRadius: 14, background: '#F4B333', border: 'none', color: '#12263B', fontSize: 13, fontWeight: 700, fontFamily: 'var(--heading)' }}>
          Start Trip ({boarded} boarded)
        </button>
      </div>
      <HomeBar light />
    </div>
  )
}

// ── D7 · Payment Receipt ─────────────────────────────────────────────────
export function D7_PaymentReceipt() {
  const payments = [
    { name: 'Kofi Mensah', seat: '4B', amount: '₵6.00', method: 'Wallet', time: '08:31' },
    { name: 'Ama Owusu', seat: '2A', amount: '₵6.00', method: 'MoMo', time: '08:32' },
    { name: 'Kwame Asante', seat: '1C', amount: '₵6.00', method: 'Card', time: '08:33' },
  ]
  return (
    <div style={{ width: '100%', height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ background: 'linear-gradient(160deg,#0B7E57,#0E9E6D)', paddingBottom: 24 }}>
        <StatusBar light />
        <div style={{ padding: '0 20px' }}>
          <p style={{ fontSize: 20, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)', marginBottom: 2 }}>Payment Receipts</p>
          <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.7)' }}>Madina → Circle · Today 08:30</p>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 24px' }}>
        {/* Today's earnings */}
        <div style={{ background: 'white', borderRadius: 20, padding: '18px', marginTop: -16, boxShadow: '0 8px 24px rgba(0,0,0,0.08)', marginBottom: 16 }}>
          <p style={{ fontSize: 12, color: 'var(--txt-2)', marginBottom: 4 }}>This Trip Collected</p>
          <p style={{ fontSize: 34, fontWeight: 800, color: 'var(--green)', fontFamily: 'var(--heading)', marginBottom: 12 }}>₵48.00</p>
          <div style={{ display: 'flex', gap: 16 }}>
            {[['8', 'Passengers'], ['₵6.00', 'Per Seat'], ['100%', 'Paid']].map(([v, l]) => (
              <div key={l}>
                <p style={{ fontSize: 15, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>{v}</p>
                <p style={{ fontSize: 10, color: 'var(--txt-2)' }}>{l}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Payment method breakdown */}
        <div style={{ background: 'white', borderRadius: 16, padding: '14px 16px', marginBottom: 14 }}>
          <p style={{ fontSize: 12, fontWeight: 700, color: 'var(--txt-2)', marginBottom: 12 }}>PAYMENT METHODS</p>
          {[['Mobile Money', '5 passengers', '₵30.00','#F4B333'],['TroSky Wallet', '2 passengers', '₵12.00','#1F6FB2'],['Debit Card', '1 passenger', '₵6.00','#0E9E6D']].map(([method, count, amount, color]) => (
            <div key={method} style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
              <div style={{ width: 10, height: 10, borderRadius: '50%', background: color, flexShrink: 0 }} />
              <p style={{ flex: 1, fontSize: 13, color: 'var(--txt)' }}>{method}</p>
              <p style={{ fontSize: 12, color: 'var(--txt-2)' }}>{count}</p>
              <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', width: 52, textAlign: 'right' }}>{amount}</p>
            </div>
          ))}
        </div>

        {/* Individual receipts */}
        <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 10 }}>PASSENGER RECEIPTS</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {payments.map((p, i) => (
            <div key={i} style={{ background: 'white', borderRadius: 14, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 38, height: 38, borderRadius: '50%', background: 'linear-gradient(135deg,#0E9E6D,#1F6FB2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: 'white', fontSize: 14, fontFamily: 'var(--heading)', flexShrink: 0 }}>{p.name[0]}</div>
              <div style={{ flex: 1 }}>
                <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--txt)' }}>{p.name}</p>
                <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>Seat {p.seat} · {p.method} · {p.time}</p>
              </div>
              <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--green)', fontFamily: 'var(--heading)' }}>{p.amount}</p>
            </div>
          ))}
        </div>
      </div>
      <HomeBar />
    </div>
  )
}

// ── D8 · Incident Report ─────────────────────────────────────────────────
export function D8_IncidentReport() {
  const types = [
    { icon: '🚨', label: 'Accident', color: '#E23D3D' },
    { icon: '🔧', label: 'Breakdown', color: '#F4B333' },
    { icon: '👤', label: 'Passenger Issue', color: '#1F6FB2' },
    { icon: '⚠️', label: 'Road Hazard', color: '#F4B333' },
  ]
  return (
    <div style={{ width: '100%', height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ background: 'linear-gradient(160deg,#C12B2B,#E23D3D)', paddingBottom: 20 }}>
        <StatusBar light />
        <div style={{ padding: '0 20px' }}>
          <p style={{ fontSize: 20, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Report Incident</p>
          <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.75)', marginTop: 2 }}>Notify TroSky operations instantly</p>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 24px' }}>
        {/* Incident type */}
        <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 10 }}>INCIDENT TYPE</p>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 18 }}>
          {types.map((t, i) => (
            <button key={t.label} style={{ background: i === 1 ? `${t.color}18` : 'white', border: i === 1 ? `1.5px solid ${t.color}` : '1.5px solid var(--border)', borderRadius: 14, padding: '14px 12px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
              <span style={{ fontSize: 24 }}>{t.icon}</span>
              <p style={{ fontSize: 12, fontWeight: 600, color: i === 1 ? t.color : 'var(--txt)' }}>{t.label}</p>
            </button>
          ))}
        </div>

        {/* Location */}
        <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 8 }}>LOCATION</p>
        <div style={{ background: 'white', borderRadius: 14, padding: '12px 14px', marginBottom: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="8" r="3" stroke="#0E9E6D" strokeWidth="1.5"/><path d="M9 1a7 7 0 017 7c0 5-7 10-7 10S2 13 2 8a7 7 0 017-7z" stroke="#0E9E6D" strokeWidth="1.5"/></svg>
          <div style={{ flex: 1 }}>
            <p style={{ fontSize: 13, color: 'var(--txt)' }}>Kwame Nkrumah Ave, near Circle</p>
            <p style={{ fontSize: 10, color: 'var(--txt-2)' }}>GPS Auto-detected</p>
          </div>
          <span style={{ fontSize: 11, color: '#0E9E6D', fontWeight: 600 }}>Edit</span>
        </div>

        {/* Description */}
        <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 8 }}>DESCRIPTION</p>
        <div style={{ background: 'white', borderRadius: 14, padding: '12px 14px', marginBottom: 16, minHeight: 80, fontSize: 13, color: 'var(--txt-2)', lineHeight: 1.5 }}>
          Right front tyre burst near the Circle interchange. Passengers are safe, vehicle pulled to roadside...
        </div>

        {/* Passengers on board */}
        <div style={{ background: 'rgba(244,179,51,0.1)', border: '1px solid rgba(244,179,51,0.3)', borderRadius: 14, padding: '12px 14px', marginBottom: 16, display: 'flex', gap: 10, alignItems: 'center' }}>
          <span style={{ fontSize: 18 }}>👥</span>
          <div>
            <p style={{ fontSize: 13, fontWeight: 600, color: '#7A5F00' }}>8 Passengers On Board</p>
            <p style={{ fontSize: 11, color: '#A07A00' }}>All will be notified of the incident</p>
          </div>
        </div>

        {/* Attach photo */}
        <div style={{ background: 'white', border: '1.5px dashed var(--border)', borderRadius: 14, padding: '16px', marginBottom: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 24 }}>📷</span>
          <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--txt)' }}>Attach Photo</p>
          <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>Optional — helps operations team</p>
        </div>

        <button style={{ width: '100%', height: 52, borderRadius: 16, background: '#E23D3D', border: 'none', color: 'white', fontSize: 15, fontWeight: 700, fontFamily: 'var(--heading)' }}>
          Submit Report
        </button>
      </div>
      <HomeBar />
    </div>
  )
}

// ── D9 · Withdrawal ──────────────────────────────────────────────────────
export function D9_Withdrawal() {
  const history = [
    { date: 'Today, 06:00', amount: '₵200.00', status: 'Completed', method: 'MTN MoMo' },
    { date: 'Yesterday', amount: '₵350.00', status: 'Completed', method: 'MTN MoMo' },
    { date: 'Sat, Jul 26', amount: '₵150.00', status: 'Completed', method: 'Vodafone Cash' },
  ]
  return (
    <div style={{ width: '100%', height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ background: 'linear-gradient(160deg,#12263B,#1D3A5B)', paddingBottom: 24 }}>
        <StatusBar light />
        <div style={{ padding: '0 20px' }}>
          <p style={{ fontSize: 20, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Withdraw Earnings</p>
          <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.6)', marginTop: 2 }}>Transfer to Mobile Money</p>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 24px' }}>
        {/* Balance card */}
        <div style={{ background: 'linear-gradient(135deg,#F4B333,#E8920A)', borderRadius: 20, padding: '20px', marginTop: -16, boxShadow: '0 8px 24px rgba(244,179,51,0.35)', marginBottom: 18 }}>
          <p style={{ fontSize: 12, color: 'rgba(18,38,59,0.7)', marginBottom: 4 }}>Available Balance</p>
          <p style={{ fontSize: 38, fontWeight: 800, color: '#12263B', fontFamily: 'var(--heading)', marginBottom: 12 }}>₵1,414.50</p>
          <div style={{ display: 'flex', gap: 20 }}>
            {[['₵280.00', "Today's Earnings"], ['₵700.00', 'This Week']].map(([v, l]) => (
              <div key={l}>
                <p style={{ fontSize: 14, fontWeight: 700, color: '#12263B', fontFamily: 'var(--heading)' }}>{v}</p>
                <p style={{ fontSize: 10, color: 'rgba(18,38,59,0.6)' }}>{l}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Amount input */}
        <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 8 }}>WITHDRAWAL AMOUNT</p>
        <div style={{ background: 'white', borderRadius: 16, padding: '14px 16px', marginBottom: 14, display: 'flex', alignItems: 'center', gap: 8 }}>
          <p style={{ fontSize: 24, fontWeight: 800, color: 'var(--green)', fontFamily: 'var(--heading)' }}>₵</p>
          <p style={{ fontSize: 24, fontWeight: 800, color: 'var(--txt)', fontFamily: 'var(--heading)', flex: 1 }}>500.00</p>
          <button style={{ background: 'var(--bg)', border: 'none', borderRadius: 8, padding: '4px 10px', fontSize: 11, fontWeight: 600, color: 'var(--txt-2)' }}>Max</button>
        </div>

        {/* Quick amounts */}
        <div style={{ display: 'flex', gap: 8, marginBottom: 18 }}>
          {['₵100', '₵200', '₵500', '₵1000'].map((a, i) => (
            <button key={a} style={{ flex: 1, padding: '8px 0', borderRadius: 10, border: '1.5px solid', borderColor: i === 2 ? '#0E9E6D' : 'var(--border)', background: i === 2 ? 'rgba(14,158,109,0.08)' : 'white', fontSize: 12, fontWeight: 600, color: i === 2 ? '#0E9E6D' : 'var(--txt-2)' }}>{a}</button>
          ))}
        </div>

        {/* MoMo number */}
        <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 8 }}>MOBILE MONEY NUMBER</p>
        <div style={{ background: 'white', borderRadius: 14, padding: '13px 14px', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 32, height: 32, borderRadius: 8, background: '#FFCC00', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, fontWeight: 800, color: '#12263B', fontFamily: 'var(--heading)', flexShrink: 0 }}>M</div>
          <div style={{ flex: 1 }}>
            <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--txt)' }}>MTN MoMo · 055 123 4567</p>
            <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>Kweku Boateng</p>
          </div>
          <span style={{ fontSize: 11, color: '#0E9E6D', fontWeight: 600 }}>Change</span>
        </div>

        {/* Fee note */}
        <p style={{ fontSize: 11, color: 'var(--txt-2)', marginBottom: 16, paddingLeft: 4 }}>Processing fee: <span style={{ fontWeight: 600, color: 'var(--txt)' }}>₵0.00</span> · Arrives instantly</p>

        <button style={{ width: '100%', height: 52, borderRadius: 16, background: '#0E9E6D', border: 'none', color: 'white', fontSize: 15, fontWeight: 700, fontFamily: 'var(--heading)', marginBottom: 18 }}>
          Withdraw ₵500.00
        </button>

        {/* History */}
        <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 10 }}>RECENT WITHDRAWALS</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {history.map((h, i) => (
            <div key={i} style={{ background: 'white', borderRadius: 13, padding: '11px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: 'rgba(14,158,109,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M9 2v14M4 7l5-5 5 5" stroke="#0E9E6D" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
              </div>
              <div style={{ flex: 1 }}>
                <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--txt)' }}>{h.method}</p>
                <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>{h.date}</p>
              </div>
              <div style={{ textAlign: 'right' }}>
                <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--green)', fontFamily: 'var(--heading)' }}>{h.amount}</p>
                <p style={{ fontSize: 10, color: '#0B7E57' }}>{h.status}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
      <HomeBar />
    </div>
  )
}
