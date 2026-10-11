import type { Schemas } from '@/api/types'

import { DAY, getDb, index, touch } from '../db'
import type { DocumentRec, DriverRec, VehicleRec } from '../db/model'
import { csvAnswer, endpoint, errorResponse, notFound, paginate } from '../http'
import { driverRating, driverResponse, money, vehicleResponse } from '../views'

const ON_THE_ROAD = new Set(['boarding', 'in_progress', 'paused'])

type Live = 'on_trip' | 'idle' | 'offline'

/** Who is on a trip now, and when each was last out. */
export function activity() {
  const current = new Map<string, string>()
  const lastOut = new Map<string, number>()
  const now = Date.now()
  for (const trip of getDb().trips) {
    const departed = Date.parse(trip.scheduled_departure_at)
    if (departed > now) continue
    for (const id of [trip.driver_id, trip.vehicle_id]) {
      if (!id) continue
      if (ON_THE_ROAD.has(trip.status)) current.set(id, trip.id)
      if (departed > (lastOut.get(id) ?? 0)) lastOut.set(id, departed)
    }
  }
  return { current, lastOut, now }
}

function liveStatus(id: string, approved: boolean, seen: ReturnType<typeof activity>): Live {
  if (seen.current.has(id)) return 'on_trip'
  return approved && seen.now - (seen.lastOut.get(id) ?? 0) < 7 * DAY ? 'idle' : 'offline'
}

export function documentSummary(document: DocumentRec): Schemas['DocumentSummary'] {
  return {
    id: document.id,
    document_type: document.document_type,
    status: document.status,
    expiry_date: document.expires_at,
    original_filename: document.original_filename,
    rejection_reason: document.rejection_reason,
    uploaded_at: document.uploaded_at,
  }
}

function fleetRef(fleetId: string | null): Schemas['Ref'] | null {
  if (!fleetId) return null
  const fleet = index().fleets.get(fleetId)
  return fleet ? { id: fleet.id, name: fleet.name } : null
}

export function adminDriver(
  driver: DriverRec,
  seen: ReturnType<typeof activity>,
): Schemas['AdminDriverResponse'] {
  const user = index().users.get(driver.user_id)!
  const vehicle = driver.vehicle_id ? index().vehicles.get(driver.vehicle_id) : undefined
  const rating = driverRating(driver.id)
  const last = seen.lastOut.get(driver.id)
  return {
    id: driver.id,
    user_id: driver.user_id,
    full_name: user.full_name,
    phone_number: user.phone_number,
    email: user.email,
    status: driver.status,
    license_number: driver.license_number,
    license_expiry: driver.license_expiry,
    fleet: fleetRef(driver.fleet_id),
    vehicle: vehicle ? { id: vehicle.id, registration_number: vehicle.registration_number } : null,
    live_status: liveStatus(driver.id, driver.status === 'approved', seen),
    current_trip_id: seen.current.get(driver.id) ?? null,
    average_rating: rating?.average ?? null,
    rating_count: rating?.count ?? 0,
    last_active_at: last ? new Date(last).toISOString() : user.last_login_at,
    created_at: driver.created_at,
  }
}

export function adminVehicle(
  vehicle: VehicleRec,
  seen: ReturnType<typeof activity>,
): Schemas['AdminVehicleResponse'] {
  const fleet = index().fleets.get(vehicle.fleet_id)!
  const owner = index().owners.get(fleet.owner_id)!
  const driver = getDb().drivers.find((candidate) => candidate.vehicle_id === vehicle.id)
  return {
    id: vehicle.id,
    registration_number: vehicle.registration_number,
    vehicle_type: vehicle.vehicle_type,
    make_model: `${vehicle.make} ${vehicle.model}`,
    year: vehicle.year,
    capacity: vehicle.capacity,
    status: vehicle.status,
    fleet: { id: fleet.id, name: fleet.name },
    fleet_owner: { id: owner.id, name: owner.business_name },
    driver: driver
      ? { id: driver.id, name: index().users.get(driver.user_id)?.full_name ?? null }
      : null,
    live_status: liveStatus(vehicle.id, vehicle.status === 'approved', seen),
    current_trip_id: seen.current.get(vehicle.id) ?? null,
    insurance_expiry: vehicle.insurance_expiry,
    roadworthy_expiry: vehicle.roadworthy_expiry,
    created_at: vehicle.created_at,
  }
}

function list(value: string | null): string[] {
  return (value ?? '').split(',').filter(Boolean)
}

