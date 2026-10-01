import { useState, useEffect } from 'react'
import { StatusBar, HomeBar, AcraMap, BusPin, Chip } from './Shared'
import troSkyLogo from '@/imports/WhatsApp_Image_2026-07-29_at_16.20.47.jpeg'
import troSkyLogoBright from '@/imports/Screenshot_2026-08-02_124000.png'


// ── P1–P3: Onboarding ─────────────────────────────────────────────────

function OnboardIllustration1() {
  return (
    <svg width="220" height="180" viewBox="0 0 220 180" fill="none">
      {/* Road */}
      <path d="M10,160 Q110,140 210,155" stroke="rgba(255,255,255,0.15)" strokeWidth="28" strokeLinecap="round" fill="none" />
      <path d="M10,160 Q110,140 210,155" stroke="rgba(255,255,255,0.06)" strokeWidth="34" strokeLinecap="round" fill="none" />
      {/* Dashed centre line */}
      <path d="M20,158 Q110,140 200,154" stroke="var(--amber)" strokeWidth="2" strokeDasharray="12 8" strokeLinecap="round" fill="none" />
      {/* Bus body */}
      <rect x="55" y="80" width="110" height="65" rx="10" fill="#0B7E57" />
      <rect x="62" y="87" width="96" height="45" rx="6" fill="rgba(255,255,255,0.12)" />
      {/* Windows */}
      <rect x="66" y="91" width="22" height="18" rx="3" fill="rgba(255,255,255,0.85)" />
      <rect x="94" y="91" width="22" height="18" rx="3" fill="rgba(255,255,255,0.85)" />
      <rect x="122" y="91" width="22" height="18" rx="3" fill="rgba(255,255,255,0.85)" />
      {/* Seats visible through windows */}
      <rect x="68" y="93" width="8" height="14" rx="2" fill="#0E9E6D" />
      <rect x="79" y="93" width="8" height="14" rx="2" fill="#0E9E6D" />
      <rect x="96" y="93" width="8" height="14" rx="2" fill="#F4B333" opacity="0.8" />
      <rect x="107" y="93" width="8" height="14" rx="2" fill="#0E9E6D" />
      <rect x="124" y="93" width="8" height="14" rx="2" fill="#0E9E6D" />
      <rect x="135" y="93" width="8" height="14" rx="2" fill="rgba(255,255,255,0.3)" />
      {/* Wheels */}
      <circle cx="82" cy="146" r="11" fill="#0A5E42" />
      <circle cx="82" cy="146" r="6" fill="#0B7E57" />
      <circle cx="140" cy="146" r="11" fill="#0A5E42" />
      <circle cx="140" cy="146" r="6" fill="#0B7E57" />
      {/* Seat tag on selected seat */}
      <rect x="90" y="72" width="36" height="20" rx="10" fill="var(--amber)" />
      <text x="108" y="85" textAnchor="middle" fill="#1D2027" fontSize="9" fontWeight="700" fontFamily="Inter, sans-serif">YOUR SEAT</text>
      <path d="M108,92 L108,96" stroke="var(--amber)" strokeWidth="1.5" />
      {/* Stars decoration */}
      <circle cx="30" cy="50" r="2" fill="white" opacity="0.4" />
      <circle cx="185" cy="40" r="1.5" fill="white" opacity="0.3" />
      <circle cx="200" cy="70" r="1" fill="white" opacity="0.5" />
      <circle cx="20" cy="90" r="1.5" fill="white" opacity="0.3" />
    </svg>
  )
}

function OnboardIllustration2() {
  const people = [
    { x: 30, c: '#7DD3B8' }, { x: 90, c: '#F4B333' }, { x: 150, c: '#89C4F0' }, { x: 210, c: '#C3A6F4' },
  ]
  return (
    <svg width="240" height="180" viewBox="0 0 240 180" fill="none">
      {/* Fare split lines */}
      <circle cx="120" cy="90" r="55" stroke="rgba(255,255,255,0.08)" strokeWidth="1" strokeDasharray="4 4" />
      <circle cx="120" cy="90" r="35" stroke="rgba(255,255,255,0.12)" strokeWidth="1" strokeDasharray="4 4" />
      {/* Central coin */}
      <circle cx="120" cy="90" r="20" fill="var(--amber)" />
      <text x="120" y="95" textAnchor="middle" fill="#1D2027" fontSize="16" fontWeight="800" fontFamily="Plus Jakarta Sans, sans-serif">₵</text>
      {/* People around */}
      {people.map((p, i) => {
        const angle = (i / 4) * Math.PI * 2 - Math.PI / 2
        const r = 60
        const px = 120 + Math.cos(angle) * r
        const py = 90 + Math.sin(angle) * r
        return (
          <g key={i}>
            <line x1="120" y1="90" x2={px} y2={py} stroke="rgba(255,255,255,0.1)" strokeWidth="1" strokeDasharray="3 3" />
            <circle cx={px} cy={py} r="18" fill={p.c} opacity="0.9" />
            <circle cx={px} cy={py - 5} r="6" fill="rgba(255,255,255,0.6)" />
            <ellipse cx={px} cy={py + 10} rx="10" ry="6" fill="rgba(255,255,255,0.4)" />
            {/* fare share */}
            <rect x={px - 12} y={py + 18} width="24" height="12" rx="6" fill="rgba(255,255,255,0.2)" />
            <text x={px} y={py + 27} textAnchor="middle" fill="white" fontSize="7" fontWeight="700" fontFamily="Inter, sans-serif">₵{[6, 8, 7, 6][i]}</text>
          </g>
        )
      })}
      {/* Arrow going down on price */}
      <path d="M110,58 L120,70 L130,58" fill="none" stroke="rgba(255,255,255,0.5)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      <text x="120" y="50" textAnchor="middle" fill="rgba(255,255,255,0.7)" fontSize="10" fontWeight="600" fontFamily="Inter, sans-serif">price drops</text>
    </svg>
  )
}

function OnboardIllustration3() {
  const days = ['M','T','W','T','F']
  return (
    <svg width="220" height="180" viewBox="0 0 220 180" fill="none">
      {/* Calendar card */}
      <rect x="20" y="20" width="180" height="130" rx="16" fill="rgba(255,255,255,0.1)" />
      <rect x="20" y="20" width="180" height="40" rx="16" fill="rgba(255,255,255,0.12)" />
      <text x="110" y="46" textAnchor="middle" fill="white" fontSize="13" fontWeight="700" fontFamily="Plus Jakarta Sans, sans-serif">July 2026</text>
      {/* Day headers */}
      {['Su','Mo','Tu','We','Th','Fr','Sa'].map((d, i) => (
        <text key={d} x={36 + i * 25} y={82} textAnchor="middle" fill="rgba(255,255,255,0.4)" fontSize="8" fontWeight="500" fontFamily="Inter, sans-serif">{d}</text>
      ))}
      {/* Calendar days with checkmarks */}
      {[7,8,9,10,11].map((day, i) => (
        <g key={day}>
          <circle cx={61 + i * 25} cy={108} r="11" fill={[1,2,3,4,5].includes(i+1) ? 'var(--green)' : 'rgba(255,255,255,0.08)'} />
          {[1,2,3,4,5].includes(i+1) ? (
            <path d={`M${55+i*25},108 L${59+i*25},112 L${67+i*25},104`} stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />
          ) : (
            <text x={61+i*25} y={111} textAnchor="middle" fill="rgba(255,255,255,0.3)" fontSize="8" fontFamily="Inter, sans-serif">{day}</text>
          )}
        </g>
      ))}
      {/* Route pill */}
      <rect x="35" y="125" width="150" height="20" rx="10" fill="rgba(255,255,255,0.12)" />
      <circle cx="48" cy="135" r="4" fill="var(--green)" />
      <text x="58" y="139" fill="white" fontSize="9" fontFamily="Inter, sans-serif">Madina → Circle</text>
      <text x="148" y="139" fill="var(--amber)" fontSize="8" fontWeight="600" fontFamily="Inter, sans-serif">07:15</text>
      {/* Recurring arrow */}
      <path d="M195,35 A10,10 0 0,1 205,45 A10,10 0 0,1 195,55" stroke="var(--amber)" strokeWidth="2" strokeLinecap="round" fill="none" />
      <path d="M193,33 L195,35 L197,37" stroke="var(--amber)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </svg>
  )
}

