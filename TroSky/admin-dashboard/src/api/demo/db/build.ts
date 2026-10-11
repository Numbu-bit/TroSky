import { DEMO_ACCOUNTS } from '../accounts'
import { offsets } from '../geo'
import {
  BUSINESS_NAMES,
  CORRIDORS,
  demoEmail,
  demoPhone,
  personName,
  plate,
  SEATS,
  stationByKey,
  STATIONS,
  VEHICLE_MODELS,
} from '../ghana'
import { Random } from '../random'
import type {
  BookingPassengerRec,
  BookingRec,
  CancellationRec,
  ComplaintRec,
  DocumentRec,
  DriverActionRec,
  DriverRec,
  FleetOwnerRec,
  FleetRec,
  IncidentRec,
  OfferRec,
  PaymentRec,
  RatingRec,
  RefundRec,
  RouteRec,
  ScheduleRec,
  SosRec,
  StopRec,
  TripRec,
  UserRec,
  VehicleRec,
  WithdrawalRec,
} from './model'

export const DAY = 86_400_000
export const HOUR = 3_600_000
export const MINUTE = 60_000

/** History length: today and the 89 days before it. */
export const HISTORY_DAYS = 90

export interface DemoDb {
  /** When the demo platform was built: everything is dated relative to it. */
  builtAt: number
  users: UserRec[]
  stops: StopRec[]
  routes: RouteRec[]
  schedules: ScheduleRec[]
  fleetOwners: FleetOwnerRec[]
  fleets: FleetRec[]
  vehicles: VehicleRec[]
  drivers: DriverRec[]
  trips: TripRec[]
  bookings: BookingRec[]
  payments: PaymentRec[]
  refunds: RefundRec[]
  cancellations: CancellationRec[]
  withdrawals: WithdrawalRec[]
  complaints: ComplaintRec[]
  incidents: IncidentRec[]
  sosAlerts: SosRec[]
  ratings: RatingRec[]
  offers: OfferRec[]
  driverActions: DriverActionRec[]
}

const iso = (ms: number) => new Date(ms).toISOString()
const dateOnly = (ms: number) => iso(ms).slice(0, 10)
const round2 = (value: number) => Math.round(value * 100) / 100
const startOfDay = (ms: number) => Math.floor(ms / DAY) * DAY // Accra is UTC+0

const DAY_NAMES = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
] as const

const CHANNELS = [
  ['mtn_momo', 52],
  ['telecel_cash', 16],
  ['airteltigo_money', 10],
  ['card', 8],
  ['wallet', 14],
] as const

const PAYMENT_FAILURES = [
  'Insufficient balance on the mobile money wallet.',
  'The customer did not approve the payment prompt.',
  'Timed out waiting for the customer to approve.',
  'The card was declined by the issuing bank.',
]

export const COMPLAINTS: Record<ComplaintRec['category'], [string, string][]> = {
  driver_conduct: [
    [
      'Driver was rude at Circle',
      'The driver shouted at an old woman getting on and refused to wait for her.',
    ],
    [
      'Driver used his phone while driving',
      'He was on a call for most of the trip from Kaneshie, even on the motorway.',
    ],
    [
      'Overcharged by the mate',
      'The mate asked everyone for an extra GH₵2 although we had all paid in the app.',
    ],
    [
      'Driver skipped my stop',
      'I booked to Legon but he drove straight past and I had to walk back from Madina.',
    ],
  ],
  vehicle_condition: [
    ['Seats were torn and dirty', 'The back row seats were torn and there was dust everywhere.'],
    [
      'Windows would not open',
      'It was very hot and none of the windows opened. The AC did not work either.',
    ],
    [
      'Smoke from the engine',
      'There was smoke coming from under the bonnet before we reached Kasoa.',
    ],
  ],
  safety: [
    [
      'Speeding on the Kumasi road',
      'The driver was overtaking dangerously near Nkawkaw. Many of us were scared.',
    ],
    [
      'Too many passengers on board',
      'People were standing in the aisle although the app said every seat was booked.',
    ],
    ['Door opened while moving', 'The sliding door opened on its own twice while we were moving.'],
  ],
  payment: [
    [
      'Charged twice for one booking',
      'MTN MoMo shows two deductions of the same amount for my booking.',
    ],
    [
      'Refund not received',
      'My trip was cancelled four days ago and I have not received my money back.',
    ],
    [
      'Paid but no ticket',
      'The payment went through on Telecel Cash but the app still says awaiting payment.',
    ],
  ],
  other: [
    ['Lost bag on the bus', 'I left a black backpack under seat 7 on the Circle to Madina trip.'],
    [
      'App showed the wrong pickup time',
      'The app said the bus would leave at 7:30 but it left at 7:05.',
    ],
    [
      'Could not change my seat',
      'I wanted to sit with my child but the app would not let me change seats.',
    ],
  ],
}

const INCIDENTS: Record<IncidentRec['incident_type'], string[]> = {
  accident: ['Minor collision with a taxi at the Lapaz junction. No one hurt.'],
  breakdown: [
    'Radiator overheated near Weija; passengers waited for a replacement bus.',
    'Flat tyre on the motorway, changed in 25 minutes.',
  ],
  delay: [
    'Heavy traffic at Kwame Nkrumah Circle, 40 minutes behind schedule.',
    'Police checkpoint at Kasoa held us for 20 minutes.',
  ],
  safety_concern: ['A passenger reported a man harassing her; he got off at Legon.'],
  passenger_issue: [
    'Passenger refused to pay for luggage and argued with the mate.',
    'A passenger fainted from the heat; she was helped at the next stop.',
  ],
  road_hazard: [
    'Flooding at Kaneshie after the rain; took the Mallam road instead.',
    'Fallen tree blocking the road near Achimota.',
  ],
  other: ['Fuel station queue at Nkawkaw added 30 minutes.'],
}

const RATING_COMMENTS = [
  'Smooth ride, the driver was very polite.',
  'Clean bus and we left on time.',
  'Driver was a bit fast on the motorway.',
  'Very comfortable, will book again.',
  'The mate helped me with my luggage. Thank you!',
  'AC was not working but the driver was nice.',
  null,
  null,
  null,
]