function expiringWithin(url: URL): number | null {
  const days = url.searchParams.get('expiring_within_days')
  return days ? Date.now() + Number(days) * DAY : null
}

/** A stand-in image for a document: obviously a demo, never a real one. */
function documentImage(title: string, owner: string, detail: string): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="900" height="560" viewBox="0 0 900 560">
<rect width="900" height="560" rx="24" fill="#f5f5f5" stroke="#12355b" stroke-width="6"/>
<rect x="0" y="0" width="900" height="90" rx="24" fill="#12355b"/>
<text x="40" y="58" font-family="Arial" font-size="34" font-weight="700" fill="#ffffff">${title}</text>
<rect x="40" y="130" width="220" height="270" rx="12" fill="#cfd5dc"/>
<circle cx="150" cy="230" r="58" fill="#9aa3ad"/><rect x="80" y="300" width="140" height="80" rx="40" fill="#9aa3ad"/>
<text x="300" y="180" font-family="Arial" font-size="30" fill="#333333">${owner}</text>
<text x="300" y="240" font-family="Arial" font-size="26" fill="#5c6670">${detail}</text>
<text x="450" y="500" font-family="Arial" font-size="44" font-weight="700" fill="#d32f2f" opacity="0.35" text-anchor="middle" transform="rotate(-12 450 500)">DEMO DOCUMENT</text>
</svg>`
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`
}

const DOCUMENT_TITLES: Record<string, string> = {
  driver_license: 'Driver’s licence',
  profile_photo: 'Profile photo',
  ghana_card: 'Ghana Card',
  police_report: 'Police report',
  vehicle_insurance: 'Insurance certificate',
  vehicle_registration: 'Vehicle registration (DVLA)',
  roadworthiness_certificate: 'Roadworthiness certificate',
  other: 'Document',
}

