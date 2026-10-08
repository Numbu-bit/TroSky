import type { Schemas } from '@/api/types'
import type { Tone } from '@/components/status/StatusBadge'

import type { DocumentType, QueueKind } from './api'

export const DOCUMENT_LABELS: Record<DocumentType, string> = {
  driver_license: 'Driver’s licence',
  profile_photo: 'Profile photo',
  ghana_card: 'Ghana Card',
  police_report: 'Police report',
  vehicle_registration: 'Vehicle registration',
  vehicle_insurance: 'Insurance certificate',
  roadworthiness_certificate: 'Roadworthiness certificate',
  other: 'Other document',
}

export const DOCUMENT_STATUS: Record<Schemas['DocumentStatus'], { tone: Tone; label: string }> = {
  pending: { tone: 'warning', label: 'To check' },
  under_review: { tone: 'info', label: 'Being checked' },
  approved: { tone: 'success', label: 'Accepted' },
  rejected: { tone: 'danger', label: 'Asked again' },
  expired: { tone: 'danger', label: 'Expired' },
}

/** The documents each kind of application should have (FR-004). */
export const EXPECTED: Record<QueueKind, { type: DocumentType; required: boolean }[]> = {
  drivers: [
    { type: 'driver_license', required: true },
    { type: 'profile_photo', required: true },
    { type: 'ghana_card', required: false },
  ],
  vehicles: [
    { type: 'vehicle_registration', required: true },
    { type: 'vehicle_insurance', required: true },
    { type: 'roadworthiness_certificate', required: true },
  ],
}

/** What the reviewer confirms before approving. Kept on this screen only. */
export const CHECKLISTS: Record<QueueKind, { id: string; label: string }[]> = {
  drivers: [
    {
      id: 'licence-readable',
      label: 'The licence is readable and its name matches the applicant.',
    },
    {
      id: 'licence-valid',
      label: 'The licence is in date and its class allows commercial passenger driving.',
    },
    { id: 'photo', label: 'The profile photo clearly shows the person on the licence.' },
    { id: 'identity', label: 'The Ghana Card, if uploaded, matches the name and the photo.' },
    { id: 'experience', label: 'The years of experience fit the licence.' },
  ],
  vehicles: [
    { id: 'registration', label: 'The registration matches the plate, make and model.' },
    { id: 'insurance', label: 'The insurance covers commercial passengers and is in date.' },
    { id: 'roadworthy', label: 'The roadworthiness certificate is in date.' },
    { id: 'capacity', label: 'The seat count fits the vehicle type.' },
  ],
}
