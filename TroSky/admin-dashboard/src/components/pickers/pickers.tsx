import { useDriverChoices, useStops, useVehicleChoices } from '@/features/shared/reference'
import { humanize } from '@/lib/format'

import { SearchPicker, type PickerOption } from './SearchPicker'

type PickerProps = {
  id?: string
  value: string | null
  /** What to show for ``value`` before the options have loaded. */
  selectedLabel?: string
  onChange: (option: PickerOption | null) => void
  disabled?: boolean
  allowClear?: boolean
  placeholder?: string
}

function useDriverOptions(search: string, open: boolean) {
  const query = useDriverChoices(search, open)
  return {
    loading: query.isFetching,
    options: (query.data?.items ?? []).map((driver) => ({
      value: driver.id,
      label: driver.full_name ?? driver.phone_number,
      hint: [
        humanize(driver.live_status),
        driver.vehicle?.registration_number,
        driver.average_rating ? `★ ${driver.average_rating}` : null,
      ]
        .filter(Boolean)
        .join(' · '),
    })),
  }
}

function useVehicleOptions(search: string, open: boolean) {
  const query = useVehicleChoices(search, open)
  return {
    loading: query.isFetching,
    options: (query.data?.items ?? []).map((vehicle) => ({
      value: vehicle.id,
      label: vehicle.registration_number,
      hint: `${vehicle.make_model ?? humanize(vehicle.vehicle_type)} · ${vehicle.capacity} seats · ${humanize(vehicle.live_status)}`,
    })),
  }
}

function useStopOptions(search: string) {
  const query = useStops(search)
  return {
    loading: query.isFetching,
    options: (query.data?.items ?? []).map((stop) => ({
      value: stop.id,
      label: stop.name,
      hint: [stop.code, stop.city].filter(Boolean).join(' · '),
    })),
  }
}

/** Approved drivers only: the API refuses anyone else on a trip. */
export function DriverPicker(props: PickerProps) {
  return (
    <SearchPicker
      {...props}
      placeholder={props.placeholder ?? 'Choose an approved driver'}
      searchPlaceholder="Name, phone or licence"
      emptyText="No approved driver matches."
      useOptions={useDriverOptions}
    />
  )
}

/** Approved vehicles only. */
export function VehiclePicker(props: PickerProps) {
  return (
    <SearchPicker
      {...props}
      placeholder={props.placeholder ?? 'Choose an approved vehicle'}
      searchPlaceholder="Part of the plate"
      emptyText="No approved vehicle matches."
      useOptions={useVehicleOptions}
    />
  )
}

export function StopPicker(props: PickerProps) {
  return (
    <SearchPicker
      {...props}
      placeholder={props.placeholder ?? 'Choose a stop'}
      searchPlaceholder="Stop name (2 letters or more)"
      emptyText="No stop matches."
      useOptions={useStopOptions}
    />
  )
}
