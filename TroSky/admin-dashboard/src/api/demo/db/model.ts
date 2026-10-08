import type { Schemas } from '@/api/types'

/**
 * The demo platform's records. Fields mirror the API's where they map one
 * to one, so handlers mostly pass them through; derived views (lists,
 * details, analytics) are computed in the handlers.
 */

export type Iso = string
type Enum<K extends keyof Schemas> = Schemas[K]

export interface UserRec {
  id: string
  full_name: string
  phone_number: string
  email: string | null
  roles: ('passenger' | 'driver' | 'fleet_owner')[]
  city: string
  created_at: Iso
  last_login_at: Iso | null
  is_active: boolean
  is_suspended: boolean
  suspended_at: Iso | null
  suspension_reason: string | null
  phone_verified: boolean
  email_verified: boolean
}

export interface StopRec {
  id: string
  key: string
  name: string
  code: string
  address: string | null
  city: string
  region: string
  latitude: number
  longitude: number
  is_active: boolean
}

export interface RouteRec {
  id: string
  name: string
  stop_ids: string[]
  /** Km from the first stop, per stop. */
  offsets_km: number[]
  distance_km: number
  minutes: number
  fare: number
  vehicle_type: 'minibus' | 'bus'
  seats: number
  city: string
  is_active: boolean
  created_at: Iso
}

export interface ScheduleRec {
  id: string
  route_id: string
  departure_time: string
  days_of_week: Enum<'DayOfWeek'>[]
  fare_amount: number
  is_active: boolean
}

export interface DocumentRec {
  id: string
  document_type: Enum<'DocumentType'>
  status: Enum<'DocumentStatus'>
  uploaded_at: Iso
  expires_at: string | null
  original_filename: string
  rejection_reason: string | null
}

export interface InfoRequestRec {
  document_types: Enum<'DocumentType'>[]
  note: string
  documents_returned: string[]
  requested_at: Iso
  requested_by: string
}

export interface FleetOwnerRec {
  id: string
  user_id: string
  business_name: string
  status: Enum<'ApprovalStatus'>
  created_at: Iso
}

export interface FleetRec {
  id: string
  owner_id: string
  name: string
  city: string
  created_at: Iso
}

export interface VehicleRec {
  id: string
  fleet_id: string
  registration_number: string
  vehicle_type: 'minibus' | 'bus'
  make: string
  model: string
  year: number
  capacity: number
  status: Enum<'ApprovalStatus'>
  created_at: Iso
  seat_ids: string[]
  seat_labels: string[]
  insurance_expiry: string
  roadworthy_expiry: string
  documents: DocumentRec[]
  info_requests: InfoRequestRec[]
  rejection_reason: string | null
}

export interface DriverRec {
  id: string
  user_id: string
  license_number: string
  license_expiry: string
  license_class: string
  years_of_experience: number
  status: Enum<'ApprovalStatus'>
  created_at: Iso
  fleet_id: string | null
  vehicle_id: string | null
  documents: DocumentRec[]
  info_requests: InfoRequestRec[]
  rejection_reason: string | null
}

export interface TripRec {
  id: string
  route_id: string
  schedule_id: string | null
  vehicle_id: string | null
  driver_id: string | null
  driver_response: 'pending' | 'accepted' | 'declined' | null
  scheduled_departure_at: Iso
  scheduled_arrival_at: Iso
  actual_departure_at: Iso | null
  actual_arrival_at: Iso | null
  status: Enum<'TripStatus'>
  fare_amount: number
  created_at: Iso
  /** Always on the road in the demo: it loops along its route. */
  live: boolean
  /** Its phone stopped reporting a few minutes ago. */
  stale_gps?: boolean
}

export interface BookingPassengerRec {
  id: string
  seat_id: string
  seat_label: string
  full_name: string
  phone_number: string | null
  boarded_at: Iso | null
  alighted_at: Iso | null
}

export interface BookingRec {
  id: string
  reference: string
  passenger_id: string
  trip_id: string
  status: Enum<'BookingStatus'>
  /** Index into the route's stops. */
  origin_index: number
  destination_index: number
  passenger_count: number
  fare_amount: number
  platform_fee: number
  total_amount: number
  created_at: Iso
  expires_at: Iso | null
  passengers: BookingPassengerRec[]
}

