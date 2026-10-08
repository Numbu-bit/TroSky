import { analyticsHandlers } from './analytics'
import { authHandlers } from './auth'
import { bookingHandlers } from './bookings'
import { dispatchHandlers } from './dispatch'
import { fleetHandlers } from './fleet'
import { fleetsHandlers } from './fleets'
import { fraudHandlers } from './fraud'
import { liveHandlers } from './live'
import { networkHandlers } from './network'
import { overviewHandlers } from './overview'
import { platformHandlers } from './platform'
import { queueHandlers } from './queues'
import { safetyHandlers } from './safety'
import { supportHandlers } from './support'
import { tripHandlers } from './trips'

/**
 * Every demo endpoint. Order matters where paths overlap: the fixed
 * "/admin/drivers/pending" (queues) must come before "/admin/drivers/:id"
 * (fleet), so the fleet handlers go last.
 */
export const handlers = [
  ...authHandlers,
  ...overviewHandlers,
  ...liveHandlers,
  ...safetyHandlers,
  ...queueHandlers,
  ...networkHandlers,
  ...tripHandlers,
  ...dispatchHandlers,
  ...bookingHandlers,
  ...supportHandlers,
  ...analyticsHandlers,
  ...fraudHandlers,
  ...platformHandlers,
  // Before the fleet handlers: "/admin/drivers/performance" isn't a driver id.
  ...fleetsHandlers,
  ...fleetHandlers,
]