// ── Splash Screen ────────────────────────────────────────────────────────
export function Splash() {
  return (
    <div style={{ width: '100%', height: '100%', background: 'linear-gradient(160deg, #0A6E4C 0%, #0E9E6D 50%, #12B87E 100%)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', position: 'relative', overflow: 'hidden' }}>
      {/* Decorative rings */}
      <div style={{ position: 'absolute', width: 500, height: 500, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.06)', top: '50%', left: '50%', transform: 'translate(-50%,-50%)' }} />
      <div style={{ position: 'absolute', width: 380, height: 380, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.08)', top: '50%', left: '50%', transform: 'translate(-50%,-50%)' }} />
      <div style={{ position: 'absolute', width: 260, height: 260, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.1)', top: '50%', left: '50%', transform: 'translate(-50%,-50%)' }} />
      {/* Glow blob */}
      <div style={{ position: 'absolute', width: 200, height: 200, borderRadius: '50%', background: 'rgba(255,255,255,0.07)', top: '50%', left: '50%', transform: 'translate(-50%,-50%)', filter: 'blur(40px)' }} />

      {/* Logo card — white background so the bright logo shows correctly */}
      <div style={{ background: 'white', borderRadius: 32, padding: '24px 32px', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 24px 64px rgba(0,0,0,0.25)', position: 'relative', zIndex: 2 }}>
        <img
          src={troSkyLogoBright}
          alt="TroSky"
          style={{ width: 200, objectFit: 'contain', display: 'block' }}
        />
      </div>

      {/* Tagline */}
      <p style={{ marginTop: 32, fontSize: 17, fontWeight: 600, color: 'rgba(255,255,255,0.85)', fontFamily: 'var(--heading)', letterSpacing: '0.01em', position: 'relative', zIndex: 2 }}>
        Your Journey. On Time.
      </p>
      <p style={{ marginTop: 6, fontSize: 13, color: 'rgba(255,255,255,0.55)', position: 'relative', zIndex: 2 }}>
        {"Ghana's Shared Transport Platform"}
      </p>

      {/* Loading dots */}
      <div style={{ position: 'absolute', bottom: 60, display: 'flex', gap: 8, zIndex: 2 }}>
        {[1,2,3].map(i => (
          <div key={i} style={{ width: 8, height: 8, borderRadius: '50%', background: i === 1 ? 'white' : 'rgba(255,255,255,0.35)' }} />
        ))}
      </div>

      {/* Bottom decoration */}
      <div style={{ position: 'absolute', bottom: -80, left: -60, width: 220, height: 220, borderRadius: '50%', background: 'rgba(0,0,0,0.08)' }} />
      <div style={{ position: 'absolute', top: -60, right: -60, width: 180, height: 180, borderRadius: '50%', background: 'rgba(255,255,255,0.06)' }} />
    </div>
  )
}

export function P1_Onboarding1() {
  return (
    <div className="flex flex-col h-full relative overflow-hidden" style={{ background: 'linear-gradient(160deg, #0B7E57 0%, #0E9E6D 45%, #0d8a61 100%)' }}>
      {/* Decorative circles */}
      <div className="absolute" style={{ width: 300, height: 300, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.08)', top: -80, right: -80 }} />
      <div className="absolute" style={{ width: 200, height: 200, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.06)', top: -20, right: -20 }} />
      <div className="absolute" style={{ width: 180, height: 180, borderRadius: '50%', background: 'rgba(0,0,0,0.08)', bottom: -60, left: -40 }} />

      <StatusBar light />
      {/* Skip */}
      <div className="flex justify-end px-6 pb-2">
        <span style={{ fontSize: 13, fontWeight: 500, color: 'rgba(255,255,255,0.65)' }}>Skip</span>
      </div>

      {/* Illustration */}
      <div className="flex-1 flex items-center justify-center px-6">
        <div className="anim-float">
          <OnboardIllustration1 />
        </div>
      </div>

      {/* Text */}
      <div className="px-7 pb-6">
        <h2 style={{ fontSize: 26, fontWeight: 800, color: 'white', lineHeight: 1.2, fontFamily: 'var(--heading)', marginBottom: 10 }}>
          Book a Seat,<br />Not a Whole Car
        </h2>
        <p style={{ fontSize: 14, color: 'rgba(255,255,255,0.72)', lineHeight: 1.6, marginBottom: 28 }}>
          Find a shared vehicle going your way, book a single seat, and split the fare with fellow riders.
        </p>

        {/* Dots */}
        <div className="flex gap-2 mb-6">
          {[1,2,3].map(i => (
            <div key={i} style={{ width: i === 1 ? 24 : 8, height: 8, borderRadius: 4, background: i === 1 ? 'var(--amber)' : 'rgba(255,255,255,0.3)', transition: 'all 0.3s' }} />
          ))}
        </div>

        {/* CTA */}
        <button style={{ width: '100%', height: 54, borderRadius: 27, background: 'rgba(255,255,255,0.95)', color: '#0B7E57', fontSize: 16, fontWeight: 700, fontFamily: 'var(--heading)', boxShadow: '0 8px 24px rgba(0,0,0,0.2)' }}>
          Next
        </button>
      </div>
      <HomeBar light />
    </div>
  )
}

export function P2_Onboarding2() {
  return (
    <div className="flex flex-col h-full relative overflow-hidden" style={{ background: 'linear-gradient(160deg, #12263B 0%, #1a3a5c 50%, #0d1f35 100%)' }}>
      <div className="absolute" style={{ width: 280, height: 280, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.05)', top: -60, left: -60 }} />
      <div className="absolute" style={{ width: 200, height: 200, borderRadius: '50%', background: 'rgba(244,179,51,0.04)', bottom: 100, right: -60 }} />

      <StatusBar light />
      <div className="flex justify-end px-6 pb-2">
        <span style={{ fontSize: 13, fontWeight: 500, color: 'rgba(255,255,255,0.55)' }}>Skip</span>
      </div>

      <div className="flex-1 flex items-center justify-center px-6">
        <div className="anim-float" style={{ animationDelay: '0.5s' }}>
          <OnboardIllustration2 />
        </div>
      </div>

      <div className="px-7 pb-6">
        <h2 style={{ fontSize: 26, fontWeight: 800, color: 'white', lineHeight: 1.2, fontFamily: 'var(--heading)', marginBottom: 10 }}>
          Share the Ride,<br />Split the Fare
        </h2>
        <p style={{ fontSize: 14, color: 'rgba(255,255,255,0.65)', lineHeight: 1.6, marginBottom: 28 }}>
          As more passengers board, the cost splits between you, so you pay a fraction of what a private ride would cost.
        </p>
        <div className="flex gap-2 mb-6">
          {[1,2,3].map(i => (
            <div key={i} style={{ width: i === 2 ? 24 : 8, height: 8, borderRadius: 4, background: i === 2 ? 'var(--amber)' : 'rgba(255,255,255,0.25)' }} />
          ))}
        </div>
        <button style={{ width: '100%', height: 54, borderRadius: 27, background: 'var(--green)', color: 'white', fontSize: 16, fontWeight: 700, fontFamily: 'var(--heading)', boxShadow: '0 8px 24px rgba(14,158,109,0.4)' }}>
          Next
        </button>
      </div>
      <HomeBar light />
    </div>
  )
}

export function P3_Onboarding3() {
  return (
    <div className="flex flex-col h-full relative overflow-hidden" style={{ background: 'linear-gradient(160deg, #0d1f35 0%, #12263B 40%, #1a2840 100%)' }}>
      <StatusBar light />
      <div className="flex justify-end px-6 pb-2">
        <span style={{ fontSize: 13, fontWeight: 500, color: 'rgba(255,255,255,0.55)' }}>Skip</span>
      </div>
      <div className="flex-1 flex items-center justify-center px-6">
        <div className="anim-float" style={{ animationDelay: '1s' }}>
          <OnboardIllustration3 />
        </div>
      </div>
      <div className="px-7 pb-6">
        <h2 style={{ fontSize: 26, fontWeight: 800, color: 'white', lineHeight: 1.2, fontFamily: 'var(--heading)', marginBottom: 10 }}>
          Subscribe Your<br />Daily Commute
        </h2>
        <p style={{ fontSize: 14, color: 'rgba(255,255,255,0.65)', lineHeight: 1.6, marginBottom: 28 }}>
          Set up a recurring commute, your vehicle, guaranteed, every morning and evening.
        </p>
        <div className="flex gap-2 mb-6">
          {[1,2,3].map(i => (
            <div key={i} style={{ width: i === 3 ? 24 : 8, height: 8, borderRadius: 4, background: i === 3 ? 'var(--amber)' : 'rgba(255,255,255,0.25)' }} />
          ))}
        </div>
        <button style={{ width: '100%', height: 54, borderRadius: 27, background: 'var(--amber)', color: '#1D2027', fontSize: 16, fontWeight: 700, fontFamily: 'var(--heading)', boxShadow: '0 8px 24px rgba(244,179,51,0.35)' }}>
          Get Started
        </button>
      </div>
      <HomeBar light />
    </div>
  )
}

// ── P4: Sign Up ───────────────────────────────────────────────────────

export function P4_SignUp() {
  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      {/* Header */}
      <div className="px-6 pb-7" style={{ background: 'linear-gradient(160deg, #0B7E57 0%, #0E9E6D 100%)' }}>
        <StatusBar light />
        <div style={{ height: 12 }} />
        <div style={{ height: 20 }} />
        <h1 style={{ fontSize: 24, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)', lineHeight: 1.2, marginBottom: 4 }}>
          Welcome to TroSky
        </h1>
        <p style={{ fontSize: 13, color: 'rgba(255,255,255,0.7)' }}>Your journey. On time. Every time.</p>
      </div>
      {/* Wave */}
      <svg height="24" viewBox="0 0 390 24" style={{ display: 'block', marginTop: -1 }}>
        <path d="M0,0 Q195,24 390,0 L390,24 L0,24 Z" fill="var(--bg)" />
      </svg>

      <div className="flex-1 px-6 pt-2 space-y-4">
        <div>
          <p style={{ fontSize: 12, fontWeight: 600, color: 'var(--txt-2)', marginBottom: 8, letterSpacing: '0.04em' }}>PHONE NUMBER</p>
          <div style={{ height: 54, background: 'white', border: '1.5px solid var(--border)', borderRadius: 14, display: 'flex', alignItems: 'center', paddingLeft: 16, paddingRight: 16, gap: 12, boxShadow: '0 2px 8px rgba(0,0,0,0.04)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, paddingRight: 12, borderRight: '1px solid var(--border)' }}>
              <span style={{ fontSize: 18 }}>🇬🇭</span>
              <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--txt)' }}>+233</span>
              <svg width="12" height="8" viewBox="0 0 12 8"><path d="M1 1l5 5 5-5" stroke="#5B6472" strokeWidth="1.5" strokeLinecap="round" fill="none"/></svg>
            </div>
            <span style={{ fontSize: 14, color: 'var(--txt-2)' }}>XX XXX XXXX</span>
          </div>
        </div>

        <button style={{ width: '100%', height: 54, borderRadius: 27, background: 'var(--green)', color: 'white', fontSize: 15, fontWeight: 700, fontFamily: 'var(--heading)', boxShadow: '0 6px 20px rgba(14,158,109,0.35)' }}>
          Send OTP
        </button>

        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ flex: 1, height: 1, background: 'var(--border)' }} />
          <span style={{ fontSize: 12, color: 'var(--txt-2)' }}>or continue with</span>
          <div style={{ flex: 1, height: 1, background: 'var(--border)' }} />
        </div>

        <button style={{ width: '100%', height: 50, borderRadius: 14, border: '1.5px solid var(--border)', background: 'white', fontSize: 14, fontWeight: 500, color: 'var(--txt)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}><rect x="2" y="4" width="20" height="16" rx="3" stroke="currentColor" strokeWidth="2"/><path d="M2 8l10 6 10-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg> Continue with Email
        </button>

        <div style={{ background: 'rgba(14,158,109,0.07)', border: '1px solid rgba(14,158,109,0.15)', borderRadius: 12, padding: '12px 14px', display: 'flex', gap: 10 }}>
          <span style={{ fontSize: 16 }}>🪪</span>
          <p style={{ fontSize: 12, color: 'var(--txt-2)', lineHeight: 1.5, margin: 0 }}>
            Optionally verify your <strong style={{ color: 'var(--green)' }}>Ghana Card</strong> for extra trust and higher wallet limits.
          </p>
        </div>
      </div>
      <HomeBar />
    </div>
  )
}

// ── P5: Home ─────────────────────────────────────────────────────────

export function P5_Home() {
  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      {/* Header */}
      <div className="px-5" style={{ background: 'linear-gradient(180deg, var(--navy) 0%, #1a3a5c 100%)', paddingBottom: 16 }}>
        <StatusBar light />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <div>
            <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.55)', marginBottom: 2 }}>Good morning</p>
            <h2 style={{ fontSize: 20, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)' }}>Kwame Asante 👋</h2>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'rgba(255,255,255,0.1)', borderRadius: 20, padding: '6px 10px' }}>
              <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--green)' }} />
              <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.9)', fontWeight: 500 }}>Madina, Accra</span>
            </div>
            <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>🔔</div>
          </div>
        </div>
        {/* Search bar */}
        <div style={{ background: 'white', borderRadius: 14, height: 48, display: 'flex', alignItems: 'center', paddingLeft: 14, paddingRight: 14, gap: 10, boxShadow: '0 4px 16px rgba(0,0,0,0.2)' }}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <circle cx="8" cy="8" r="5.5" stroke="#5B6472" strokeWidth="1.5"/>
            <path d="M12.5 12.5l2.5 2.5" stroke="#5B6472" strokeWidth="1.5" strokeLinecap="round"/>
          </svg>
          <span style={{ fontSize: 14, color: 'var(--txt-2)', flex: 1 }}>Where are you going?</span>
          <div style={{ width: 1, height: 20, background: 'var(--border)' }} />
          <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--green)' }}>Now</span>
        </div>
      </div>

      {/* Map */}
      <div style={{ position: 'relative', height: 220 }}>
        <AcraMap height={220} />
        <svg width="390" height="220" viewBox="0 0 390 220" style={{ position: 'absolute', inset: 0 }}>
          <BusPin x={80} y={60} seats={5} />
          <BusPin x={310} y={130} seats={8} />
          <BusPin x={145} y={190} seats={2} amber />
        </svg>
        {/* SOS */}
        <button style={{ position: 'absolute', bottom: 12, right: 12, width: 44, height: 44, borderRadius: '50%', background: 'var(--red)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 16px rgba(226,61,61,0.5)', border: '2px solid rgba(255,255,255,0.3)' }}>
          <span style={{ color: 'white', fontSize: 10, fontWeight: 800, fontFamily: 'var(--heading)' }}>SOS</span>
        </button>
        {/* My location */}
        <button style={{ position: 'absolute', bottom: 64, right: 12, width: 36, height: 36, borderRadius: '50%', background: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 2px 10px rgba(0,0,0,0.15)' }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="3" fill="var(--green)"/><circle cx="8" cy="8" r="6" stroke="var(--green)" strokeWidth="1.5"/><line x1="8" y1="0" x2="8" y2="4" stroke="var(--green)" strokeWidth="1.5" strokeLinecap="round"/><line x1="8" y1="12" x2="8" y2="16" stroke="var(--green)" strokeWidth="1.5" strokeLinecap="round"/></svg>
        </button>
      </div>

      {/* Bottom sheet */}
      <div style={{ flex: 1, background: 'white', borderRadius: '20px 20px 0 0', marginTop: -8, padding: '16px 16px 8px', boxShadow: '0 -4px 20px rgba(0,0,0,0.08)', overflow: 'hidden' }}>
        <div style={{ width: 40, height: 4, borderRadius: 2, background: 'var(--border)', margin: '0 auto 14px' }} />
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
          <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>Favourite Routes</span>
          <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--blue)' }}>See all</span>
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 14 }}>
          {['Madina → Circle', 'Legon → Osu', 'Achimota → Tema', 'Kaneshie → Lapaz'].map(r => (
            <div key={r} style={{ padding: '8px 14px', background: 'var(--bg)', borderRadius: 20, fontSize: 12, fontWeight: 500, color: 'var(--txt)', border: '1px solid var(--border)' }}>{r}</div>
          ))}
        </div>
        {/* Promo */}
        <div style={{ borderRadius: 16, background: 'linear-gradient(120deg, var(--navy) 0%, #1F6FB2 100%)', padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--amber)', letterSpacing: '0.06em', marginBottom: 2 }}>NEW FEATURE</div>
            <div style={{ fontSize: 13, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)', marginBottom: 2 }}>Subscribe your commute</div>
            <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.6)' }}>Save up to 40% with a monthly plan</div>
          </div>
          <div style={{ padding: '8px 14px', background: 'var(--amber)', borderRadius: 20, fontSize: 12, fontWeight: 700, color: 'var(--ink)', whiteSpace: 'nowrap' }}>Try it</div>
        </div>
      </div>
      <HomeBar />
    </div>
  )
}

// ── P6: Trip Search Results ───────────────────────────────────────────

export function P6_SearchResults() {
  const rides = [
    { type: 'Minibus', plate: 'GR-4821', seats: 5, seatsColor: 'green' as const, depart: '07:15', eta: '08:05', priv: 38, shared: 14, save: '63%', approaching: true, distMin: 3, passed: false },
    { type: 'Saloon Car', plate: 'GR-2204', seats: 2, seatsColor: 'amber' as const, depart: '07:22', eta: '08:10', priv: 45, shared: 18, save: '60%', approaching: true, distMin: 7, passed: false },
    { type: 'Minibus', plate: 'GR-7743', seats: 9, seatsColor: 'green' as const, depart: '07:30', eta: '08:20', priv: 38, shared: 12, save: '68%', approaching: true, distMin: 12, passed: false },
    { type: 'Minibus', plate: 'GR-1190', seats: 0, seatsColor: 'gray' as const, depart: '06:58', eta: '07:48', priv: 38, shared: 0, save: '', approaching: false, distMin: 0, passed: true },
    { type: 'Saloon Car', plate: 'GR-5531', seats: 3, seatsColor: 'green' as const, depart: '07:02', eta: '07:52', priv: 45, shared: 16, save: '64%', approaching: false, distMin: 0, passed: true },
  ]
  const [showPassed, setShowPassed] = useState(false)
  const visible = showPassed ? rides : rides.filter(r => !r.passed)
  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      <div className="px-5" style={{ background: 'var(--navy)', paddingBottom: 14 }}>
        <StatusBar light />
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
          <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M11 14L6 9L11 4" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
          <div style={{ flex: 1 }}>
            <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)', marginBottom: 1 }}>Route</p>
            <p style={{ fontSize: 16, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)' }}>Madina → Circle</p>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, background: 'rgba(255,255,255,0.08)', borderRadius: 12, padding: 4 }}>
          <div style={{ flex: 1, background: 'rgba(255,255,255,0.12)', borderRadius: 8, height: 40, display: 'flex', alignItems: 'center', paddingLeft: 12, gap: 8 }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--green)' }} />
            <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.85)', fontWeight: 500 }}>Madina Junction</span>
          </div>
          <div style={{ flex: 1, height: 40, display: 'flex', alignItems: 'center', paddingLeft: 12, gap: 8 }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--amber)' }} />
            <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.6)' }}>Circle Interchange</span>
          </div>
        </div>
      </div>

      {/* Smart filter banner */}
      <div style={{ background: 'rgba(14,158,109,0.08)', borderBottom: '1px solid rgba(14,158,109,0.15)', padding: '8px 16px', display: 'flex', alignItems: 'center', gap: 8 }}>
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><circle cx="7" cy="7" r="6" stroke="#0E9E6D" strokeWidth="1.5"/><path d="M7 4v3.5l2 1.5" stroke="#0E9E6D" strokeWidth="1.5" strokeLinecap="round"/></svg>
        <span style={{ fontSize: 11, fontWeight: 600, color: '#0B7E57', flex: 1 }}>Showing vehicles still approaching your stop</span>
        <button onClick={() => setShowPassed(p => !p)} style={{ fontSize: 10, fontWeight: 700, color: showPassed ? 'var(--red)' : '#5B6472', background: 'none', border: 'none', cursor: 'pointer', whiteSpace: 'nowrap' }}>
          {showPassed ? 'Hide passed' : 'Show all'}
        </button>
      </div>

      {/* Filter pills */}
      <div style={{ display: 'flex', gap: 8, padding: '10px 16px', overflowX: 'auto', borderBottom: '1px solid var(--border)', background: 'white' }}>
        {['Now', 'Schedule', 'Cheapest', 'Fastest', 'Minibus'].map((f, i) => (
          <div key={f} style={{ padding: '6px 14px', borderRadius: 20, fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap', background: i === 0 ? 'var(--navy)' : 'var(--bg)', color: i === 0 ? 'white' : 'var(--txt-2)', border: `1px solid ${i === 0 ? 'var(--navy)' : 'var(--border)'}` }}>{f}</div>
        ))}
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 14px 20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {visible.map((r, i) => (
          <div key={r.plate} style={{ background: 'white', borderRadius: 20, boxShadow: '0 2px 12px rgba(0,0,0,0.06)', opacity: r.passed ? 0.45 : 1, border: !r.passed && i === 0 ? '1.5px solid rgba(14,158,109,0.3)' : r.passed ? '1.5px solid #E4E8EE' : '1.5px solid transparent', overflow: 'visible' }}>

            {/* Passed banner — inline, not absolute */}
            {r.passed && (
              <div style={{ background: 'rgba(226,61,61,0.07)', borderBottom: '1px solid rgba(226,61,61,0.12)', padding: '5px 16px', borderRadius: '18px 18px 0 0', display: 'flex', alignItems: 'center', gap: 6 }}>
                <svg width="10" height="10" viewBox="0 0 10 10" fill="none"><path d="M1 5h8M6 2l3 3-3 3" stroke="#E23D3D" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
                <span style={{ fontSize: 10, fontWeight: 700, color: 'var(--red)' }}>Already passed your stop — unavailable</span>
              </div>
            )}

            {/* Card body */}
            <div style={{ padding: '12px 16px 14px' }}>
              {/* Top row */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 4 }}>
                <div style={{ flex: 1, minWidth: 0, paddingRight: 8 }}>
                  <div style={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 6, marginBottom: 3 }}>
                    <span style={{ fontSize: 14, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>{r.type}</span>
                    <span style={{ fontSize: 10, color: '#A0AAB4' }}>{r.plate}</span>
                    {!r.passed && i === 0 && <span style={{ fontSize: 10, fontWeight: 700, background: 'rgba(14,158,109,0.1)', color: 'var(--green)', borderRadius: 4, padding: '2px 6px' }}>BEST MATCH</span>}
                  </div>
                  <p style={{ fontSize: 12, color: 'var(--txt-2)' }}>Departs {r.depart} · ETA {r.eta}</p>
                </div>
                <Chip color={r.passed ? 'gray' as const : r.seatsColor} label={r.passed ? 'Passed' : r.seats > 0 ? `${r.seats} seats` : 'Full'} />
              </div>

              {/* Approaching badge */}
              {!r.passed && (
                <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 6, marginBottom: 8, padding: '5px 10px', background: 'rgba(14,158,109,0.08)', borderRadius: 8 }}>
                  <svg width="10" height="10" viewBox="0 0 10 10" fill="none"><circle cx="5" cy="5" r="4" stroke="#0E9E6D" strokeWidth="1.2"/><path d="M5 2v3l1.5 1.5" stroke="#0E9E6D" strokeWidth="1.2" strokeLinecap="round"/></svg>
                  <span style={{ fontSize: 10, fontWeight: 600, color: '#0B7E57' }}>~{r.distMin} min away · approaching your stop</span>
                </div>
              )}

              {/* Fare row */}
              {r.seats > 0 && !r.passed && (
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{ fontSize: 13, color: 'var(--txt-2)', textDecoration: 'line-through' }}>₵{r.priv}</span>
                  <span style={{ fontSize: 22, fontWeight: 800, color: 'var(--ink)', fontFamily: 'var(--heading)', lineHeight: 1 }}>₵{r.shared}</span>
                  <span style={{ padding: '4px 10px', background: 'rgba(244,179,51,0.15)', borderRadius: 20, fontSize: 11, fontWeight: 700, color: '#B8860B', whiteSpace: 'nowrap' }}>Save {r.save}</span>
                </div>
              )}
            </div>
          </div>
        ))}

        {!showPassed && (
          <button onClick={() => setShowPassed(true)} style={{ height: 44, borderRadius: 16, background: 'white', border: '1.5px dashed #E4E8EE', fontSize: 12, fontWeight: 600, color: 'var(--txt-2)', boxShadow: 'none' }}>
            Show 2 vehicles that already passed your stop
          </button>
        )}
      </div>
      <HomeBar />
    </div>
  )
}

// ── P7: Seat Selection (Signature Screen) ─────────────────────────────

export function P7_SeatSelection() {
  const [selected, setSelected] = useState<number[]>([4])
  const [booked, setBooked] = useState(5)
  const [fare, setFare] = useState(14.0)
  const taken = [2, 6, 9, 11, 12]
  const toggleSeat = (seatNum: number) => setSelected(prev =>
    prev.includes(seatNum) ? prev.filter(s => s !== seatNum) : [...prev, seatNum]
  )

  useEffect(() => {
    if (booked < 12) {
      const t = setTimeout(() => {
        setBooked(p => {
          const n = p + 1
          setFare(parseFloat(Math.max(6, 44 / n).toFixed(2)))
          return n
        })
      }, 3500)
      return () => clearTimeout(t)
    }
  }, [booked])

  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      {/* Header */}
      <div style={{ background: 'linear-gradient(180deg, var(--navy) 0%, #1a3358 100%)', paddingBottom: 16 }}>
        <StatusBar light />
        <div style={{ padding: '4px 16px 0', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M11 14L6 9L11 4" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
          <div>
            <h2 style={{ fontSize: 17, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)', marginBottom: 1 }}>Choose Your Seat</h2>
            <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.55)' }}>Madina → Circle · GR-4821 · Departs 07:15</p>
          </div>
        </div>
      </div>

      {/* Booked counter */}
      <div style={{ margin: '14px 14px 0', background: 'white', borderRadius: 16, padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12, boxShadow: '0 2px 12px rgba(0,0,0,0.06)' }}>
        <div style={{ flex: 1, display: 'flex', gap: 3 }}>
          {Array.from({ length: 14 }, (_, i) => (
            <div key={i} style={{ flex: 1, height: 8, borderRadius: 4, background: i < booked ? 'var(--green)' : 'var(--border)', transition: 'background 0.4s' }} />
          ))}
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 2 }}>
          <span style={{ fontSize: 16, fontWeight: 800, color: 'var(--green)', fontFamily: 'var(--heading)' }}>{booked}</span>
          <span style={{ fontSize: 12, color: 'var(--txt-2)' }}>/14 booked</span>
        </div>
      </div>

      {/* Seat map card */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 14px' }}>
        <div style={{ background: 'white', borderRadius: 24, padding: '20px 16px', boxShadow: '0 4px 24px rgba(0,0,0,0.08)' }}>
          {/* Vehicle cab */}
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 16 }}>
            <div style={{ width: 72, height: 36, borderRadius: '20px 20px 0 0', background: 'var(--navy)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
              <span style={{ fontSize: 14 }}>🚌</span>
              <span style={{ fontSize: 10, fontWeight: 600, color: 'rgba(255,255,255,0.7)' }}>GR-4821</span>
            </div>
          </div>

          {/* Legend */}
          <div style={{ display: 'flex', justifyContent: 'center', gap: 16, marginBottom: 18 }}>
            {[['var(--green)', 'Available'], ['#D0D7DF', 'Taken'], ['var(--green-dk)', 'Selected']].map(([c, l]) => (
              <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <div style={{ width: 14, height: 14, borderRadius: 4, background: c, border: l === 'Selected' ? '2px solid var(--amber)' : 'none' }} />
                <span style={{ fontSize: 11, color: 'var(--txt-2)', fontWeight: 500 }}>{l}</span>
              </div>
            ))}
          </div>

          {/* Seats */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {[0, 1, 2].map(row => {
              const base = row * 4
              return (
                <div key={row} style={{ display: 'flex', justifyContent: 'center', gap: 8, alignItems: 'center' }}>
                  {[base, base + 1].map(si => {
                    const seatNum = si + 1
                    const isTaken = taken.includes(seatNum)
                    const isSel = selected.includes(seatNum)
                    return (
                      <button key={si} onClick={() => !isTaken && toggleSeat(seatNum)}
                        style={{ width: 56, height: 60, borderRadius: 12, background: isTaken ? '#E4E8EE' : isSel ? 'var(--green-dk)' : 'var(--green)', border: isSel ? '2.5px solid var(--amber)' : '2px solid transparent', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2, boxShadow: isSel ? '0 4px 16px rgba(11,126,87,0.4)' : 'none', transition: 'all 0.2s', cursor: isTaken ? 'not-allowed' : 'pointer', opacity: isTaken ? 0.6 : 1 }}>
                        {/* Seat headrest */}
                        <div style={{ width: 28, height: 8, borderRadius: '50% 50% 0 0', background: isTaken ? '#B0B8C2' : 'rgba(255,255,255,0.35)' }} />
                        <div style={{ width: 36, height: 28, borderRadius: 6, background: isTaken ? '#C4CDD6' : 'rgba(255,255,255,0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          {isTaken ? <span style={{ fontSize: 14 }}>👤</span> : isSel ? <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M3 8l4 4 6-7" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/></svg> : <span style={{ fontSize: 11, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)' }}>{seatNum}</span>}
                        </div>
                      </button>
                    )
                  })}
                  {/* Aisle */}
                  <div style={{ width: 20, display: 'flex', justifyContent: 'center' }}>
                    <div style={{ width: 1, height: 50, background: 'var(--border)' }} />
                  </div>
                  {[base + 2, base + 3].map(si => {
                    const seatNum = si + 1
                    const isTaken = taken.includes(seatNum)
                    const isSel = selected.includes(seatNum)
                    return (
                      <button key={si} onClick={() => !isTaken && toggleSeat(seatNum)}
                        style={{ width: 56, height: 60, borderRadius: 12, background: isTaken ? '#E4E8EE' : isSel ? 'var(--green-dk)' : 'var(--green)', border: isSel ? '2.5px solid var(--amber)' : '2px solid transparent', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2, boxShadow: isSel ? '0 4px 16px rgba(11,126,87,0.4)' : 'none', transition: 'all 0.2s', cursor: isTaken ? 'not-allowed' : 'pointer', opacity: isTaken ? 0.6 : 1 }}>
                        <div style={{ width: 28, height: 8, borderRadius: '50% 50% 0 0', background: isTaken ? '#B0B8C2' : 'rgba(255,255,255,0.35)' }} />
                        <div style={{ width: 36, height: 28, borderRadius: 6, background: isTaken ? '#C4CDD6' : 'rgba(255,255,255,0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          {isTaken ? <span style={{ fontSize: 14 }}>👤</span> : isSel ? <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M3 8l4 4 6-7" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/></svg> : <span style={{ fontSize: 11, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)' }}>{seatNum}</span>}
                        </div>
                      </button>
                    )
                  })}
                </div>
              )
            })}
            {/* Back bench — same style as regular seats */}
            <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginTop: 4 }}>
              {[13, 14].map(seatNum => {
                const isTaken = taken.includes(seatNum)
                const isSel = selected.includes(seatNum)
                return (
                  <button key={seatNum} onClick={() => !isTaken && toggleSeat(seatNum)}
                    style={{ width: 56, height: 60, borderRadius: 12, background: isTaken ? '#E4E8EE' : isSel ? 'var(--green-dk)' : 'var(--green)', border: isSel ? '2.5px solid var(--amber)' : '2px solid transparent', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2, boxShadow: isSel ? '0 4px 16px rgba(11,126,87,0.4)' : 'none', transition: 'all 0.2s', cursor: isTaken ? 'not-allowed' : 'pointer', opacity: isTaken ? 0.6 : 1 }}>
                    {/* Headrest */}
                    <div style={{ width: 28, height: 8, borderRadius: '50% 50% 0 0', background: isTaken ? '#B0B8C2' : 'rgba(255,255,255,0.35)' }} />
                    <div style={{ width: 36, height: 28, borderRadius: 6, background: isTaken ? '#C4CDD6' : 'rgba(255,255,255,0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                      {isTaken ? <span style={{ fontSize: 14 }}>👤</span> : isSel ? <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M3 8l4 4 6-7" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/></svg> : <span style={{ fontSize: 11, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)' }}>{seatNum}</span>}
                    </div>
                  </button>
                )
              })}
            </div>
          </div>
        </div>
      </div>

      {/* Fare panel */}
      <div style={{ background: 'white', margin: '0 14px 14px', borderRadius: 20, padding: '14px 18px', boxShadow: '0 -4px 20px rgba(0,0,0,0.08)' }}>

        {/* Group booking strip */}
        {selected.length > 0 && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12, padding: '8px 12px', background: 'rgba(14,158,109,0.06)', borderRadius: 12 }}>
            <span style={{ fontSize: 14 }}>👥</span>
            <div style={{ flex: 1 }}>
              <p style={{ fontSize: 11, fontWeight: 700, color: '#0B7E57' }}>
                {selected.length === 1 ? '1 seat selected' : `${selected.length} seats selected (group booking)`}
              </p>
              <p style={{ fontSize: 10, color: 'var(--txt-2)' }}>Seats: {selected.sort((a,b) => a-b).join(', ')}</p>
            </div>
            <button onClick={() => setSelected([])} style={{ fontSize: 10, fontWeight: 700, color: 'var(--red)', background: 'none', border: 'none', cursor: 'pointer' }}>Clear</button>
          </div>
        )}

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 10 }}>
          <div>
            <p style={{ fontSize: 11, color: 'var(--txt-2)', marginBottom: 2 }}>
              {selected.length > 1 ? `₵${fare.toFixed(2)} × ${selected.length} seats` : 'You pay now'}
            </p>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
              <span style={{ fontSize: 30, fontWeight: 800, color: 'var(--ink)', fontFamily: 'var(--heading)', lineHeight: 1 }}>
                ₵{(fare * Math.max(selected.length, 1)).toFixed(2)}
              </span>
              <span style={{ fontSize: 13, color: 'var(--txt-2)', textDecoration: 'line-through' }}>
                ₵{(38 * Math.max(selected.length, 1)).toFixed(2)}
              </span>
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ padding: '4px 10px', background: 'rgba(244,179,51,0.15)', borderRadius: 20, fontSize: 11, fontWeight: 700, color: '#B8860B', marginBottom: 3 }}>↓ Drops to ₵6.00</div>
            <p style={{ fontSize: 10, color: 'var(--txt-2)' }}>as more riders join</p>
          </div>
        </div>

        <button style={{ width: '100%', height: 52, borderRadius: 26, background: selected.length > 0 ? 'var(--green)' : 'var(--border)', color: selected.length > 0 ? 'white' : 'var(--txt-2)', fontSize: 14, fontWeight: 700, fontFamily: 'var(--heading)', boxShadow: selected.length > 0 ? '0 6px 20px rgba(14,158,109,0.35)' : 'none', transition: 'all 0.25s' }}>
          {selected.length === 0
            ? 'Select Seats to Continue'
            : selected.length === 1
              ? `Reserve Seat ${selected[0]}`
              : `Reserve ${selected.length} Seats · ₵${(fare * selected.length).toFixed(2)}`}
        </button>
      </div>
      <HomeBar />
    </div>
  )
}