export const fleetHandlers = [
  // -------------------------------------------------------------- drivers
  endpoint.get('/admin/drivers', ['drivers:approve', 'trips:monitor_live'], ({ url }) => {
    const statuses = list(url.searchParams.get('status'))
    const live = list(url.searchParams.get('live_status'))
    const fleetId = url.searchParams.get('fleet_id')
    const q = (url.searchParams.get('q') ?? '').trim().toLowerCase()
    const until = expiringWithin(url)
    const sort = url.searchParams.get('sort') ?? 'full_name'
    const seen = activity()
    let rows = getDb()
      .drivers.map((driver) => adminDriver(driver, seen))
      .filter(
        (row) =>
          (!statuses.length || statuses.includes(row.status)) &&
          (!live.length || live.includes(row.live_status)) &&
          (!fleetId || row.fleet?.id === fleetId) &&
          (!until || Date.parse(row.license_expiry) <= until) &&
          (!q ||
            (row.full_name ?? '').toLowerCase().includes(q) ||
            row.phone_number.includes(q) ||
            row.license_number.toLowerCase().includes(q)),
      )
    const key = sort.replace(/^-/, '') as keyof Schemas['AdminDriverResponse']
    rows = rows.sort((a, b) =>
      String(a[key] ?? '').localeCompare(String(b[key] ?? ''), 'en', { numeric: true }),
    )
    if (sort.startsWith('-')) rows.reverse()
    if (url.searchParams.get('format') === 'csv') return csvAnswer(rows, 'drivers')
    return paginate(rows, url)
  }),

  endpoint.get(
    '/admin/drivers/:driverId',
    ['drivers:approve', 'trips:monitor_live'],
    ({ params }) => {
      const driver = index().drivers.get(params.driverId!)
      if (!driver) return notFound('Driver not found.')
      const vehicle = driver.vehicle_id ? index().vehicles.get(driver.vehicle_id) : undefined
      return {
        ...adminDriver(driver, activity()),
        license_class: driver.license_class,
        years_of_experience: driver.years_of_experience,
        documents: driver.documents.map(documentSummary),
        vehicles: vehicle
          ? [
              {
                id: vehicle.id,
                registration_number: vehicle.registration_number,
                vehicle_type: vehicle.vehicle_type,
                fleet_id: vehicle.fleet_id,
                assigned_at: driver.created_at,
              },
            ]
          : [],
      } satisfies Schemas['AdminDriverDetailResponse']
    },
  ),

  endpoint.post('/admin/drivers/:driverId/approve', ['drivers:approve'], ({ params }) => {
    const driver = index().drivers.get(params.driverId!)
    if (!driver) return notFound('Driver not found.')
    if (driver.status === 'approved') {
      return errorResponse(409, 'INVALID_STATE_TRANSITION', 'This driver is already approved.')
    }
    driver.status = 'approved'
    driver.rejection_reason = null
    for (const document of driver.documents) document.status = 'approved'
    touch()
    return driverResponse(driver)
  }),

  endpoint.post('/admin/drivers/:driverId/reject', ['drivers:approve'], ({ params, body }) => {
    const driver = index().drivers.get(params.driverId!)
    if (!driver) return notFound('Driver not found.')
    if (driver.status === 'rejected') {
      return errorResponse(409, 'INVALID_STATE_TRANSITION', 'This driver is already rejected.')
    }
    driver.status = 'rejected'
    driver.rejection_reason =
      (body as Schemas['ApprovalReviewRequest'] | undefined)?.rejection_reason || 'Not specified'
    touch()
    return driverResponse(driver)
  }),

  // ------------------------------------------------------------- vehicles
  endpoint.get('/admin/vehicles', ['vehicles:approve', 'trips:monitor_live'], ({ url }) => {
    const statuses = list(url.searchParams.get('status'))
    const live = list(url.searchParams.get('live_status'))
    const fleetId = url.searchParams.get('fleet_id')
    const ownerId = url.searchParams.get('fleet_owner_id')
    const q = (url.searchParams.get('q') ?? '').trim().toLowerCase()
    const until = expiringWithin(url)
    const sort = url.searchParams.get('sort') ?? 'registration_number'
    const seen = activity()
    let rows = getDb()
      .vehicles.map((vehicle) => adminVehicle(vehicle, seen))
      .filter(
        (row) =>
          (!statuses.length || statuses.includes(row.status)) &&
          (!live.length || live.includes(row.live_status)) &&
          (!fleetId || row.fleet.id === fleetId) &&
          (!ownerId || row.fleet_owner.id === ownerId) &&
          (!until ||
            (row.insurance_expiry !== null && Date.parse(row.insurance_expiry) <= until) ||
            (row.roadworthy_expiry !== null && Date.parse(row.roadworthy_expiry) <= until)) &&
          (!q || row.registration_number.toLowerCase().includes(q)),
      )
    const key = sort.replace(/^-/, '') as keyof Schemas['AdminVehicleResponse']
    rows = rows.sort((a, b) =>
      String(a[key] ?? '').localeCompare(String(b[key] ?? ''), 'en', { numeric: true }),
    )
    if (sort.startsWith('-')) rows.reverse()
    if (url.searchParams.get('format') === 'csv') return csvAnswer(rows, 'vehicles')
    return paginate(rows, url)
  }),

  endpoint.get(
    '/admin/vehicles/:vehicleId',
    ['vehicles:approve', 'trips:monitor_live'],
    ({ params }) => {
      const vehicle = index().vehicles.get(params.vehicleId!)
      if (!vehicle) return notFound('Vehicle not found.')
      const since = Date.now() - 30 * DAY
      const trips = getDb().trips.filter(
        (trip) =>
          trip.vehicle_id === vehicle.id &&
          Date.parse(trip.scheduled_departure_at) >= since &&
          Date.parse(trip.scheduled_departure_at) <= Date.now(),
      )
      let revenue = 0
      for (const trip of trips) {
        for (const booking of index().bookingsByTrip.get(trip.id) ?? []) {
          if (booking.status === 'completed' || booking.status === 'confirmed')
            revenue += booking.fare_amount
        }
      }
      const tripIds = new Set(
        getDb()
          .trips.filter((trip) => trip.vehicle_id === vehicle.id)
          .map((trip) => trip.id),
      )
      return {
        ...adminVehicle(vehicle, activity()),
        documents: vehicle.documents.map(documentSummary),
        last_30_days: {
          trips: trips.length,
          completed_trips: trips.filter((trip) => trip.status === 'completed').length,
          revenue: money(revenue),
        },
        recent_incidents: getDb()
          .incidents.filter((incident) => tripIds.has(incident.trip_id))
          .slice(0, 5)
          .map((incident) => ({
            id: incident.id,
            trip_id: incident.trip_id,
            incident_type: incident.incident_type,
            severity: incident.severity,
            status: incident.status,
            created_at: incident.created_at,
          })),
      } satisfies Schemas['AdminVehicleDetailResponse']
    },
  ),

  endpoint.post('/admin/vehicles/:vehicleId/approve', ['vehicles:approve'], ({ params }) => {
    const vehicle = index().vehicles.get(params.vehicleId!)
    if (!vehicle) return notFound('Vehicle not found.')
    if (vehicle.status === 'approved') {
      return errorResponse(409, 'INVALID_STATE_TRANSITION', 'This vehicle is already approved.')
    }
    vehicle.status = 'approved'
    vehicle.rejection_reason = null
    for (const document of vehicle.documents) document.status = 'approved'
    touch()
    return vehicleResponse(vehicle)
  }),

  endpoint.post('/admin/vehicles/:vehicleId/reject', ['vehicles:approve'], ({ params, body }) => {
    const vehicle = index().vehicles.get(params.vehicleId!)
    if (!vehicle) return notFound('Vehicle not found.')
    if (vehicle.status === 'rejected') {
      return errorResponse(409, 'INVALID_STATE_TRANSITION', 'This vehicle is already rejected.')
    }
    vehicle.status = 'rejected'
    vehicle.rejection_reason =
      (body as Schemas['ApprovalReviewRequest'] | undefined)?.rejection_reason || 'Not specified'
    touch()
    return vehicleResponse(vehicle)
  }),

  // ------------------------------------------- more information, documents
  ...(['drivers', 'vehicles'] as const).map((kind) =>
    endpoint.post(
      `/admin/${kind}/:subjectId/request-info`,
      [kind === 'drivers' ? 'drivers:approve' : 'vehicles:approve'],
      ({ params, body, admin }) => {
        const subject =
          kind === 'drivers'
            ? index().drivers.get(params.subjectId!)
            : index().vehicles.get(params.subjectId!)
        if (!subject)
          return notFound(kind === 'drivers' ? 'Driver not found.' : 'Vehicle not found.')
        const request = body as Schemas['InfoRequestBody']
        const returned = subject.documents.filter((document) =>
          request.document_types.includes(document.document_type),
        )
        for (const document of returned) {
          document.status = 'rejected'
          document.rejection_reason = request.note
        }
        const requestedAt = new Date().toISOString()
        subject.info_requests.push({
          document_types: request.document_types,
          note: request.note,
          documents_returned: returned.map((document) => document.id),
          requested_at: requestedAt,
          requested_by: admin.id,
        })
        touch()
        const ownerUser =
          kind === 'drivers'
            ? (subject as DriverRec).user_id
            : index().owners.get(index().fleets.get((subject as VehicleRec).fleet_id)!.owner_id)!
                .user_id
        return {
          subject_type: kind === 'drivers' ? 'driver' : 'vehicle',
          subject_id: subject.id,
          document_types: request.document_types,
          note: request.note,
          documents_returned: returned.map((document) => document.id),
          notified_user_id: ownerUser,
          requested_at: requestedAt,
        } satisfies Schemas['InfoRequestResponse']
      },
    ),
  ),

  endpoint.get(
    '/admin/documents/:documentId',
    ['drivers:approve', 'vehicles:approve'],
    ({ params }) => {
      const db = getDb()
      for (const driver of db.drivers) {
        const document = driver.documents.find((candidate) => candidate.id === params.documentId)
        if (document) {
          const user = index().users.get(driver.user_id)!
          return link(document, 'driver', driver.id, user.full_name, driver.license_number)
        }
      }
      for (const vehicle of db.vehicles) {
        const document = vehicle.documents.find((candidate) => candidate.id === params.documentId)
        if (document) {
          return link(
            document,
            'vehicle',
            vehicle.id,
            vehicle.registration_number,
            `${vehicle.make} ${vehicle.model}, ${vehicle.year}`,
          )
        }
      }
      return notFound('Document not found.')
    },
  ),
]

function link(
  document: DocumentRec,
  ownerType: 'driver' | 'vehicle',
  ownerId: string,
  owner: string,
  detail: string,
): Schemas['DocumentLinkResponse'] {
  return {
    document_id: document.id,
    owner_type: ownerType,
    owner_id: ownerId,
    document_type: document.document_type,
    status: document.status,
    expiry_date: document.expires_at,
    original_filename: document.original_filename,
    // The demo draws every document as an image (a data: URL).
    mime_type: document.original_filename.endsWith('.png') ? 'image/png' : 'image/jpeg',
    file_size_bytes: 48_213,
    url: documentImage(DOCUMENT_TITLES[document.document_type] ?? 'Document', owner, detail),
    expires_at: new Date(Date.now() + 5 * 60_000).toISOString(),
  }
}
