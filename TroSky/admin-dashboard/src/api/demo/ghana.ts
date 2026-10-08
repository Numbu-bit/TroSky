import type { Random } from './random'

/**
 * Realistic, fictitious Ghanaian data: names, stations and lorry parks with
 * their real positions, Ghana-format plates, and phone numbers in the
 * reserved +233 24 000 xxxx block so none belongs to anyone.
 */

export const MALE_NAMES = [
  'Kwame',
  'Kofi',
  'Kwabena',
  'Kwaku',
  'Yaw',
  'Kwasi',
  'Kojo',
  'Ekow',
  'Fiifi',
  'Nii',
  'Selorm',
  'Elikem',
  'Mawuli',
  'Kweku',
  'Nana',
  'Edem',
  'Kobina',
  'Papa',
  'Yaw',
  'Kwadwo',
] as const

export const FEMALE_NAMES = [
  'Ama',
  'Akua',
  'Abena',
  'Adwoa',
  'Yaa',
  'Afia',
  'Esi',
  'Efua',
  'Araba',
  'Aba',
  'Naa',
  'Dzifa',
  'Akosua',
  'Adjoa',
  'Afua',
  'Ekua',
  'Akorfa',
  'Esinam',
  'Maame',
  'Akweley',
] as const

export const SURNAMES = [
  'Mensah',
  'Owusu',
  'Boateng',
  'Asante',
  'Osei',
  'Agyeman',
  'Ofori',
  'Darko',
  'Appiah',
  'Addo',
  'Tetteh',
  'Quaye',
  'Lamptey',
  'Amoah',
  'Badu',
  'Nkansah',
  'Frimpong',
  'Acheampong',
  'Sarpong',
  'Gyamfi',
  'Ansah',
  'Adjei',
  'Bonsu',
  'Kyei',
  'Opoku',
  'Wiredu',
  'Annor',
  'Ampofo',
  'Danquah',
  'Okyere',
  'Aidoo',
  'Arthur',
  'Quartey',
  'Odoi',
  'Agbeko',
  'Kumah',
  'Dogbe',
] as const

export interface Station {
  key: string
  name: string
  city: string
  region: string
  latitude: number
  longitude: number
}

export const STATIONS: Station[] = [
  {
    key: 'circle',
    name: 'Circle',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.5701,
    longitude: -0.2129,
  },
  {
    key: 'madina',
    name: 'Madina',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.673,
    longitude: -0.167,
  },
  {
    key: 'kaneshie',
    name: 'Kaneshie',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.5667,
    longitude: -0.237,
  },
  {
    key: 'kasoa',
    name: 'Kasoa',
    city: 'Kasoa',
    region: 'Central',
    latitude: 5.534,
    longitude: -0.417,
  },
  {
    key: 'achimota',
    name: 'Achimota',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.62,
    longitude: -0.228,
  },
  {
    key: 'tema-station',
    name: 'Tema Station',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.546,
    longitude: -0.208,
  },
  {
    key: 'lapaz',
    name: 'Lapaz',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.604,
    longitude: -0.252,
  },
  {
    key: 'adenta',
    name: 'Adenta',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.709,
    longitude: -0.153,
  },
  {
    key: 'legon',
    name: 'Legon',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.65,
    longitude: -0.187,
  },
  {
    key: 'east-legon',
    name: 'East Legon',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.637,
    longitude: -0.16,
  },
  {
    key: 'spintex',
    name: 'Spintex',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.628,
    longitude: -0.106,
  },
  {
    key: 'dansoman',
    name: 'Dansoman',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.542,
    longitude: -0.265,
  },
  {
    key: 'teshie',
    name: 'Teshie',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.583,
    longitude: -0.105,
  },
  {
    key: 'mallam',
    name: 'Mallam',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.57,
    longitude: -0.283,
  },
  {
    key: 'weija',
    name: 'Weija',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.56,
    longitude: -0.335,
  },
  {
    key: 'ofankor',
    name: 'Ofankor',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.66,
    longitude: -0.265,
  },
  {
    key: 'amasaman',
    name: 'Amasaman',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.703,
    longitude: -0.3,
  },
  {
    key: '37',
    name: '37 Station',
    city: 'Accra',
    region: 'Greater Accra',
    latitude: 5.588,
    longitude: -0.183,
  },
  {
    key: 'tema',
    name: 'Tema Community 1',
    city: 'Tema',
    region: 'Greater Accra',
    latitude: 5.6698,
    longitude: -0.0166,
  },
  {
    key: 'kejetia',
    name: 'Kejetia',
    city: 'Kumasi',
    region: 'Ashanti',
    latitude: 6.697,
    longitude: -1.623,
  },
  {
    key: 'nkawkaw',
    name: 'Nkawkaw',
    city: 'Nkawkaw',
    region: 'Eastern',
    latitude: 6.551,
    longitude: -0.766,
  },
  {
    key: 'konongo',
    name: 'Konongo',
    city: 'Konongo',
    region: 'Ashanti',
    latitude: 6.617,
    longitude: -1.216,
  },
  {
    key: 'winneba',
    name: 'Winneba',
    city: 'Winneba',
    region: 'Central',
    latitude: 5.35,
    longitude: -0.623,
  },
  {
    key: 'mankessim',
    name: 'Mankessim',
    city: 'Mankessim',
    region: 'Central',
    latitude: 5.27,
    longitude: -1.016,
  },
  {
    key: 'cape-coast',
    name: 'Cape Coast',
    city: 'Cape Coast',
    region: 'Central',
    latitude: 5.1053,
    longitude: -1.2466,
  },
]