export interface PaymentRec {
  id: string
  booking_id: string | null
  user_id: string
  purpose: Enum<'PaymentPurpose'>
  channel: Enum<'PaymentChannel'>
  status: Enum<'PaymentStatus'>
  amount: number
  refunded_amount: number
  provider_reference: string | null
  failure_reason: string | null
  created_at: Iso
  completed_at: Iso | null
}

export interface RefundRec {
  id: string
  payment_id: string
  booking_id: string | null
  amount: number
  reason: string | null
  status: Enum<'RefundStatus'>
  reviewed_by: string | null
  reviewed_at: Iso | null
  decision_notes: string | null
  provider_refund_reference: string | null
  failure_reason: string | null
  created_at: Iso
}

export interface CancellationRec {
  id: string
  booking_id: string
  requested_by: string | null
  reason: string | null
  status: Enum<'CancellationStatus'>
  refund_eligible: boolean
  decided_by: string | null
  decided_at: Iso | null
  decision_notes: string | null
  created_at: Iso
}

export interface WithdrawalRec {
  id: string
  user_id: string
  amount: number
  channel: Enum<'PaymentChannel'>
  destination_phone_number: string
  status: Enum<'WithdrawalStatus'>
  reviewed_by: string | null
  reviewed_at: Iso | null
  decision_notes: string | null
  provider_reference: string | null
  failure_reason: string | null
  created_at: Iso
  /** Status changes, oldest first, for the payout drawer. */
  history: { status: Enum<'WithdrawalStatus'>; at: Iso; by: string | null; note: string | null }[]
}

export interface ComplaintNoteRec {
  id: string
  kind: 'internal' | 'message'
  body: string
  author_id: string | null
  created_at: Iso
}

export interface ComplaintRec {
  id: string
  filed_by: string
  booking_id: string | null
  trip_id: string | null
  category: Enum<'ComplaintCategory'>
  subject: string
  description: string
  status: Enum<'ComplaintStatus'>
  priority: Enum<'ComplaintPriority'>
  resolved_by: string | null
  resolved_at: Iso | null
  resolution_notes: string | null
  assigned_to: string | null
  assigned_at: Iso | null
  first_response_at: Iso | null
  due_at: Iso
  created_at: Iso
  notes: ComplaintNoteRec[]
}

export interface IncidentRec {
  id: string
  trip_id: string
  reported_by: string
  incident_type: Enum<'IncidentType'>
  severity: Enum<'IncidentSeverity'>
  description: string
  status: Enum<'IncidentStatus'>
  resolved_by: string | null
  resolved_at: Iso | null
  resolution_notes: string | null
  created_at: Iso
}

export interface SosEscalationRec {
  id: string
  contact_type: Enum<'EscalationContactType'>
  contact_name: string | null
  phone_number: string | null
  contacted_at: Iso
  notes: string | null
  logged_by: string | null
  created_at: Iso
}

export interface SosRec {
  id: string
  trip_id: string | null
  triggered_by: string
  status: Enum<'SosAlertStatus'>
  latitude: number | null
  longitude: number | null
  acknowledged_by: string | null
  acknowledged_at: Iso | null
  resolved_by: string | null
  resolved_at: Iso | null
  resolution_notes: string | null
  created_at: Iso
  escalations: SosEscalationRec[]
}

export interface RatingRec {
  id: string
  booking_id: string
  trip_id: string
  driver_id: string
  passenger_id: string
  overall: number
  safety: number
  cleanliness: number
  professionalism: number
  timeliness: number
  comment: string | null
  created_at: Iso
}

export interface OfferRec {
  id: string
  booking_id: string
  trip_id: string
  driver_id: string | null
  status: 'pending' | 'accepted' | 'declined' | 'expired' | 'withdrawn'
  expires_at: Iso
  decided_at: Iso | null
  decided_by: string | null
  reason: string | null
  created_at: Iso
}

export interface DriverActionRec {
  id: string
  driver_id: string | null
  trip_id: string
  booking_id: string | null
  kind: Enum<'DriverActionKind'>
  acted_as: Enum<'ActedAs'>
  actor_id: string | null
  reason: string | null
  details: Record<string, unknown> | null
  created_at: Iso
}