// ── P8: Live Tracking (dark) ──────────────────────────────────────────

export function P8_LiveTracking() {
  return (
    <div className="flex flex-col h-full relative overflow-hidden" style={{ background: '#13181F' }}>
      {/* Real map background — dark filtered */}
      <iframe
        src="https://www.openstreetmap.org/export/embed.html?bbox=-0.2200%2C5.5600%2C-0.1500%2C5.6300&layer=mapnik"
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', border: 'none', pointerEvents: 'none' }}
        scrolling="no"
        title="Live tracking map"
      />
      {/* Route line, vehicle, user dot overlays */}
      <svg width="390" height="694" viewBox="0 0 390 694" style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        <path d="M250,580 Q250,480 280,420 Q310,360 310,300 Q310,250 250,220" stroke="#0E9E6D" strokeWidth="4" fill="none" strokeDasharray="10 6" opacity="0.95"/>
        <circle cx="250" cy="210" r="10" fill="#0E9E6D"/>
        <circle cx="250" cy="210" r="5" fill="white"/>
        <path d="M250,220 L250,228" stroke="#0E9E6D" strokeWidth="2"/>
        <circle cx="295" cy="360" r="28" fill="#0E9E6D" opacity="0.15"/>
        <circle cx="295" cy="360" r="18" fill="#0E9E6D"/>
        <text x="295" y="364" textAnchor="middle" dominantBaseline="middle" fontSize="16">🚌</text>
        <circle cx="250" cy="580" r="20" fill="#1F6FB2" opacity="0.2" className="anim-pulse"/>
        <circle cx="250" cy="580" r="10" fill="#1F6FB2"/>
        <circle cx="250" cy="580" r="4" fill="white"/>
        <rect x="165" y="190" width="70" height="20" rx="10" fill="rgba(14,158,109,0.85)"/>
        <text x="200" y="203" textAnchor="middle" fill="white" fontSize="9" fontWeight="600" fontFamily="Inter, sans-serif">DESTINATION</text>
      </svg>

      {/* ETA banner */}
      <div style={{ position: 'absolute', top: 48, left: 16, right: 16, zIndex: 10 }}>
        <StatusBar light />
        <div style={{ background: 'rgba(18,38,59,0.92)', backdropFilter: 'blur(12px)', borderRadius: 16, padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 10, marginTop: 8, border: '1px solid rgba(255,255,255,0.06)' }}>
          <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--amber)' }} />
          <span style={{ fontSize: 14, fontWeight: 600, color: 'white', flex: 1 }}>Arriving in ~24 min</span>
          <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)' }}>ETA 08:05</span>
        </div>
      </div>

      {/* Bottom sheet */}
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: 'rgba(18,26,38,0.97)', backdropFilter: 'blur(20px)', borderRadius: '28px 28px 0 0', padding: '20px 18px 20px', border: '1px solid rgba(255,255,255,0.06)' }}>
        <div style={{ width: 40, height: 4, borderRadius: 2, background: 'rgba(255,255,255,0.15)', margin: '0 auto 16px' }} />
        {/* Driver card */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16, paddingBottom: 16, borderBottom: '1px solid rgba(255,255,255,0.07)' }}>
          <div style={{ width: 48, height: 48, borderRadius: '50%', background: 'rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24 }}>👨🏿</div>
          <div style={{ flex: 1 }}>
            <p style={{ fontSize: 15, fontWeight: 700, color: 'white', fontFamily: 'var(--heading)', marginBottom: 2 }}>Kofi Mensah</p>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)' }}>⭐ 4.8</span>
              <span style={{ width: 3, height: 3, borderRadius: '50%', background: 'rgba(255,255,255,0.2)', display: 'inline-block' }} />
              <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)' }}>GR-4821 · Minibus</span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <div style={{ width: 38, height: 38, borderRadius: '50%', background: 'var(--green)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>📞</div>
            <div style={{ width: 38, height: 38, borderRadius: '50%', background: 'rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>💬</div>
          </div>
        </div>
        {/* Stats */}
        <div style={{ display: 'flex', gap: 10, marginBottom: 14 }}>
          {[['Live fare', '₵11.50', 'var(--amber)'], ['Riders', '7 / 14', 'white'], ['Seat', '#4', 'white']].map(([k, v, c]) => (
            <div key={k} style={{ flex: 1, background: 'rgba(255,255,255,0.06)', borderRadius: 14, padding: '10px 12px' }}>
              <p style={{ fontSize: 10, color: 'rgba(255,255,255,0.45)', marginBottom: 3 }}>{k}</p>
              <p style={{ fontSize: 16, fontWeight: 700, color: c, fontFamily: 'var(--heading)' }}>{v}</p>
            </div>
          ))}
        </div>
        {/* Actions */}
        <div style={{ display: 'flex', gap: 10 }}>
          <button style={{ flex: 1, height: 50, borderRadius: 25, background: 'rgba(255,255,255,0.08)', color: 'white', fontSize: 13, fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
            📤 Share Trip
          </button>
          <button style={{ flex: 1, height: 50, borderRadius: 25, background: 'var(--red)', color: 'white', fontSize: 13, fontWeight: 700, fontFamily: 'var(--heading)', boxShadow: '0 4px 16px rgba(226,61,61,0.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
            🚨 SOS
          </button>
        </div>
      </div>
    </div>
  )
}

// ── P9: Wallet ────────────────────────────────────────────────────────

export function P9_Wallet() {
  const txns = [
    { label: 'Madina → Circle', date: 'Today 07:15', amt: -11.5, icon: '🚌' },
    { label: 'MTN MoMo Top-up', date: 'Yesterday', amt: 50, icon: '📱' },
    { label: 'Legon → Osu', date: 'Mon Jul 28', amt: -8.0, icon: '🚌' },
    { label: 'Telecel Cash', date: 'Fri Jul 25', amt: 100, icon: '📱' },
    { label: 'Achimota → Tema', date: 'Thu Jul 24', amt: -14.5, icon: '🚌' },
  ]
  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      <div style={{ background: 'var(--navy)', paddingBottom: 16, paddingLeft: 20, paddingRight: 20 }}>
        <StatusBar light />
        <h2 style={{ fontSize: 22, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Wallet</h2>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 14px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* Balance card */}
        <div style={{ borderRadius: 24, overflow: 'hidden', boxShadow: '0 12px 40px rgba(18,38,59,0.35)' }}>
          <div style={{ background: 'linear-gradient(135deg, #12263B 0%, #1F3A5A 60%, #1F6FB2 100%)', padding: '22px 20px 20px' }}>
            {/* Card pattern */}
            <div style={{ position: 'relative' }}>
              <div style={{ position: 'absolute', top: -30, right: -30, width: 120, height: 120, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.06)' }} />
              <div style={{ position: 'absolute', top: -10, right: -10, width: 80, height: 80, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.04)' }} />
            </div>
            <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', marginBottom: 4, letterSpacing: '0.05em' }}>TROSKY WALLET</p>
            <p style={{ fontSize: 38, fontWeight: 800, color: 'var(--amber)', fontFamily: 'var(--heading)', lineHeight: 1, marginBottom: 6 }}>₵128.50</p>
            <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.4)' }}>Kwame Asante · **** 8821</p>
          </div>
          <div style={{ background: 'rgba(18,38,59,0.95)', padding: '12px 20px', display: 'flex', gap: 10 }}>
            <button style={{ flex: 1, height: 40, borderRadius: 20, background: 'var(--green)', color: 'white', fontSize: 13, fontWeight: 700, fontFamily: 'var(--heading)' }}>+ Top Up</button>
            <button style={{ flex: 1, height: 40, borderRadius: 20, background: 'rgba(255,255,255,0.08)', color: 'white', fontSize: 13, fontWeight: 600 }}>↗ Send</button>
          </div>
        </div>

        {/* Payment methods */}
        <div style={{ background: 'white', borderRadius: 20, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)', marginBottom: 12 }}>Payment Methods</p>
          {/* MTN MoMo */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, paddingTop: 10, paddingBottom: 10, borderBottom: '1px solid var(--border)' }}>
            <svg width="40" height="40" viewBox="0 0 40 40" style={{ borderRadius: 10, flexShrink: 0 }}>
              <rect width="40" height="40" rx="10" fill="#FFCC00"/>
              <text x="20" y="15" textAnchor="middle" fontSize="9" fontWeight="900" fontFamily="Arial, sans-serif" fill="#000">MTN</text>
              <text x="20" y="25" textAnchor="middle" fontSize="7" fontWeight="700" fontFamily="Arial, sans-serif" fill="#000">MoMo</text>
              <rect x="6" y="27" width="28" height="2.5" rx="1.25" fill="#000" opacity="0.15"/>
              <text x="20" y="35" textAnchor="middle" fontSize="5.5" fontWeight="600" fontFamily="Arial, sans-serif" fill="#000" opacity="0.6">Mobile Money</text>
            </svg>
            <div style={{ flex: 1 }}>
              <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--txt)' }}>MTN MoMo</p>
              <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>055 *** 8821</p>
            </div>
            <Chip color="green" label="Default" />
          </div>

          {/* Telecel Cash */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, paddingTop: 10, paddingBottom: 10, borderBottom: '1px solid var(--border)' }}>
            <svg width="40" height="40" viewBox="0 0 40 40" style={{ borderRadius: 10, flexShrink: 0 }}>
              <rect width="40" height="40" rx="10" fill="#E8001C"/>
              <circle cx="20" cy="16" r="8" fill="none" stroke="white" strokeWidth="2.5"/>
              <circle cx="20" cy="16" r="3.5" fill="white"/>
              <text x="20" y="32" textAnchor="middle" fontSize="6.5" fontWeight="800" fontFamily="Arial, sans-serif" fill="white" letterSpacing="0.5">TELECEL</text>
              <text x="20" y="39" textAnchor="middle" fontSize="5.5" fontWeight="600" fontFamily="Arial, sans-serif" fill="rgba(255,255,255,0.8)">Cash</text>
            </svg>
            <div style={{ flex: 1 }}>
              <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--txt)' }}>Telecel Cash</p>
              <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>027 *** 4411</p>
            </div>
          </div>

          {/* Visa Debit */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, paddingTop: 10, paddingBottom: 10, borderBottom: '1px solid var(--border)' }}>
            <svg width="40" height="40" viewBox="0 0 40 40" style={{ borderRadius: 10, flexShrink: 0 }}>
              <rect width="40" height="40" rx="10" fill="#1A1F71"/>
              <text x="20" y="24" textAnchor="middle" fontSize="14" fontWeight="900" fontFamily="Arial, sans-serif" fill="white" letterSpacing="-0.5">VISA</text>
            </svg>
            <div style={{ flex: 1 }}>
              <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--txt)' }}>Visa Debit</p>
              <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>**** 4412</p>
            </div>
          </div>
          <button style={{ marginTop: 10, fontSize: 13, fontWeight: 600, color: 'var(--blue)' }}>+ Add method</button>
        </div>

        {/* Transactions */}
        <div style={{ background: 'white', borderRadius: 20, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>Recent Transactions</p>
            <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--blue)' }}>See all</span>
          </div>
          {txns.map((t, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, paddingTop: 10, paddingBottom: 10, borderBottom: i < txns.length - 1 ? '1px solid var(--border)' : 'none' }}>
              <div style={{ width: 38, height: 38, borderRadius: 12, background: t.amt > 0 ? 'rgba(14,158,109,0.1)' : 'rgba(31,111,178,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>{t.icon}</div>
              <div style={{ flex: 1 }}>
                <p style={{ fontSize: 13, fontWeight: 500, color: 'var(--txt)' }}>{t.label}</p>
                <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>{t.date}</p>
              </div>
              <span style={{ fontSize: 14, fontWeight: 700, color: t.amt > 0 ? 'var(--success)' : 'var(--ink)' }}>
                {t.amt > 0 ? '+' : ''}₵{Math.abs(t.amt).toFixed(2)}
              </span>
            </div>
          ))}
        </div>
      </div>
      <HomeBar />
    </div>
  )
}

// ── P10: Subscribe ────────────────────────────────────────────────────

export function P10_Subscribe() {
  const [days, setDays] = useState(['Mon', 'Tue', 'Wed', 'Thu', 'Fri'])
  const [morningSlot, setMorningSlot] = useState('07:15')
  const [eveningSlot, setEveningSlot] = useState('17:30')
  const morningTimes = ['05:30', '06:00', '06:30', '07:00', '07:15', '07:30', '08:00', '08:30']
  const eveningTimes = ['15:30', '16:00', '16:30', '17:00', '17:30', '18:00', '18:30', '19:00']
  const toggleDay = (d: string) => setDays(prev => prev.includes(d) ? prev.filter(x => x !== d) : [...prev, d])
  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      <div style={{ background: 'var(--navy)', paddingBottom: 16, paddingLeft: 20, paddingRight: 20 }}>
        <StatusBar light />
        <h2 style={{ fontSize: 22, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)', marginBottom: 2 }}>Subscribe Commute</h2>
        <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)' }}>Guaranteed vehicle, every day</p>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 14px 20px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {/* Route */}
        <div style={{ background: 'white', borderRadius: 20, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 10 }}>ROUTE</p>
          {[['var(--green)', 'Home', 'Madina Junction, Accra'], ['var(--navy)', 'Work', 'Airport Hills, Accra']].map(([c, label, addr]) => (
            <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', background: 'var(--bg)', borderRadius: 12, marginBottom: 8, border: '1.5px solid var(--border)' }}>
              <div style={{ width: 10, height: 10, borderRadius: '50%', background: c }} />
              <div>
                <p style={{ fontSize: 10, color: 'var(--txt-2)', marginBottom: 1 }}>{label}</p>
                <p style={{ fontSize: 13, fontWeight: 500, color: 'var(--txt)' }}>{addr}</p>
              </div>
            </div>
          ))}
        </div>
        {/* Days */}
        <div style={{ background: 'white', borderRadius: 20, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 10 }}>COMMUTE DAYS</p>
          <div style={{ display: 'flex', gap: 6 }}>
            {['Mon','Tue','Wed','Thu','Fri','Sat'].map(d => (
              <button key={d} onClick={() => toggleDay(d)} style={{ flex: 1, height: 44, borderRadius: 12, background: days.includes(d) ? 'var(--navy)' : 'var(--bg)', color: days.includes(d) ? 'white' : 'var(--txt-2)', fontSize: 11, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', border: `1px solid ${days.includes(d) ? 'var(--navy)' : 'var(--border)'}`, cursor: 'pointer', transition: 'all 0.15s' }}>{d}</button>
            ))}
          </div>
        </div>

        {/* Time Slots */}
        <div style={{ background: 'white', borderRadius: 20, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 12 }}>TIME SLOTS</p>

          {/* Morning */}
          <div style={{ marginBottom: 14 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <span style={{ fontSize: 14 }}>🌅</span>
              <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--txt)' }}>Morning Departure</span>
              <span style={{ marginLeft: 'auto', fontSize: 11, fontWeight: 700, color: 'var(--navy)', background: 'rgba(18,38,59,0.08)', borderRadius: 8, padding: '2px 8px' }}>{morningSlot}</span>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {morningTimes.map(t => (
                <button key={t} onClick={() => setMorningSlot(t)} style={{ padding: '6px 10px', borderRadius: 10, fontSize: 11, fontWeight: 600, border: '1.5px solid', borderColor: morningSlot === t ? 'var(--navy)' : 'var(--border)', background: morningSlot === t ? 'var(--navy)' : 'var(--bg)', color: morningSlot === t ? 'white' : 'var(--txt-2)', cursor: 'pointer', transition: 'all 0.15s' }}>{t}</button>
              ))}
            </div>
          </div>

          {/* Divider */}
          <div style={{ height: 1, background: 'var(--border)', marginBottom: 14 }} />

          {/* Evening */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <span style={{ fontSize: 14 }}>🌆</span>
              <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--txt)' }}>Evening Return</span>
              <span style={{ marginLeft: 'auto', fontSize: 11, fontWeight: 700, color: 'var(--green)', background: 'rgba(14,158,109,0.1)', borderRadius: 8, padding: '2px 8px' }}>{eveningSlot}</span>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {eveningTimes.map(t => (
                <button key={t} onClick={() => setEveningSlot(t)} style={{ padding: '6px 10px', borderRadius: 10, fontSize: 11, fontWeight: 600, border: '1.5px solid', borderColor: eveningSlot === t ? 'var(--green)' : 'var(--border)', background: eveningSlot === t ? 'var(--green)' : 'var(--bg)', color: eveningSlot === t ? 'white' : 'var(--txt-2)', cursor: 'pointer', transition: 'all 0.15s' }}>{t}</button>
              ))}
            </div>
          </div>
        </div>
        {/* Plans */}
        <div style={{ background: 'white', borderRadius: 20, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
          <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', marginBottom: 10 }}>PLAN</p>
          {[{ id: 'weekly', label: 'Weekly', price: '₵68', save: 'Save ₵14', note: '5 days × 2 trips' }, { id: 'monthly', label: 'Monthly', price: '₵260', save: 'Save ₵72', note: '20 days × 2 trips', best: true }].map(p => (
            <div key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderRadius: 16, border: `2px solid ${p.best ? 'var(--green)' : 'var(--border)'}`, background: p.best ? 'rgba(14,158,109,0.04)' : 'white', marginBottom: 8 }}>
              <div style={{ width: 20, height: 20, borderRadius: '50%', border: `2px solid ${p.best ? 'var(--green)' : 'var(--border)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {p.best && <div style={{ width: 10, height: 10, borderRadius: '50%', background: 'var(--green)' }} />}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 1 }}>
                  <span style={{ fontSize: 14, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>{p.label}</span>
                  {p.best && <span style={{ fontSize: 9, fontWeight: 700, background: 'var(--green)', color: 'white', borderRadius: 4, padding: '1px 6px' }}>BEST VALUE</span>}
                </div>
                <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>{p.note}</p>
              </div>
              <div style={{ textAlign: 'right' }}>
                <p style={{ fontSize: 20, fontWeight: 800, color: 'var(--ink)', fontFamily: 'var(--heading)' }}>{p.price}</p>
                <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--amber)' }}>{p.save}</p>
              </div>
            </div>
          ))}
        </div>
        {/* Savings badge */}
        <div style={{ borderRadius: 16, padding: '14px 16px', background: 'rgba(244,179,51,0.1)', border: '1.5px solid rgba(244,179,51,0.25)', display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: 24 }}>🎉</span>
          <div>
            <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)', fontFamily: 'var(--heading)' }}>You save ₵72 this month</p>
            <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>vs booking each trip individually</p>
          </div>
        </div>
        <button style={{ height: 54, borderRadius: 27, background: 'var(--green)', color: 'white', fontSize: 15, fontWeight: 700, fontFamily: 'var(--heading)', boxShadow: '0 6px 20px rgba(14,158,109,0.35)' }}>
          Subscribe — ₵260/month
        </button>
      </div>
      <HomeBar />
    </div>
  )
}

// ── P11: Profile ──────────────────────────────────────────────────────

export function P11_Profile() {
  return (
    <div className="flex flex-col h-full" style={{ background: 'var(--bg)' }}>
      <div style={{ background: 'linear-gradient(160deg, var(--navy) 0%, #1F3A5A 100%)', paddingBottom: 24, paddingLeft: 20, paddingRight: 20 }}>
        <StatusBar light />
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginTop: 8 }}>
          <div style={{ position: 'relative' }}>
            <div style={{ width: 68, height: 68, borderRadius: '50%', background: 'rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 32, border: '2px solid rgba(255,255,255,0.2)' }}>👨🏿‍💼</div>
            <div style={{ position: 'absolute', bottom: 2, right: 2, width: 18, height: 18, borderRadius: '50%', background: 'var(--green)', border: '2px solid white', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="8" height="8" viewBox="0 0 8 8" fill="none"><path d="M1.5 4l2 2 3-3" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </div>
          </div>
          <div>
            <h2 style={{ fontSize: 20, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)', marginBottom: 2 }}>Kwame Asante</h2>
            <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.55)', marginBottom: 6 }}>+233 055 821 4493</p>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, background: 'rgba(244,179,51,0.2)', borderRadius: 8, padding: '4px 8px' }}>
              <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--amber)' }} />
              <span style={{ fontSize: 10, fontWeight: 700, color: 'var(--amber)' }}>Ghana Card Unverified</span>
            </div>
          </div>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 14px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {/* Verify card */}
        <div style={{ background: 'white', borderRadius: 18, padding: '12px 16px', border: '1.5px dashed var(--amber)', display: 'flex', alignItems: 'center', gap: 12, boxShadow: '0 2px 12px rgba(244,179,51,0.12)' }}>
          <span style={{ fontSize: 24 }}>🪪</span>
          <div style={{ flex: 1 }}>
            <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>Verify Ghana Card</p>
            <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>Higher limits · Extra trust badge</p>
          </div>
          <div style={{ padding: '6px 14px', borderRadius: 20, background: 'var(--amber)', fontSize: 12, fontWeight: 700, color: 'var(--ink)' }}>Verify</div>
        </div>

        {[
          { section: 'ACCOUNT', items: [['👤', 'Personal Info'], ['📍', 'Saved Addresses'], ['👥', 'Trusted Contacts']] },
          { section: 'PREFERENCES', items: [['🔔', 'Notifications'], ['🔒', 'Privacy & Security'], ['🌍', 'Language']] },
          { section: 'SUPPORT', items: [['💬', 'Help Centre'], ['⭐', 'Rate TroSky'], ['📄', 'Terms & Privacy']] },
        ].map(s => (
          <div key={s.section} style={{ background: 'white', borderRadius: 18, boxShadow: '0 2px 12px rgba(0,0,0,0.05)' }}>
            <p style={{ fontSize: 10, fontWeight: 700, color: 'var(--txt-2)', letterSpacing: '0.05em', padding: '10px 14px 6px' }}>{s.section}</p>
            {s.items.map(([icon, label], i) => (
              <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '11px 14px', borderTop: i > 0 ? '1px solid var(--border)' : 'none', boxSizing: 'border-box', width: '100%' }}>
                <span style={{ fontSize: 17, width: 22, flexShrink: 0 }}>{icon}</span>
                <span style={{ flex: 1, fontSize: 13, color: 'var(--txt)', fontWeight: 400, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{label}</span>
                <svg width="14" height="14" viewBox="0 0 14 14" fill="none" style={{ flexShrink: 0 }}><path d="M5 3l4 4-4 4" stroke="#C0C8D2" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
              </div>
            ))}
          </div>
        ))}

        <button style={{ height: 50, borderRadius: 16, background: 'rgba(226,61,61,0.06)', color: 'var(--red)', fontSize: 14, fontWeight: 600, border: '1px solid rgba(226,61,61,0.15)' }}>
          Sign Out
        </button>
      </div>
      <HomeBar />
    </div>
  )
}

// ── P12 · QR Boarding Pass ───────────────────────────────────────────────
export function P12_QRBoarding() {
  return (
    <div style={{ width: '100%', height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ background: 'linear-gradient(160deg,#12263B 0%,#1F6FB2 100%)', padding: '0 0 28px' }}>
        <StatusBar light />
        <div style={{ padding: '4px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="16" height="16" viewBox="0 0 18 18" fill="none"><path d="M11 4L6 9l5 5" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
        </div>
        <div style={{ padding: '0 20px' }}>
          <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.6)', marginBottom: 1 }}>BOARDING PASS</p>
          <p style={{ fontSize: 17, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Madina → Circle</p>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 24px' }}>
        {/* QR Card */}
        <div style={{ background: 'white', borderRadius: 24, padding: '24px 20px', marginTop: -16, boxShadow: '0 8px 32px rgba(0,0,0,0.10)', textAlign: 'center' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, background: 'rgba(14,158,109,0.1)', borderRadius: 20, padding: '4px 12px', marginBottom: 20 }}>
            <div style={{ width: 7, height: 7, borderRadius: '50%', background: '#0E9E6D' }} />
            <span style={{ fontSize: 12, fontWeight: 700, color: '#0B7E57' }}>Ready to Board</span>
          </div>

          {/* QR Code SVG */}
          <div style={{ display: 'inline-block', padding: 12, background: 'white', border: '1px solid #E8EAF0', borderRadius: 16, marginBottom: 20 }}>
            <svg width="160" height="160" viewBox="0 0 160 160">
              <rect width="160" height="160" fill="white"/>
              {/* Finder patterns */}
              <rect x="8" y="8" width="44" height="44" rx="4" fill="#12263B"/>
              <rect x="12" y="12" width="36" height="36" rx="2" fill="white"/>
              <rect x="16" y="16" width="28" height="28" rx="1" fill="#12263B"/>
              <rect x="108" y="8" width="44" height="44" rx="4" fill="#12263B"/>
              <rect x="112" y="12" width="36" height="36" rx="2" fill="white"/>
              <rect x="116" y="16" width="28" height="28" rx="1" fill="#12263B"/>
              <rect x="8" y="108" width="44" height="44" rx="4" fill="#12263B"/>
              <rect x="12" y="112" width="36" height="36" rx="2" fill="white"/>
              <rect x="16" y="116" width="28" height="28" rx="1" fill="#12263B"/>
              {/* Data modules */}
              {[60,68,76,84,92,100].map((x,i) => [60,68,76,84,92,100].map((y,j) => (i+j)%3!==0 ? <rect key={`${x}${y}`} x={x} y={y} width="6" height="6" fill="#12263B"/> : null))}
              {[60,76,92].map(x => [12,28,44].map(y => <rect key={`t${x}${y}`} x={x} y={y} width="6" height="6" fill="#12263B"/>))}
              {[12,28,44].map(x => [60,76,92].map(y => <rect key={`s${x}${y}`} x={x} y={y} width="6" height="6" fill="#12263B"/>))}
              {[116,132].map(x => [60,68,76,84].map(y => <rect key={`r${x}${y}`} x={x} y={y} width="6" height="6" fill="#12263B"/>))}
              {/* TroSky logo center */}
              <rect x="66" y="66" width="28" height="28" rx="6" fill="white"/>
              <image href={troSkyLogo} x="68" y="68" width="24" height="24" preserveAspectRatio="xMidYMid meet" clipPath="url(#qrClip)" />
              <clipPath id="qrClip"><rect x="68" y="68" width="24" height="24" rx="4"/></clipPath>
            </svg>
          </div>

          <p style={{ fontSize: 13, color: 'var(--txt-2)', marginBottom: 4 }}>Scan this code when boarding</p>
          <p style={{ fontSize: 11, color: '#C0C8D2', fontFamily: 'monospace' }}>TRO-2024-MDN-CCL-004</p>

          {/* Dashed divider */}
          <div style={{ margin: '20px 0', display: 'flex', alignItems: 'center', gap: 4 }}>
            {Array.from({ length: 28 }).map((_, i) => <div key={i} style={{ flex: 1, height: 1, background: i%2===0 ? '#E8EAF0' : 'transparent' }} />)}
          </div>

          {/* Trip details */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
            {[['Seat', '4B'], ['Departs', '08:30'], ['Fare', '₵6.00']].map(([label, value]) => (
              <div key={label}>
                <p style={{ fontSize: 10, color: 'var(--txt-2)', marginBottom: 2 }}>{label}</p>
                <p style={{ fontSize: 16, fontWeight: 800, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>{value}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Passenger info */}
        <div style={{ background: 'white', borderRadius: 16, padding: '14px 16px', marginTop: 12, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 42, height: 42, borderRadius: '50%', background: 'linear-gradient(135deg,#0E9E6D,#1F6FB2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)', flexShrink: 0 }}>K</div>
          <div style={{ flex: 1 }}>
            <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--txt)' }}>Kofi Mensah</p>
            <p style={{ fontSize: 12, color: 'var(--txt-2)' }}>Verified · Ghana Card ✓</p>
          </div>
          <div style={{ background: 'rgba(14,158,109,0.1)', borderRadius: 10, padding: '6px 10px' }}>
            <p style={{ fontSize: 11, fontWeight: 700, color: '#0B7E57' }}>PAID</p>
          </div>
        </div>

        {/* Share trip */}
        <button style={{ width: '100%', height: 50, borderRadius: 16, background: 'var(--navy)', color: 'white', fontSize: 14, fontWeight: 700, fontFamily: 'var(--heading)', marginTop: 12, border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M15 12a2 2 0 01-1.63-3.16L8.26 5.98a2 2 0 110-2.79l5.11-2.85A2 2 0 1115 4a2 2 0 01-1.63-.84L8.26 6.01a2 2 0 010 5.98l5.11 2.85A2 2 0 1115 12z" fill="white"/></svg>
          Share Live Trip
        </button>
      </div>
      <HomeBar />
    </div>
  )
}

// ── P13 · Trip History ───────────────────────────────────────────────────
export function P13_TripHistory() {
  const trips = [
    { route: 'Madina → Circle', date: 'Today, 08:30', fare: '₵6.00', status: 'Completed', seats: 1 },
    { route: 'Circle → Tema', date: 'Yesterday, 17:15', fare: '₵9.00', status: 'Completed', seats: 2 },
    { route: 'Accra Central → Kaneshie', date: 'Mon, 07:45', fare: '₵4.50', status: 'Completed', seats: 1 },
    { route: 'Madina → Circle', date: 'Sun, 08:30', fare: '₵6.00', status: 'Completed', seats: 1 },
    { route: 'Tema → Circle', date: 'Sat, 18:00', fare: '₵9.00', status: 'Cancelled', seats: 0 },
  ]
  return (
    <div style={{ width: '100%', height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ background: 'linear-gradient(160deg,#12263B,#1D3A5B)', paddingBottom: 20 }}>
        <StatusBar light />
        <div style={{ padding: '0 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <p style={{ fontSize: 20, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Trip History</p>
          <button style={{ background: 'rgba(255,255,255,0.12)', border: 'none', borderRadius: 10, padding: '6px 12px', color: 'white', fontSize: 12, fontWeight: 600 }}>Export</button>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 24px' }}>
        {/* Spending summary */}
        <div style={{ background: 'linear-gradient(135deg,#0E9E6D,#0B7E57)', borderRadius: 20, padding: '18px 20px', marginTop: -12, boxShadow: '0 8px 24px rgba(14,158,109,0.3)', color: 'white', marginBottom: 16 }}>
          <p style={{ fontSize: 12, opacity: 0.8, marginBottom: 4 }}>Total Spent This Month</p>
          <p style={{ fontSize: 32, fontWeight: 800, fontFamily: 'var(--heading)', marginBottom: 12 }}>₵128.50</p>
          <div style={{ display: 'flex', gap: 20 }}>
            {[['24', 'Trips'], ['₵5.35', 'Avg Fare'], ['₵18.20', 'Saved']].map(([v, l]) => (
              <div key={l}>
                <p style={{ fontSize: 16, fontWeight: 700, fontFamily: 'var(--heading)' }}>{v}</p>
                <p style={{ fontSize: 10, opacity: 0.7 }}>{l}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Filter tabs */}
        <div style={{ display: 'flex', gap: 8, marginBottom: 16, background: 'white', borderRadius: 14, padding: 4 }}>
          {['All', 'This Month', 'Last Month'].map((t, i) => (
            <div key={t} style={{ flex: 1, textAlign: 'center', padding: '8px 0', borderRadius: 10, background: i === 0 ? '#0E9E6D' : 'transparent', fontSize: 12, fontWeight: 600, color: i === 0 ? 'white' : 'var(--txt-2)' }}>{t}</div>
          ))}
        </div>

        {/* Trips */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {trips.map((t, i) => (
            <div key={i} style={{ background: 'white', borderRadius: 16, padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 40, height: 40, borderRadius: 12, background: t.status === 'Cancelled' ? 'rgba(226,61,61,0.08)' : 'rgba(14,158,109,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><rect x="2" y="6" width="16" height="11" rx="2" stroke={t.status === 'Cancelled' ? '#E23D3D' : '#0E9E6D'} strokeWidth="1.5"/><path d="M6 6V4a2 2 0 014 0v2M6 10h2m4 0h2M6 13h2" stroke={t.status === 'Cancelled' ? '#E23D3D' : '#0E9E6D'} strokeWidth="1.5" strokeLinecap="round"/></svg>
              </div>
              <div style={{ flex: 1 }}>
                <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--txt)', marginBottom: 2 }}>{t.route}</p>
                <p style={{ fontSize: 11, color: 'var(--txt-2)' }}>{t.date}</p>
              </div>
              <div style={{ textAlign: 'right' }}>
                <p style={{ fontSize: 14, fontWeight: 700, color: t.status === 'Cancelled' ? 'var(--txt-2)' : 'var(--txt)', fontFamily: 'var(--heading)', textDecoration: t.status === 'Cancelled' ? 'line-through' : 'none' }}>{t.fare}</p>
                <span style={{ fontSize: 10, fontWeight: 700, color: t.status === 'Cancelled' ? '#E23D3D' : '#0B7E57', background: t.status === 'Cancelled' ? 'rgba(226,61,61,0.08)' : 'rgba(14,158,109,0.08)', borderRadius: 6, padding: '1px 6px' }}>{t.status}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
      <HomeBar />
    </div>
  )
}

// ── P14 · Favourite Routes ───────────────────────────────────────────────
export function P14_FavouriteRoutes() {
  const routes = [
    { from: 'Madina', to: 'Circle', next: '08:30', seats: 5, price: '₵6', saved: '₵2.50', freq: 'Daily' },
    { from: 'Circle', to: 'Tema', next: '09:15', seats: 3, price: '₵9', saved: '₵4.00', freq: '3×/week' },
    { from: 'Accra Central', to: 'Kaneshie', next: '10:00', seats: 8, price: '₵4.50', saved: '₵1.50', freq: 'Weekdays' },
  ]
  return (
    <div style={{ width: '100%', height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ background: 'linear-gradient(160deg,#0B7E57,#0E9E6D)', paddingBottom: 20 }}>
        <StatusBar light />
        <div style={{ padding: '0 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <p style={{ fontSize: 20, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Favourite Routes</p>
          <button style={{ background: 'rgba(255,255,255,0.2)', border: 'none', borderRadius: 10, padding: '6px 12px', color: 'white', fontSize: 12, fontWeight: 600 }}>+ Add</button>
        </div>
        <p style={{ padding: '6px 20px 0', fontSize: 13, color: 'rgba(255,255,255,0.75)' }}>One-tap booking for your regular commute</p>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 24px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 16 }}>
          {routes.map((r, i) => (
            <div key={i} style={{ background: 'white', borderRadius: 20, overflow: 'hidden', boxShadow: '0 2px 16px rgba(0,0,0,0.06)' }}>
              {/* Route header */}
              <div style={{ padding: '16px 16px 12px', borderBottom: '1px solid var(--border)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <p style={{ fontSize: 15, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>{r.from}</p>
                      <svg width="20" height="10" viewBox="0 0 20 10" fill="none"><path d="M0 5h18M14 1l4 4-4 4" stroke="#0E9E6D" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
                      <p style={{ fontSize: 15, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>{r.to}</p>
                    </div>
                    <p style={{ fontSize: 11, color: 'var(--txt-2)', marginTop: 2 }}>{r.freq} · Next at {r.next}</p>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <p style={{ fontSize: 20, fontWeight: 800, color: 'var(--green)', fontFamily: 'var(--heading)' }}>{r.price}</p>
                    <p style={{ fontSize: 10, color: 'var(--txt-2)' }}>Save {r.saved}</p>
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontSize: 11, fontWeight: 600, color: r.seats > 3 ? '#0B7E57' : '#B8860B', background: r.seats > 3 ? 'rgba(14,158,109,0.1)' : 'rgba(244,179,51,0.12)', borderRadius: 8, padding: '2px 8px' }}>{r.seats} seats left</span>
                  <span style={{ fontSize: 11, color: 'var(--txt-2)' }}>·</span>
                  <span style={{ fontSize: 11, color: 'var(--txt-2)' }}>~35 min</span>
                </div>
              </div>
              {/* Book button */}
              <button style={{ width: '100%', padding: '13px 0', background: '#0E9E6D', border: 'none', color: 'white', fontSize: 14, fontWeight: 700, fontFamily: 'var(--heading)', cursor: 'pointer' }}>
                Book Now — One Tap
              </button>
            </div>
          ))}
        </div>

        {/* Tip */}
        <div style={{ background: 'rgba(31,111,178,0.08)', borderRadius: 14, padding: '12px 14px', marginTop: 16, display: 'flex', gap: 10 }}>
          <span style={{ fontSize: 16 }}>💡</span>
          <p style={{ fontSize: 12, color: '#1557A0', lineHeight: 1.5 }}>Subscribe to a route to get guaranteed seats and extra savings every week.</p>
        </div>
      </div>
      <HomeBar />
    </div>
  )
}

// ── P15 · SOS Emergency ─────────────────────────────────────────────────
export function P15_SOS() {
  return (
    <div style={{ width: '100%', height: '100%', background: '#0D1117', display: 'flex', flexDirection: 'column' }}>
      <StatusBar light />
      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 20px 24px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ marginBottom: 14 }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, background: 'rgba(255,255,255,0.1)', borderRadius: 10, padding: '3px 10px 3px 4px' }}>
            <img src={troSkyLogo} alt="TroSky" style={{ height: 20, objectFit: 'contain', display: 'block', borderRadius: 4 }} />
            <span style={{ fontSize: 12, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>TroSky</span>
          </div>
        </div>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
          <div>
            <p style={{ fontSize: 22, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Emergency</p>
            <p style={{ fontSize: 13, color: 'rgba(255,255,255,0.5)' }}>Your location is being shared</p>
          </div>
          <div style={{ background: 'rgba(14,158,109,0.15)', borderRadius: 12, padding: '6px 10px', display: 'flex', alignItems: 'center', gap: 6 }}>
            <div style={{ width: 6, height: 6, borderRadius: '50%', background: '#0E9E6D' }} />
            <span style={{ fontSize: 11, color: '#0E9E6D', fontWeight: 600 }}>GPS Active</span>
          </div>
        </div>

        {/* SOS button */}
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 28 }}>
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ width: 160, height: 160, borderRadius: '50%', border: '2px solid rgba(226,61,61,0.2)', position: 'absolute' }} />
            <div style={{ width: 140, height: 140, borderRadius: '50%', border: '2px solid rgba(226,61,61,0.35)', position: 'absolute' }} />
            <div style={{ width: 120, height: 120, borderRadius: '50%', background: 'linear-gradient(135deg,#E23D3D,#C12B2B)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 0 40px rgba(226,61,61,0.5)', flexDirection: 'column', gap: 2 }}>
              <p style={{ fontSize: 22, fontWeight: 900, color: 'white', fontFamily: 'var(--heading)', letterSpacing: '0.05em' }}>SOS</p>
              <p style={{ fontSize: 9, color: 'rgba(255,255,255,0.7)', letterSpacing: '0.05em' }}>HOLD 3 SEC</p>
            </div>
          </div>
        </div>

        {/* Location */}
        <div style={{ background: 'rgba(255,255,255,0.06)', borderRadius: 14, padding: '12px 14px', marginBottom: 16, display: 'flex', gap: 10, alignItems: 'center' }}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="8" r="3" stroke="#F4B333" strokeWidth="1.5"/><path d="M9 1a7 7 0 017 7c0 5-7 10-7 10S2 13 2 8a7 7 0 017-7z" stroke="#F4B333" strokeWidth="1.5"/></svg>
          <div>
            <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', marginBottom: 1 }}>CURRENT LOCATION</p>
            <p style={{ fontSize: 13, fontWeight: 600, color: 'white' }}>Kwame Nkrumah Ave, Accra</p>
          </div>
        </div>

        {/* Trusted contacts */}
        <p style={{ fontSize: 11, fontWeight: 700, color: 'rgba(255,255,255,0.4)', letterSpacing: '0.06em', marginBottom: 10 }}>TRUSTED CONTACTS NOTIFIED</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 20 }}>
          {[['Abena Mensah', 'Sister', '✓ Notified'],['Kwame Asante', 'Friend', '✓ Notified'],['TroSky Support', 'Platform', '✓ Notified']].map(([name, rel, status]) => (
            <div key={name} style={{ background: 'rgba(255,255,255,0.06)', borderRadius: 12, padding: '10px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14 }}>👤</div>
              <div style={{ flex: 1 }}>
                <p style={{ fontSize: 13, fontWeight: 600, color: 'white' }}>{name}</p>
                <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.4)' }}>{rel}</p>
              </div>
              <span style={{ fontSize: 11, fontWeight: 600, color: '#0E9E6D' }}>{status}</span>
            </div>
          ))}
        </div>

        {/* Actions */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <button style={{ height: 50, borderRadius: 14, background: 'rgba(255,255,255,0.08)', border: '1px solid rgba(255,255,255,0.12)', color: 'white', fontSize: 14, fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
            📞 Call TroSky Support
          </button>
          <button style={{ height: 50, borderRadius: 14, background: 'rgba(31,111,178,0.2)', border: '1px solid rgba(31,111,178,0.3)', color: '#7ABDE8', fontSize: 14, fontWeight: 600 }}>
            Share Trip Link
          </button>
        </div>
      </div>
      <HomeBar light />
    </div>
  )
}

// ── P16 · Rate Driver ────────────────────────────────────────────────────
export function P16_RateDriver() {
  const stars = [1,2,3,4,5]
  const categories = [
    { label: 'Safety', filled: 5 },
    { label: 'Cleanliness', filled: 4 },
    { label: 'Professionalism', filled: 5 },
    { label: 'Punctuality', filled: 4 },
  ]
  return (
    <div style={{ width: '100%', height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ background: 'linear-gradient(160deg,#12263B,#1F3A5B)', paddingBottom: 24 }}>
        <StatusBar light />
        <div style={{ padding: '0 20px', textAlign: 'center' }}>
          <p style={{ fontSize: 13, color: 'rgba(255,255,255,0.6)', marginBottom: 4 }}>TRIP COMPLETE</p>
          <p style={{ fontSize: 19, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>Rate Your Driver</p>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 24px' }}>
        {/* Driver card */}
        <div style={{ background: 'white', borderRadius: 20, padding: '20px', marginTop: -14, boxShadow: '0 8px 24px rgba(0,0,0,0.08)', textAlign: 'center', marginBottom: 16 }}>
          <div style={{ width: 70, height: 70, borderRadius: '50%', background: 'linear-gradient(135deg,#F4B333,#E8920A)', margin: '0 auto 10px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 28, fontWeight: 800, color: 'white', fontFamily: 'var(--heading)' }}>K</div>
          <p style={{ fontSize: 17, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>Kweku Boateng</p>
          <p style={{ fontSize: 12, color: 'var(--txt-2)', marginBottom: 10 }}>GR-2034-21 · Toyota HiAce</p>

          {/* Trip summary */}
          <div style={{ display: 'flex', justifyContent: 'center', gap: 24, padding: '12px 0', borderTop: '1px solid var(--border)', borderBottom: '1px solid var(--border)', marginBottom: 16 }}>
            {[['Madina → Circle', 'Route'], ['35 min', 'Duration'], ['₵6.00', 'Fare']].map(([v, l]) => (
              <div key={l}>
                <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', fontFamily: 'var(--heading)' }}>{v}</p>
                <p style={{ fontSize: 10, color: 'var(--txt-2)' }}>{l}</p>
              </div>
            ))}
          </div>

          {/* Overall stars */}
          <p style={{ fontSize: 12, color: 'var(--txt-2)', marginBottom: 8 }}>Overall rating</p>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 8 }}>
            {stars.map(s => (
              <svg key={s} width="32" height="32" viewBox="0 0 32 32" fill={s <= 5 ? '#F4B333' : '#E4E8EE'}><path d="M16 2l3.6 7.3 8.1 1.2-5.9 5.7 1.4 8-7.2-3.8-7.2 3.8 1.4-8-5.9-5.7 8.1-1.2z"/></svg>
            ))}
          </div>
        </div>

        {/* Category ratings */}
        <div style={{ background: 'white', borderRadius: 20, padding: '16px', marginBottom: 14 }}>
          <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--txt)', marginBottom: 14 }}>Detailed Ratings</p>
          {categories.map(c => (
            <div key={c.label} style={{ display: 'flex', alignItems: 'center', marginBottom: 14 }}>
              <p style={{ width: 110, fontSize: 13, color: 'var(--txt)' }}>{c.label}</p>
              <div style={{ display: 'flex', gap: 4 }}>
                {stars.map(s => (
                  <svg key={s} width="22" height="22" viewBox="0 0 32 32" fill={s <= c.filled ? '#F4B333' : '#E4E8EE'}><path d="M16 2l3.6 7.3 8.1 1.2-5.9 5.7 1.4 8-7.2-3.8-7.2 3.8 1.4-8-5.9-5.7 8.1-1.2z"/></svg>
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* Comment */}
        <div style={{ background: 'white', borderRadius: 16, padding: '14px 14px' }}>
          <p style={{ fontSize: 12, fontWeight: 600, color: 'var(--txt-2)', marginBottom: 8 }}>Leave a comment (optional)</p>
          <div style={{ background: 'var(--bg)', borderRadius: 10, padding: '10px 12px', fontSize: 13, color: 'var(--txt-2)', minHeight: 60 }}>Great driver, very punctual and safe...</div>
        </div>

        <button style={{ width: '100%', height: 52, borderRadius: 16, background: '#0E9E6D', border: 'none', color: 'white', fontSize: 15, fontWeight: 700, fontFamily: 'var(--heading)', marginTop: 14 }}>
          Submit Rating
        </button>
      </div>
      <HomeBar />
    </div>
  )
}