export function buildDemoDb(now: number = Date.now(), seed = 20_261_004): DemoDb {
  const random = new Random(seed)
  const today = startOfDay(now)
  const adminIds = DEMO_ACCOUNTS.map((account) => account.id)

  // ------------------------------------------------------------- network
  const stops: StopRec[] = STATIONS.map((station) => ({
    id: random.uuid(),
    key: station.key,
    name: station.name,
    code: station.key
      .replace(/[^a-z0-9]/g, '')
      .slice(0, 4)
      .toUpperCase(),
    address: `${station.name} station, ${station.city}`,
    city: station.city,
    region: station.region,
    latitude: station.latitude,
    longitude: station.longitude,
    is_active: true,
  }))
  const stopByKey = new Map(stops.map((stop) => [stop.key, stop]))

  const routes: RouteRec[] = []
  const schedules: ScheduleRec[] = []
  for (const corridor of CORRIDORS) {
    for (const direction of [corridor.stops, [...corridor.stops].reverse()]) {
      const points = direction.map((key) => stationByKey(key))
      // Straight lines between stations, lengthened for the road's turns.
      const km = offsets(points).map((value) => round2(value * 1.3))
      const first = points[0]!
      const last = points[points.length - 1]!
      const route: RouteRec = {
        id: random.uuid(),
        name: `${first.name} – ${last.name}`,
        stop_ids: direction.map((key) => stopByKey.get(key)!.id),
        offsets_km: km,
        distance_km: km[km.length - 1]!,
        minutes: corridor.minutes,
        fare: corridor.fare,
        vehicle_type: corridor.vehicle === 'minibus' ? 'minibus' : 'bus',
        seats: SEATS[corridor.vehicle],
        city: first.city === 'Kumasi' || last.city === 'Kumasi' ? 'Kumasi' : 'Accra',
        is_active: true,
        created_at: iso(now - random.int(200, 400) * DAY),
      }
      routes.push(route)
      const slots =
        corridor.vehicle === 'minibus'
          ? [random.pick(['05:45', '06:30', '07:15']), random.pick(['12:00', '16:30', '17:45'])]
          : random.sample(['06:00', '09:00', '14:00'], random.int(1, 2))
      for (const time of slots.sort()) {
        schedules.push({
          id: random.uuid(),
          route_id: route.id,
          departure_time: `${time}:00`,
          days_of_week: [
            'monday',
            'tuesday',
            'wednesday',
            'thursday',
            'friday',
            'saturday',
            'sunday',
          ],
          fare_amount: corridor.fare,
          is_active: true,
        })
      }
    }
  }

  // -------------------------------------------------------------- people
  const users: UserRec[] = []
  let phoneSerial = 100
  function makeUser(
    roles: UserRec['roles'],
    createdAt: number,
    city = random.weighted([
      ['Accra', 70],
      ['Kumasi', 12],
      ['Kasoa', 8],
      ['Cape Coast', 5],
      ['Tema', 5],
    ] as const),
  ): UserRec {
    const name = personName(random)
    phoneSerial += 1
    const user: UserRec = {
      id: random.uuid(),
      full_name: name,
      phone_number: demoPhone(phoneSerial),
      email: random.chance(0.55) ? demoEmail(name, phoneSerial) : null,
      roles,
      city,
      created_at: iso(createdAt),
      last_login_at: iso(
        Math.min(now, createdAt + random.int(1, 80) * DAY - random.int(0, 20) * HOUR),
      ),
      is_active: true,
      is_suspended: false,
      suspended_at: null,
      suspension_reason: null,
      phone_verified: true,
      email_verified: random.chance(0.6),
    }
    users.push(user)
    return user
  }

  // Passengers: a long tail from before the history window, then growth.
  for (let index = 0; index < 420; index += 1) {
    const older = random.chance(0.3)
    const daysAgo = older
      ? random.int(HISTORY_DAYS, 420)
      : Math.floor((HISTORY_DAYS - 1) * Math.pow(random.next(), 1.5))
    makeUser(['passenger'], today - daysAgo * DAY + random.int(6, 22) * HOUR)
  }
  const passengers = users
    .filter((user) => user.roles.includes('passenger'))
    .sort((a, b) => a.created_at.localeCompare(b.created_at))
  for (const user of random.sample(passengers, 3)) {
    user.is_active = false
    user.is_suspended = true
    user.suspended_at = iso(now - random.int(2, 30) * DAY)
    user.suspension_reason = 'Repeated chargebacks on card payments.'
  }

  // Fleet owners and their fleets.
  const fleetOwners: FleetOwnerRec[] = []
  const fleets: FleetRec[] = []
  BUSINESS_NAMES.forEach((business, index) => {
    const user = makeUser(['fleet_owner'], now - random.int(150, 500) * DAY)
    const owner: FleetOwnerRec = {
      id: random.uuid(),
      user_id: user.id,
      business_name: business,
      status: index === BUSINESS_NAMES.length - 1 ? 'pending' : 'approved',
      created_at: user.created_at,
    }
    fleetOwners.push(owner)
    const fleetCount = index < 2 ? 2 : 1
    for (let f = 0; f < fleetCount; f += 1) {
      fleets.push({
        id: random.uuid(),
        owner_id: owner.id,
        name: f === 0 ? business : `${business} – Kumasi`,
        city: f === 0 ? random.pick(['Accra', 'Accra', 'Tema', 'Kasoa']) : 'Kumasi',
        created_at: iso(Date.parse(owner.created_at) + f * 30 * DAY),
      })
    }
  })
  const activeFleets = fleets.filter(
    (fleet) => fleetOwners.find((owner) => owner.id === fleet.owner_id)?.status === 'approved',
  )

  // Vehicles: enough of each kind for the timetable, plus some pending.
  const vehicles: VehicleRec[] = []
  function makeVehicle(
    kind: 'minibus' | 'bus' | 'coach',
    status: VehicleRec['status'],
  ): VehicleRec {
    const [make, model] = random.pick(VEHICLE_MODELS[kind])
    const capacity = SEATS[kind]
    const seatIds = Array.from({ length: capacity }, () => random.uuid())
    const createdAt =
      status === 'approved' ? now - random.int(60, 380) * DAY : now - random.int(1, 9) * DAY
    const vehicle: VehicleRec = {
      id: random.uuid(),
      fleet_id: random.pick(status === 'approved' ? activeFleets : fleets).id,
      registration_number: plate(random),
      vehicle_type: kind === 'minibus' ? 'minibus' : 'bus',
      make,
      model,
      year: random.int(2012, 2024),
      capacity,
      status,
      created_at: iso(createdAt),
      seat_ids: seatIds,
      seat_labels: seatIds.map((_, index) => String(index + 1)),
      insurance_expiry: dateOnly(now + random.int(-5, 320) * DAY),
      roadworthy_expiry: dateOnly(now + random.int(8, 200) * DAY),
      documents: [],
      info_requests: [],
      rejection_reason: status === 'rejected' ? 'Roadworthiness certificate has expired.' : null,
    }
    vehicle.documents = documents(
      ['vehicle_registration', 'vehicle_insurance', 'roadworthiness_certificate'],
      status,
      createdAt,
      vehicle.insurance_expiry,
    )
    vehicles.push(vehicle)
    return vehicle
  }
  function documents(
    types: DocumentRec['document_type'][],
    status: VehicleRec['status'],
    uploadedAt: number,
    expiresAt: string | null,
  ): DocumentRec[] {
    return types.map((type) => ({
      id: random.uuid(),
      document_type: type,
      status: status === 'approved' ? 'approved' : status === 'rejected' ? 'rejected' : 'pending',
      uploaded_at: iso(uploadedAt + random.int(0, 3) * HOUR),
      expires_at: type === 'vehicle_insurance' || type === 'driver_license' ? expiresAt : null,
      original_filename: `${type.replace(/_/g, '-')}-${random.int(1000, 9999)}.${type === 'profile_photo' ? 'jpg' : random.pick(['jpg', 'png'])}`,
      rejection_reason: status === 'rejected' ? 'The photo is too blurred to read.' : null,
    }))
  }
  for (let index = 0; index < 36; index += 1) makeVehicle('minibus', 'approved')
  for (let index = 0; index < 8; index += 1) makeVehicle('bus', 'approved')
  for (let index = 0; index < 6; index += 1) makeVehicle('coach', 'approved')
  makeVehicle('minibus', 'pending')
  makeVehicle('minibus', 'pending')
  makeVehicle('minibus', 'pending')
  makeVehicle('bus', 'pending')
  makeVehicle('coach', 'under_review')
  makeVehicle('minibus', 'rejected')
  makeVehicle('minibus', 'suspended')

  // Drivers.
  const drivers: DriverRec[] = []
  const driverStatuses: DriverRec['status'][] = [
    ...Array<DriverRec['status']>(52).fill('approved'),
    ...Array<DriverRec['status']>(6).fill('pending'),
    'under_review',
    'under_review',
    'rejected',
    'rejected',
    'suspended',
    'suspended',
  ]
  const approvedVehicles = vehicles.filter((vehicle) => vehicle.status === 'approved')
  driverStatuses.forEach((status, index) => {
    const approved = status === 'approved' || status === 'suspended'
    const createdAt = approved
      ? now - random.int(40, 420) * DAY
      : now - random.int(0, 8) * DAY - random.int(1, 20) * HOUR
    const user = makeUser(['driver'], createdAt)
    // A few licences run out soon: the fleet screen's expiry alerts.
    const licenceExpiry =
      index < 5 ? now + random.int(3, 28) * DAY : now + random.int(90, 1400) * DAY
    const vehicle =
      status === 'approved' ? (approvedVehicles[index % approvedVehicles.length] ?? null) : null
    drivers.push({
      id: random.uuid(),
      user_id: user.id,
      license_number: `DL-${random.int(100000, 999999)}-${random.int(10, 99)}`,
      license_expiry: dateOnly(licenceExpiry),
      license_class: random.weighted([
        ['C', 50],
        ['D', 35],
        ['E', 15],
      ] as const),
      years_of_experience: random.int(1, 25),
      status,
      created_at: user.created_at,
      fleet_id: vehicle?.fleet_id ?? (status === 'pending' ? null : random.pick(activeFleets).id),
      vehicle_id: vehicle?.id ?? null,
      documents: documents(
        [
          'driver_license',
          'profile_photo',
          ...(random.chance(0.6) ? (['ghana_card'] as const) : []),
        ],
        status,
        createdAt,
        dateOnly(licenceExpiry),
      ),
      info_requests: [],
      rejection_reason:
        status === 'rejected' ? 'Licence number does not match the DVLA record.' : null,
    })
    if (status === 'suspended') {
      user.is_active = false
      user.is_suspended = true
      user.suspended_at = iso(now - random.int(3, 40) * DAY)
      user.suspension_reason = 'Dangerous driving reported by several passengers.'
    }
  })
  const workingDrivers = drivers.filter((driver) => driver.status === 'approved')
  const driverByVehicle = new Map(
    workingDrivers
      .filter((driver) => driver.vehicle_id)
      .map((driver) => [driver.vehicle_id!, driver]),
  )
  const pools = {
    15: approvedVehicles.filter((vehicle) => vehicle.capacity === 15),
    33: approvedVehicles.filter((vehicle) => vehicle.capacity === 33),
    50: approvedVehicles.filter((vehicle) => vehicle.capacity === 50),
  } as Record<number, VehicleRec[]>
  const poolCursor: Record<number, number> = { 15: 0, 33: 0, 50: 0 }
  function nextVehicle(seats: number): VehicleRec {
    const pool = pools[seats]!
    const vehicle = pool[poolCursor[seats]! % pool.length]!
    poolCursor[seats] = poolCursor[seats]! + 1
    return vehicle
  }

  // ---------------------------------------------------------------- trips
  const trips: TripRec[] = []
  for (let dayOffset = -(HISTORY_DAYS - 1); dayOffset <= 1; dayOffset += 1) {
    const dayStart = today + dayOffset * DAY
    const weekday = DAY_NAMES[new Date(dayStart).getUTCDay()]!
    for (const schedule of schedules) {
      if (!schedule.days_of_week.includes(weekday)) continue
      const route = routes.find((candidate) => candidate.id === schedule.route_id)!
      const [hours = 0, minutes = 0] = schedule.departure_time.split(':').map(Number)
      const departure = dayStart + hours * HOUR + minutes * MINUTE
      const arrival = departure + route.minutes * MINUTE
      const vehicle = nextVehicle(route.seats)
      const driver = driverByVehicle.get(vehicle.id) ?? random.pick(workingDrivers)
      const trip: TripRec = {
        id: random.uuid(),
        route_id: route.id,
        schedule_id: schedule.id,
        vehicle_id: vehicle.id,
        driver_id: driver.id,
        driver_response: 'accepted',
        scheduled_departure_at: iso(departure),
        scheduled_arrival_at: iso(arrival),
        actual_departure_at: null,
        actual_arrival_at: null,
        status: 'scheduled',
        fare_amount: route.fare,
        created_at: iso(departure - random.int(3, 10) * DAY),
        live: false,
      }
      if (arrival + 20 * MINUTE < now) {
        if (random.chance(0.035)) {
          trip.status = 'cancelled'
        } else {
          const delay = random.int(0, 15) * MINUTE
          trip.status = 'completed'
          trip.actual_departure_at = iso(departure + delay)
          trip.actual_arrival_at = iso(
            departure + delay + route.minutes * MINUTE * random.float(0.9, 1.25),
          )
        }
      } else if (departure <= now) {
        trip.status = 'in_progress'
        trip.actual_departure_at = iso(departure + random.int(0, 8) * MINUTE)
      } else if (departure - 20 * MINUTE <= now) {
        trip.status = 'boarding'
      } else {
        // Ahead: not every driver has answered yet, and a few trips still
        // need a driver or a vehicle.
        const roll = random.next()
        if (roll < 0.15) trip.driver_response = 'pending'
        else if (roll < 0.19) {
          trip.driver_response = null
          trip.driver_id = null
        } else if (roll < 0.21) trip.vehicle_id = null
      }
      trips.push(trip)
    }
  }

  // Buses on the road whenever the demo is opened: one per route, part-way
  // along it, looping. Their vehicles and drivers are their own.
  const busy = new Set(
    trips.filter((trip) => trip.status === 'in_progress').map((trip) => trip.vehicle_id),
  )
  routes.forEach((route, index) => {
    const pool = pools[route.seats]!.filter((vehicle) => !busy.has(vehicle.id))
    const vehicle = pool[index % Math.max(pool.length, 1)] ?? nextVehicle(route.seats)
    busy.add(vehicle.id)
    const driver = driverByVehicle.get(vehicle.id) ?? random.pick(workingDrivers)
    const startedAgo = route.minutes * MINUTE * random.float(0.1, 0.85)
    const departed = now - startedAgo
    trips.push({
      id: random.uuid(),
      route_id: route.id,
      schedule_id: null,
      vehicle_id: vehicle.id,
      driver_id: driver.id,
      driver_response: 'accepted',
      scheduled_departure_at: iso(departed - random.int(0, 6) * MINUTE),
      scheduled_arrival_at: iso(departed + route.minutes * MINUTE),
      actual_departure_at: iso(departed),
      actual_arrival_at: null,
      status: index === 3 ? 'paused' : 'in_progress',
      fare_amount: route.fare,
      created_at: iso(departed - 4 * DAY),
      live: true,
      stale_gps: index === 9,
    })
  })

  // ------------------------------------------------- bookings and payments
  const bookings: BookingRec[] = []
  const payments: PaymentRec[] = []
  const refunds: RefundRec[] = []
  const cancellations: CancellationRec[] = []
  const ratings: RatingRec[] = []
  const routeById = new Map(routes.map((route) => [route.id, route]))
  const vehicleById = new Map(vehicles.map((vehicle) => [vehicle.id, vehicle]))
  const passengerTimes = passengers.map((user) => Date.parse(user.created_at))
  const driverQuality = new Map(drivers.map((driver) => [driver.id, random.float(3.4, 4.9)]))
  let referenceSerial = random.int(100_000, 900_000)

  function passengerFor(before: number): UserRec {
    // Anyone signed up before the booking; recent sign-ups book a bit more.
    let high = passengerTimes.length
    let low = 0
    while (low < high) {
      const middle = (low + high) >> 1
      if (passengerTimes[middle]! < before) low = middle + 1
      else high = middle
    }
    const eligible = Math.max(low, 1)
    return passengers[Math.min(Math.floor(eligible * Math.sqrt(random.next())), eligible - 1)]!
  }

  function pay(booking: BookingRec, at: number, status: PaymentRec['status']): PaymentRec {
    const channel = random.weighted(CHANNELS)
    if (status === 'successful' && random.chance(0.06)) {
      payments.push({
        id: random.uuid(),
        booking_id: booking.id,
        user_id: booking.passenger_id,
        purpose: 'booking_payment',
        channel,
        status: 'failed',
        amount: booking.total_amount,
        refunded_amount: 0,
        provider_reference: null,
        failure_reason: random.pick(PAYMENT_FAILURES),
        created_at: iso(at - 4 * MINUTE),
        completed_at: null,
      })
    }
    const payment: PaymentRec = {
      id: random.uuid(),
      booking_id: booking.id,
      user_id: booking.passenger_id,
      purpose: 'booking_payment',
      channel,
      status,
      amount: booking.total_amount,
      refunded_amount: 0,
      provider_reference:
        status === 'pending'
          ? null
          : `${channel === 'card' ? 'PSK' : 'MP'}${random.int(10_000_000, 99_999_999)}`,
      failure_reason: null,
      created_at: iso(at),
      completed_at:
        status === 'successful' || status === 'refunded'
          ? iso(at + random.int(5, 90) * 1000)
          : null,
    }
    payments.push(payment)
    return payment
  }

  for (const trip of trips) {
    const route = routeById.get(trip.route_id)!
    const vehicle = trip.vehicle_id ? vehicleById.get(trip.vehicle_id) : undefined
    const capacity = vehicle?.capacity ?? route.seats
    const departure = Date.parse(trip.scheduled_departure_at)
    const hour = new Date(departure).getUTCHours()
    const weekend = [0, 6].includes(new Date(departure).getUTCDay())
    let fill = hour < 9 || (hour >= 16 && hour < 19) ? 0.82 : 0.55
    if (weekend) fill *= 0.85
    // A young platform: demand has grown from about half of today's.
    const age = Math.min(Math.max((now - departure) / DAY, 0), HISTORY_DAYS)
    fill *= 1 - 0.55 * (age / HISTORY_DAYS)
    if (trip.status === 'scheduled') fill *= departure - now > 12 * HOUR ? 0.35 : 0.6
    if (trip.status === 'boarding') fill *= 0.85
    let seatsLeft = Math.min(capacity, Math.round(capacity * fill * random.float(0.75, 1.1)))
    const seatIds = vehicle?.seat_ids ?? []
    let seatCursor = 0
    const lastStop = route.stop_ids.length - 1

    while (seatsLeft > 0) {
      const party = Math.min(
        seatsLeft,
        random.weighted([
          [1, 70],
          [2, 22],
          [3, 8],
        ] as const),
      )
      seatsLeft -= party
      const fullRoute = random.chance(0.55)
      const origin = fullRoute ? 0 : random.int(0, lastStop - 1)
      const destination = fullRoute ? lastStop : random.int(origin + 1, lastStop)
      const share = (route.offsets_km[destination]! - route.offsets_km[origin]!) / route.distance_km
      const perSeat = Math.max(2, Math.round(route.fare * share * 2) / 2)
      const fare = round2(perSeat * party)
      const fee = round2(Math.max(0.5, fare * 0.03))
      const proposed = Math.min(departure - 10 * MINUTE, departure - random.float(0.25, 72) * HOUR)
      // Nothing is booked in the future: seats on trips ahead were booked
      // in the hours before now.
      const createdAt =
        proposed < now ? proposed : now - ((proposed - now) % (18 * HOUR)) - 5 * MINUTE
      const passenger = passengerFor(createdAt)
      referenceSerial += random.int(1, 9)

      let status: BookingRec['status']
      const roll = random.next()
      switch (trip.status) {
        case 'completed':
          status =
            roll < 0.9
              ? 'completed'
              : roll < 0.94
                ? 'cancelled'
                : roll < 0.97
                  ? 'refunded'
                  : 'expired'
          break
        case 'in_progress':
        case 'paused':
          status = 'confirmed'
          break
        case 'boarding':
          status = roll < 0.85 ? 'confirmed' : roll < 0.95 ? 'pending' : 'awaiting_acceptance'
          break
        case 'cancelled':
          status =
            roll < 0.75 ? (departure > now - 5 * DAY ? 'refund_pending' : 'refunded') : 'cancelled'
          break
        default:
          status =
            roll < 0.75
              ? 'confirmed'
              : roll < 0.87
                ? 'pending'
                : roll < 0.92
                  ? 'payment_pending'
                  : 'awaiting_acceptance'
      }

      const passengersOnBoard: BookingPassengerRec[] = Array.from({ length: party }, (_, index) => {
        const seatId = seatIds[seatCursor % Math.max(seatIds.length, 1)] ?? random.uuid()
        const label =
          vehicle?.seat_labels[seatCursor % Math.max(seatIds.length, 1)] ?? String(seatCursor + 1)
        seatCursor += 1
        const rode =
          status === 'completed' || (status === 'confirmed' && trip.actual_departure_at !== null)
        return {
          id: random.uuid(),
          seat_id: seatId,
          seat_label: label,
          full_name: index === 0 ? passenger.full_name : personName(random),
          phone_number: index === 0 ? passenger.phone_number : null,
          boarded_at: rode ? iso(departure + random.int(-15, 2) * MINUTE) : null,
          alighted_at: status === 'completed' ? trip.actual_arrival_at : null,
        }
      })

      const booking: BookingRec = {
        id: random.uuid(),
        reference: `TRK-${referenceSerial.toString(36).toUpperCase().padStart(8, '0')}`,
        passenger_id: passenger.id,
        trip_id: trip.id,
        status,
        origin_index: origin,
        destination_index: destination,
        passenger_count: party,
        fare_amount: fare,
        platform_fee: fee,
        total_amount: round2(fare + fee),
        created_at: iso(createdAt),
        expires_at:
          status === 'pending' || status === 'payment_pending'
            ? iso(Math.max(now + random.int(2, 9) * MINUTE, createdAt + 10 * MINUTE))
            : status === 'awaiting_acceptance'
              ? iso(now + random.int(30, 110) * 1000)
              : null,
        passengers: passengersOnBoard,
      }
      bookings.push(booking)

      const paidAt = Math.min(createdAt + random.int(1, 9) * MINUTE, now - 30 * 1000)
      if (['confirmed', 'completed'].includes(status)) {
        pay(booking, paidAt, 'successful')
      } else if (status === 'payment_pending') {
        pay(booking, paidAt, 'pending')
      } else if (status === 'refunded' || status === 'refund_pending') {
        const payment = pay(booking, paidAt, status === 'refunded' ? 'refunded' : 'successful')
        if (status === 'refunded') payment.refunded_amount = payment.amount
        const decided = status === 'refunded'
        const requestedAt = Math.min(now - HOUR, departure - random.int(1, 20) * HOUR)
        refunds.push({
          id: random.uuid(),
          payment_id: payment.id,
          booking_id: booking.id,
          amount: payment.amount,
          reason:
            trip.status === 'cancelled'
              ? 'Trip cancelled by the operator.'
              : 'Cancelled by the passenger before departure.',
          status: decided ? 'completed' : 'pending',
          reviewed_by: decided ? random.pick(adminIds) : null,
          reviewed_at: decided ? iso(requestedAt + random.int(1, 30) * HOUR) : null,
          decision_notes: decided ? 'Refund approved.' : null,
          provider_refund_reference: decided ? `RF${random.int(10_000_000, 99_999_999)}` : null,
          failure_reason: null,
          created_at: iso(requestedAt),
        })
      }

      if (status === 'completed' && trip.driver_id && random.chance(0.32)) {
        const base = driverQuality.get(trip.driver_id) ?? 4.2
        const score = () => Math.min(5, Math.max(1, Math.round(base + random.float(-1.2, 0.9))))
        const parts = [score(), score(), score(), score()] as const
        ratings.push({
          id: random.uuid(),
          booking_id: booking.id,
          trip_id: trip.id,
          driver_id: trip.driver_id,
          passenger_id: passenger.id,
          overall: Math.round((parts[0] + parts[1] + parts[2] + parts[3]) / 4),
          safety: parts[0],
          cleanliness: parts[1],
          professionalism: parts[2],
          timeliness: parts[3],
          comment: random.pick(RATING_COMMENTS),
          created_at: iso(
            Date.parse(trip.actual_arrival_at ?? trip.scheduled_arrival_at) +
              random.int(5, 600) * MINUTE,
          ),
        })
      }
    }
  }

  // Refund requests waiting for an admin, and a few turned down.
  for (const booking of random.sample(
    bookings.filter(
      (candidate) =>
        candidate.status === 'completed' && Date.parse(candidate.created_at) > now - 20 * DAY,
    ),
    4,
  )) {
    const payment = payments.find(
      (candidate) => candidate.booking_id === booking.id && candidate.status === 'successful',
    )
    if (!payment) continue
    refunds.push({
      id: random.uuid(),
      payment_id: payment.id,
      booking_id: booking.id,
      amount: payment.amount,
      reason: random.pick([
        'The bus broke down and I had to take a taxi.',
        'Charged twice for the same booking.',
        'Driver refused to stop at my destination.',
      ]),
      status: 'rejected',
      reviewed_by: random.pick(adminIds),
      reviewed_at: iso(now - random.int(1, 15) * DAY),
      decision_notes: 'The trip was completed as booked; no refund is due.',
      provider_refund_reference: null,
      failure_reason: null,
      created_at: iso(now - random.int(16, 19) * DAY),
    })
  }

  // Cancellations asked for after departure, waiting for a decision.
  const onTheRoad = new Set(
    trips.filter((trip) => ['in_progress', 'paused'].includes(trip.status)).map((trip) => trip.id),
  )
  for (const booking of random.sample(
    bookings.filter(
      (candidate) => candidate.status === 'confirmed' && onTheRoad.has(candidate.trip_id),
    ),
    5,
  )) {
    cancellations.push({
      id: random.uuid(),
      booking_id: booking.id,
      requested_by: booking.passenger_id,
      reason: random.pick([
        'I had an emergency and could not travel.',
        'The bus left without me although I was at the station.',
        'Wrong date booked by mistake.',
      ]),
      status: 'pending',
      refund_eligible: false,
      decided_by: null,
      decided_at: null,
      decision_notes: null,
      created_at: iso(now - random.int(10, 240) * MINUTE),
    })
  }

  // --------------------------------------------------------------- payouts
  const withdrawals: WithdrawalRec[] = []
  for (let index = 0; index < 46; index += 1) {
    const driver = random.pick(workingDrivers)
    const user = users.find((candidate) => candidate.id === driver.user_id)!
    const daysAgo = index < 7 ? random.float(0, 2) : random.float(2, 88)
    const createdAt = now - daysAgo * DAY
    const status: WithdrawalRec['status'] =
      index < 6
        ? 'pending'
        : index < 9
          ? 'approved'
          : random.weighted([
              ['completed', 80],
              ['failed', 8],
              ['rejected', 12],
            ] as const)
    const reviewer = random.pick(adminIds)
    const reviewedAt = createdAt + random.int(1, 20) * HOUR
    const history: WithdrawalRec['history'] = [
      { status: 'pending', at: iso(createdAt), by: driver.user_id, note: null },
    ]
    if (status !== 'pending') {
      history.push({
        status: status === 'rejected' ? 'rejected' : 'approved',
        at: iso(reviewedAt),
        by: reviewer,
        note:
          status === 'rejected'
            ? 'The destination number does not match the driver’s account.'
            : null,
      })
    }
    if (status === 'completed' || status === 'failed') {
      history.push({
        status,
        at: iso(reviewedAt + random.int(1, 6) * HOUR),
        by: reviewer,
        note: status === 'failed' ? 'MTN MoMo rejected the transfer: wallet limit reached.' : null,
      })
    }
    withdrawals.push({
      id: random.uuid(),
      user_id: driver.user_id,
      amount: round2(random.int(8, 90) * 10 + random.int(0, 9)),
      channel: random.weighted([
        ['mtn_momo', 70],
        ['telecel_cash', 20],
        ['airteltigo_money', 10],
      ] as const),
      destination_phone_number: user.phone_number,
      status,
      reviewed_by: status === 'pending' ? null : reviewer,
      reviewed_at: status === 'pending' ? null : iso(reviewedAt),
      decision_notes: history[1]?.note ?? null,
      provider_reference:
        status === 'completed' ? `MT${random.int(100_000_000, 999_999_999)}` : null,
      failure_reason:
        status === 'failed' ? 'MTN MoMo rejected the transfer: wallet limit reached.' : null,
      created_at: iso(createdAt),
      history,
    })
  }

  // ---------------------------------------------------- complaints & safety
  const complaints: ComplaintRec[] = []
  const SLA_HOURS: Record<ComplaintRec['priority'], number> = {
    urgent: 4,
    high: 24,
    medium: 48,
    low: 72,
  }
  const completedBookings = bookings.filter((booking) => booking.status === 'completed')
  for (let index = 0; index < 72; index += 1) {
    const category = random.weighted([
      ['driver_conduct', 30],
      ['vehicle_condition', 18],
      ['safety', 12],
      ['payment', 22],
      ['other', 18],
    ] as const)
    const [subject, description] = random.pick(COMPLAINTS[category])
    const recent = index < 14
    const createdAt = now - (recent ? random.float(0.05, 4) : random.float(4, 88)) * DAY
    const booking = random.pick(completedBookings)
    const priority: ComplaintRec['priority'] =
      category === 'safety'
        ? random.pick(['high', 'urgent'] as const)
        : random.pick(['low', 'medium', 'medium', 'high'] as const)
    const status: ComplaintRec['status'] = recent
      ? random.pick(['open', 'open', 'in_review'] as const)
      : random.weighted([
          ['resolved', 78],
          ['dismissed', 14],
          ['in_review', 8],
        ] as const)
    const assigned = status !== 'open' || random.chance(0.4)
    const assignee = assigned ? random.pick(adminIds) : null
    const closed = status === 'resolved' || status === 'dismissed'
    complaints.push({
      id: random.uuid(),
      filed_by: booking.passenger_id,
      booking_id: booking.id,
      trip_id: booking.trip_id,
      category,
      subject,
      description,
      status,
      priority,
      resolved_by: closed ? assignee : null,
      resolved_at: closed ? iso(createdAt + random.float(2, 60) * HOUR) : null,
      resolution_notes: closed
        ? status === 'resolved'
          ? 'We spoke to the driver and the fleet owner; a warning has been recorded.'
          : 'Duplicate of an earlier complaint.'
        : null,
      assigned_to: assignee,
      assigned_at: assignee ? iso(createdAt + random.float(0.2, 6) * HOUR) : null,
      first_response_at: status === 'open' ? null : iso(createdAt + random.float(0.5, 20) * HOUR),
      due_at: iso(createdAt + SLA_HOURS[priority] * HOUR),
      created_at: iso(createdAt),
      notes: [],
    })
  }

  const incidents: IncidentRec[] = []
  const pastTrips = trips.filter((trip) => trip.status === 'completed' && trip.driver_id)
  for (let index = 0; index < 32; index += 1) {
    const type = random.weighted([
      ['delay', 30],
      ['breakdown', 20],
      ['road_hazard', 15],
      ['passenger_issue', 15],
      ['safety_concern', 10],
      ['accident', 5],
      ['other', 5],
    ] as const)
    const recent = index < 5
    const trip = recent
      ? random.pick(trips.filter((candidate) => onTheRoad.has(candidate.id)))
      : random.pick(pastTrips)
    const createdAt = recent
      ? now - random.float(0.2, 30) * HOUR
      : Date.parse(trip.actual_departure_at ?? trip.scheduled_departure_at) +
        random.int(5, 90) * MINUTE
    const status: IncidentRec['status'] = recent
      ? random.pick(['reported', 'in_review'] as const)
      : random.weighted([
          ['resolved', 70],
          ['closed', 25],
          ['in_review', 5],
        ] as const)
    const done = status === 'resolved' || status === 'closed'
    const driver = drivers.find((candidate) => candidate.id === trip.driver_id)
    incidents.push({
      id: random.uuid(),
      trip_id: trip.id,
      reported_by: driver?.user_id ?? random.pick(passengers).id,
      incident_type: type,
      severity:
        type === 'accident' || type === 'safety_concern'
          ? random.pick(['high', 'critical'] as const)
          : random.pick(['low', 'medium', 'medium'] as const),
      description: random.pick(INCIDENTS[type]),
      status,
      resolved_by: done ? random.pick(adminIds) : null,
      resolved_at: done ? iso(createdAt + random.float(1, 30) * HOUR) : null,
      resolution_notes: done ? 'Spoke to the driver; the trip carried on safely.' : null,
      created_at: iso(createdAt),
    })
  }

  const sosAlerts: SosRec[] = []
  const liveTrips = trips.filter((trip) => trip.live)
  for (let index = 0; index < 16; index += 1) {
    const current = index === 0 || index === 1
    const trip = current ? liveTrips[index + 5]! : random.pick(pastTrips)
    const route = routeById.get(trip.route_id)!
    const stopId = random.pick(route.stop_ids)
    const stop = stops.find((candidate) => candidate.id === stopId)!
    const createdAt = current
      ? now - (index === 0 ? 3 : 42) * MINUTE
      : Date.parse(trip.actual_departure_at ?? trip.scheduled_departure_at) +
        random.int(5, 60) * MINUTE
    const tripBookings = bookings.filter((booking) => booking.trip_id === trip.id)
    const triggeredBy = tripBookings.length
      ? random.pick(tripBookings).passenger_id
      : random.pick(passengers).id
    const status: SosRec['status'] =
      index === 0
        ? 'active'
        : index === 1
          ? 'acknowledged'
          : random.chance(0.35)
            ? 'false_alarm'
            : 'resolved'
    const handler = random.pick(adminIds)
    const done = status === 'resolved' || status === 'false_alarm'
    sosAlerts.push({
      id: random.uuid(),
      trip_id: trip.id,
      triggered_by: triggeredBy,
      status,
      latitude: stop.latitude + random.float(-0.01, 0.01),
      longitude: stop.longitude + random.float(-0.01, 0.01),
      acknowledged_by: status === 'active' ? null : handler,
      acknowledged_at: status === 'active' ? null : iso(createdAt + random.int(1, 4) * MINUTE),
      resolved_by: done ? handler : null,
      resolved_at: done ? iso(createdAt + random.int(15, 90) * MINUTE) : null,
      resolution_notes: done
        ? status === 'false_alarm'
          ? 'Pressed by mistake; the passenger confirmed by phone that all is well.'
          : 'Police met the bus at the next stop; the passenger is safe.'
        : null,
      created_at: iso(createdAt),
      escalations:
        status === 'acknowledged' || (done && random.chance(0.4))
          ? [
              {
                id: random.uuid(),
                contact_type: 'police',
                contact_name: 'Ghana Police Service, MTTD',
                phone_number: '191',
                contacted_at: iso(createdAt + 6 * MINUTE),
                notes: 'Gave them the bus’s position and registration.',
                logged_by: handler,
                created_at: iso(createdAt + 7 * MINUTE),
              },
            ]
          : [],
    })
  }

  // ------------------------------------------------- dispatch and its log
  const offers: OfferRec[] = []
  const tripById = new Map(trips.map((trip) => [trip.id, trip]))
  for (const booking of bookings) {
    if (booking.status !== 'awaiting_acceptance') continue
    const trip = tripById.get(booking.trip_id)!
    offers.push({
      id: random.uuid(),
      booking_id: booking.id,
      trip_id: trip.id,
      driver_id: trip.driver_id,
      status: 'pending',
      expires_at: booking.expires_at ?? iso(now + 90 * 1000),
      decided_at: null,
      decided_by: null,
      reason: null,
      created_at: iso(Date.parse(booking.expires_at ?? iso(now)) - 120 * 1000),
    })
  }
  const driverActions: DriverActionRec[] = []
  const driverUser = new Map(drivers.map((driver) => [driver.id, driver.user_id]))
  const bookingsOnTrip = new Map<string, BookingRec[]>()
  for (const booking of bookings) {
    const list = bookingsOnTrip.get(booking.trip_id)
    if (list) list.push(booking)
    else bookingsOnTrip.set(booking.trip_id, [booking])
  }
  const recent = trips.filter(
    (trip) =>
      trip.driver_id &&
      Date.parse(trip.scheduled_departure_at) > now - 2 * DAY &&
      Date.parse(trip.scheduled_departure_at) < now + DAY,
  )
  for (const trip of recent) {
    const driverId = trip.driver_id!
    const actor = driverUser.get(driverId) ?? null
    const departure = Date.parse(trip.scheduled_departure_at)
    const log = (kind: DriverActionRec['kind'], at: number, extra: Partial<DriverActionRec> = {}) =>
      driverActions.push({
        id: random.uuid(),
        driver_id: driverId,
        trip_id: trip.id,
        booking_id: null,
        kind,
        acted_as: 'driver',
        actor_id: actor,
        reason: null,
        details: null,
        created_at: iso(Math.min(at, now - 1000)),
        ...extra,
      })
    if (trip.driver_response === 'accepted') {
      // Drivers answer hours ahead; for trips soon after the demo's "now", earlier today.
      const answered = departure - random.float(2, 30) * HOUR
      log('trip_accepted', answered < now ? answered : now - random.float(0.5, 14) * HOUR)
    }
    if (trip.actual_departure_at) log('trip_started', Date.parse(trip.actual_departure_at))
    if (trip.status === 'paused')
      log('trip_paused', now - random.int(3, 20) * MINUTE, { reason: 'Fuel stop' })
    for (const booking of (bookingsOnTrip.get(trip.id) ?? []).slice(0, 3)) {
      if (booking.status === 'confirmed' || booking.status === 'completed') {
        log('booking_accepted', Date.parse(booking.created_at) + random.int(8, 110) * 1000, {
          booking_id: booking.id,
        })
      }
      const boarded = booking.passengers[0]?.boarded_at
      if (boarded) {
        log('ticket_scanned', Date.parse(boarded), {
          booking_id: booking.id,
          details: { ticket_reference: `TKT-${booking.reference.slice(4)}` },
        })
      }
    }
    if (trip.actual_arrival_at) log('trip_ended', Date.parse(trip.actual_arrival_at))
  }
  // A few answers worth an admin's eye: declines, and requests nobody took.
  for (const trip of random.sample(
    recent.filter((trip) => trip.status === 'scheduled'),
    4,
  )) {
    driverActions.push({
      id: random.uuid(),
      driver_id: trip.driver_id,
      trip_id: trip.id,
      booking_id: null,
      kind: 'trip_declined',
      acted_as: 'driver',
      actor_id: driverUser.get(trip.driver_id!) ?? null,
      reason: random.pick(['My car is at the mechanic.', 'Family emergency.', 'Not feeling well.']),
      details: null,
      created_at: iso(now - random.float(1, 30) * HOUR),
    })
  }
  for (const booking of random.sample(
    bookings.filter((candidate) => candidate.status === 'expired'),
    5,
  )) {
    const trip = tripById.get(booking.trip_id)!
    driverActions.push({
      id: random.uuid(),
      driver_id: trip.driver_id,
      trip_id: trip.id,
      booking_id: booking.id,
      kind: 'booking_unanswered',
      acted_as: 'system',
      actor_id: null,
      reason: null,
      details: null,
      created_at: iso(now - random.float(1, 40) * HOUR),
    })
  }
  driverActions.sort((a, b) => b.created_at.localeCompare(a.created_at))

  // One trip that never started, its departure time 25 minutes gone: nobody
  // was found to drive it or, as there isn't always such a trip ahead, its
  // driver never answered. The team is alerted (trip_not_started). Done
  // last, drawing nothing random, so the rest of the demo is the same as
  // without it.
  const ahead = trips
    .filter((trip) => trip.status === 'scheduled' && Date.parse(trip.scheduled_departure_at) > now)
    .sort((a, b) => a.scheduled_departure_at.localeCompare(b.scheduled_departure_at))
  const unstarted =
    ahead.find((trip) => trip.driver_id === null) ??
    ahead.find((trip) => trip.driver_response === 'pending')
  if (unstarted) {
    const takes =
      Date.parse(unstarted.scheduled_arrival_at) - Date.parse(unstarted.scheduled_departure_at)
    unstarted.scheduled_departure_at = iso(now - 25 * MINUTE)
    unstarted.scheduled_arrival_at = iso(now - 25 * MINUTE + takes)
  }

  return {
    builtAt: now,
    users,
    stops,
    routes,
    schedules,
    fleetOwners,
    fleets,
    vehicles,
    drivers,
    trips,
    bookings,
    payments,
    refunds,
    cancellations,
    withdrawals,
    complaints,
    incidents,
    sosAlerts,
    ratings,
    offers,
    driverActions,
  }
}
