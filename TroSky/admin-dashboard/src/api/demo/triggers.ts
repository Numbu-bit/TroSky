import { getDb, touch } from './db'
import { COMPLAINTS } from './db/build'
import type { ComplaintRec, DocumentRec, DriverRec, VehicleRec } from './db/model'
import { platformState, SETTING_DEFAULTS } from './db/platform'
import { demoEmail, demoPhone, personName, plate, SEATS, VEHICLE_MODELS } from './ghana'
import { Random } from './random'

export { raiseDemoSos } from './handlers/safety'

const random = new Random(Date.now() % 100_000)
const DAY = 86_400_000

const dateOnly = (time: number) => new Date(time).toISOString().slice(0, 10)

function upload(type: DocumentRec['document_type'], expires: string | null): DocumentRec {
  return {
    id: random.uuid(),
    document_type: type,
    status: 'pending',
    uploaded_at: new Date().toISOString(),
    expires_at: expires,
    original_filename: `${type.replace(/_/g, '-')}-${random.int(1000, 9999)}.jpg`,
    rejection_reason: null,
  }
}

/** A driver who has just applied: a new account and a pending application. */
export function addDemoDriverApplication(): DriverRec {
  const db = getDb()
  const now = Date.now()
  const serial = 5000 + random.int(0, 4999)
  const name = personName(random)
  const user = {
    id: random.uuid(),
    full_name: name,
    phone_number: demoPhone(serial),
    email: random.chance(0.6) ? demoEmail(name, serial) : null,
    roles: ['driver' as const],
    city: 'Accra',
    created_at: new Date(now - 20 * 60_000).toISOString(),
    last_login_at: new Date(now).toISOString(),
    is_active: true,
    is_suspended: false,
    suspended_at: null,
    suspension_reason: null,
    phone_verified: true,
    email_verified: false,
  }
  const expiry = dateOnly(now + random.int(200, 1500) * DAY)
  const driver: DriverRec = {
    id: random.uuid(),
    user_id: user.id,
    license_number: `DL-${random.int(100000, 999999)}-${random.int(10, 99)}`,
    license_expiry: expiry,
    license_class: random.pick(['B', 'C', 'D', 'E']),
    years_of_experience: random.int(2, 25),
    status: 'pending',
    created_at: new Date(now).toISOString(),
    fleet_id: null,
    vehicle_id: null,
    documents: [upload('driver_license', expiry), upload('profile_photo', null)],
    info_requests: [],
    rejection_reason: null,
  }
  if (random.chance(0.5)) driver.documents.push(upload('ghana_card', null))
  db.users.push(user)
  db.drivers.push(driver)
  touch()
  return driver
}

/** A vehicle a fleet owner has just added: pending, with its three documents. */
export function addDemoVehicleApplication(): VehicleRec {
  const db = getDb()
  const now = Date.now()
  const fleet = random.pick(db.fleets)
  const type = random.chance(0.75) ? 'minibus' : 'bus'
  const [make, model] = random.pick(VEHICLE_MODELS[type])
  const capacity = SEATS[type]
  const seatIds = Array.from({ length: capacity }, () => random.uuid())
  const insurance = dateOnly(now + random.int(60, 360) * DAY)
  const vehicle: VehicleRec = {
    id: random.uuid(),
    fleet_id: fleet.id,
    registration_number: plate(random),
    vehicle_type: type,
    make,
    model,
    year: random.int(2012, 2024),
    capacity,
    status: 'pending',
    created_at: new Date(now).toISOString(),
    seat_ids: seatIds,
    seat_labels: seatIds.map((_, position) => String(position + 1)),
    insurance_expiry: insurance,
    roadworthy_expiry: dateOnly(now + random.int(30, 200) * DAY),
    documents: [],
    info_requests: [],
    rejection_reason: null,
  }
  vehicle.documents = [
    upload('vehicle_registration', null),
    upload('vehicle_insurance', insurance),
    upload('roadworthiness_certificate', vehicle.roadworthy_expiry),
  ]
  db.vehicles.push(vehicle)
  touch()
  return vehicle
}

/** A passenger complains about a trip they took, due within the SLA set. */
export function addDemoComplaint(): ComplaintRec {
  const db = getDb()
  const now = Date.now()
  const booking = random.pick(db.bookings.filter((candidate) => candidate.status === 'completed'))
  const category = random.pick([
    'driver_conduct',
    'vehicle_condition',
    'payment',
    'safety',
  ] as const)
  const [subject, description] = random.pick(COMPLAINTS[category])
  const priority: ComplaintRec['priority'] = category === 'safety' ? 'urgent' : 'medium'
  const sla = (platformState().settings.get('complaint_sla_hours')?.value ??
    SETTING_DEFAULTS.complaint_sla_hours) as Record<ComplaintRec['priority'], number>
  const complaint: ComplaintRec = {
    id: random.uuid(),
    filed_by: booking.passenger_id,
    booking_id: booking.id,
    trip_id: booking.trip_id,
    category,
    subject,
    description,
    status: 'open',
    priority,
    resolved_by: null,
    resolved_at: null,
    resolution_notes: null,
    assigned_to: null,
    assigned_at: null,
    first_response_at: null,
    due_at: new Date(now + sla[priority] * 3_600_000).toISOString(),
    created_at: new Date(now).toISOString(),
    notes: [],
  }
  db.complaints.unshift(complaint)
  touch()
  return complaint
}