/** Corridors: stops in order; each runs both ways. */
export const CORRIDORS: {
  stops: string[]
  fare: number
  minutes: number
  vehicle: 'minibus' | 'bus' | 'coach'
}[] = [
  { stops: ['circle', '37', 'legon', 'madina'], fare: 8, minutes: 45, vehicle: 'minibus' },
  { stops: ['kaneshie', 'mallam', 'weija', 'kasoa'], fare: 10, minutes: 55, vehicle: 'minibus' },
  {
    stops: ['tema-station', 'circle', 'lapaz', 'achimota'],
    fare: 7,
    minutes: 40,
    vehicle: 'minibus',
  },
  { stops: ['circle', 'nkawkaw', 'konongo', 'kejetia'], fare: 120, minutes: 300, vehicle: 'coach' },
  {
    stops: ['circle', '37', 'east-legon', 'madina', 'adenta'],
    fare: 10,
    minutes: 55,
    vehicle: 'minibus',
  },
  { stops: ['tema-station', '37', 'teshie'], fare: 7, minutes: 40, vehicle: 'minibus' },
  { stops: ['kaneshie', 'dansoman'], fare: 5, minutes: 25, vehicle: 'minibus' },
  {
    stops: ['kaneshie', 'kasoa', 'winneba', 'mankessim', 'cape-coast'],
    fare: 70,
    minutes: 180,
    vehicle: 'bus',
  },
  { stops: ['achimota', 'ofankor', 'amasaman'], fare: 6, minutes: 35, vehicle: 'minibus' },
  { stops: ['madina', 'east-legon', 'spintex', 'tema'], fare: 9, minutes: 50, vehicle: 'minibus' },
]

export function stationByKey(key: string): Station {
  const station = STATIONS.find((candidate) => candidate.key === key)
  if (!station) throw new Error(`Unknown station ${key}`)
  return station
}

export function personName(random: Random, gender?: 'm' | 'f'): string {
  const female = gender ? gender === 'f' : random.chance(0.5)
  return `${random.pick(female ? FEMALE_NAMES : MALE_NAMES)} ${random.pick(SURNAMES)}`
}

/** +233 24 000 xxxx: fictitious, by construction. */
export function demoPhone(serial: number): string {
  return `+23324000${String(serial % 10_000).padStart(4, '0')}`
}

export function demoEmail(name: string, serial: number): string {
  const [first = 'user', last = String(serial)] = name.toLowerCase().split(' ')
  return `${first}.${last}${serial % 97}@trosky.test`
}

const PLATE_REGIONS = ['GR', 'GR', 'GR', 'GT', 'GW', 'GE', 'AS', 'CR'] as const

/** "GR 2451-22" */
export function plate(random: Random): string {
  return `${random.pick(PLATE_REGIONS)} ${random.int(1000, 9999)}-${random.int(16, 25)}`
}

export const VEHICLE_MODELS: Record<'minibus' | 'bus' | 'coach', [string, string][]> = {
  minibus: [
    ['Toyota', 'Hiace'],
    ['Nissan', 'Urvan'],
    ['Ford', 'Transit'],
    ['Mercedes-Benz', 'Sprinter'],
  ],
  bus: [
    ['Yutong', 'ZK6729'],
    ['King Long', 'XMQ6800'],
  ],
  coach: [
    ['Yutong', 'ZK6122'],
    ['Scania', 'Touring'],
    ['VIP', 'Marcopolo'],
  ],
}

export const SEATS: Record<'minibus' | 'bus' | 'coach', number> = {
  minibus: 15,
  bus: 33,
  coach: 50,
}

export const BUSINESS_NAMES = [
  'Kantamanto Movers',
  'Asante Express',
  'Golden Route Transport',
  'Sika Wheels',
  'Adom Shuttles',
  'Nyame Bekyere Ventures',
  'Coastal Link Co.',
  'Akwaaba Trotro Ltd',
] as const
