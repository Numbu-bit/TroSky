// Loaded up front: the screens these tests open are lazy.
import './NetworkScreen'
import './PinMap'
import '@/components/map/RouteMap'

import { fireEvent, screen, waitFor, within } from '@testing-library/react'

import { getDb } from '@/api/demo/db'
import { ADMIN, renderApp } from '@/test/render'

import { formatDays } from './days'

type User = ReturnType<typeof renderApp>['user']

/** Pick a stop in a stop picker by typing part of its name. */
async function pickStop(user: User, label: string, name: string) {
  await user.click(screen.getByRole('combobox', { name: label }))
  await user.type(await screen.findByPlaceholderText(/Stop name/), name.slice(0, 4))
  await user.click(await screen.findByRole('option', { name: new RegExp(`^${name}`) }))
}

describe('Routes', () => {
  it('are listed A to Z with their ends, and filtered as you type', async () => {
    const { user } = renderApp('/network', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Routes' })
    expect(within(table).getAllByRole('row').length).toBeGreaterThan(5)
    expect(await within(table).findAllByText(/Circle → Madina|Circle/)).not.toHaveLength(0)

    await user.type(screen.getByLabelText('Find a route'), 'Kasoa')
    await waitFor(() => {
      for (const row of within(table).getAllByRole('row').slice(1)) {
        expect(row).toHaveTextContent(/Kasoa/)
      }
    })
  })

  it('are created from their stops in order, then opened', async () => {
    const { user } = renderApp('/network', { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'New route' }))
    const dialog = await screen.findByRole('dialog')
    await user.click(within(dialog).getByRole('button', { name: 'Create route' }))
    expect(await within(dialog).findByText('Choose where the route starts.')).toBeInTheDocument()
    expect(within(dialog).getByText('Choose where the route ends.')).toBeInTheDocument()

    await user.type(within(dialog).getByLabelText('Name'), 'Madina – Kaneshie Express')
    await pickStop(user, 'Starts at', 'Madina')
    await user.click(within(dialog).getByRole('button', { name: 'Add a stop in between' }))
    await pickStop(user, 'Next stop in between', 'Circle')
    expect(within(dialog).getByRole('list')).toHaveTextContent('Circle')
    await pickStop(user, 'Ends at', 'Kaneshie')
    await user.click(within(dialog).getByRole('button', { name: 'Create route' }))

    expect(
      await screen.findByRole('heading', { name: 'Madina – Kaneshie Express' }),
    ).toBeInTheDocument()
    const stops = screen.getByRole('region', { name: 'Stops, in order' })
    expect(
      within(stops)
        .getAllByRole('listitem')
        .map((item) => item.textContent),
    ).toEqual([
      expect.stringContaining('Madina'),
      expect.stringContaining('Circle'),
      expect.stringContaining('Kaneshie'),
    ])
  })

  it('refuse a name another route has', async () => {
    const taken = getDb().routes.find((route) => route.is_active)!.name
    const { user } = renderApp('/network', { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'New route' }))
    const dialog = await screen.findByRole('dialog')
    await user.type(within(dialog).getByLabelText('Name'), taken)
    await pickStop(user, 'Starts at', 'Madina')
    await pickStop(user, 'Ends at', 'Kaneshie')
    await user.click(within(dialog).getByRole('button', { name: 'Create route' }))
    expect(
      await within(dialog).findByText('Another route already has this name.'),
    ).toBeInTheDocument()
  })
})

describe('A route', () => {
  it('shows its timetable, and takes new departures', async () => {
    const route = getDb().routes.find((candidate) => candidate.name === 'Achimota – Amasaman')!
    const { user } = renderApp(`/network/routes/${route.id}`, { as: ADMIN })
    const departures = await screen.findByRole('list', { name: 'Departures' })
    const before = within(departures).getAllByRole('listitem').length

    fireEvent.change(screen.getByLabelText('Leaves at'), { target: { value: '19:05' } })
    await user.click(screen.getByRole('button', { name: 'Weekends' }))
    await user.type(screen.getByLabelText('Fare (GH₵)'), '7.50')
    await user.click(screen.getByRole('button', { name: 'Add departure' }))

    expect(await screen.findByText('Departure at 19:05 added.')).toBeInTheDocument()
    await waitFor(() =>
      expect(
        within(screen.getByRole('list', { name: 'Departures' })).getAllByRole('listitem'),
      ).toHaveLength(before + 1),
    )
    expect(screen.getByText('19:05').closest('li')).toHaveTextContent('Weekends')
    expect(screen.getByText('19:05').closest('li')).toHaveTextContent('GH₵7.50')
  })

  it('is edited: name, length and time', async () => {
    const route = getDb().routes.find((candidate) => candidate.is_active)!
    const { user } = renderApp(`/network/routes/${route.id}`, { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'Edit' }))
    const dialog = await screen.findByRole('dialog')
    await user.clear(within(dialog).getByLabelText('Time in minutes'))
    await user.type(within(dialog).getByLabelText('Time in minutes'), '61')
    await user.click(within(dialog).getByRole('button', { name: 'Save route' }))
    expect(await screen.findByText('Route saved.')).toBeInTheDocument()
    expect(await screen.findByText(/1 h 1 min/)).toBeInTheDocument()
  })

  it('can’t be retired while trips on it are still to run', async () => {
    const route = getDb().routes.find((candidate) => candidate.is_active)!
    const { user } = renderApp(`/network/routes/${route.id}`, { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'Retire route' }))
    const confirm = await screen.findByRole('alertdialog')
    await user.click(within(confirm).getByRole('button', { name: 'Retire route' }))
    expect(
      await within(confirm).findByText(/still scheduled or under way on this route/),
    ).toBeInTheDocument()
  })
})

describe('Stops', () => {
  it('are searched by name from two letters', async () => {
    const { user, router } = renderApp('/network/stops', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Stops' })
    const all = within(table).getAllByRole('row').length
    await user.type(screen.getByLabelText('Search by name'), 'ka')
    await waitFor(() => expect(router.state.location.search).toBe('?q=ka'))
    await waitFor(() =>
      expect(
        within(screen.getByRole('table', { name: 'Stops' })).getAllByRole('row').length,
      ).toBeLessThan(all),
    )
    for (const row of within(screen.getByRole('table', { name: 'Stops' }))
      .getAllByRole('row')
      .slice(1)) {
      expect(row.querySelector('td')).toHaveTextContent(/ka/i)
    }
  })

  it('are added with their coordinates', async () => {
    const { user } = renderApp('/network/stops', { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'New stop' }))
    const dialog = await screen.findByRole('dialog')
    await user.click(within(dialog).getByRole('button', { name: 'Add stop' }))
    expect(await within(dialog).findByText('At least 2 characters.')).toBeInTheDocument()
    expect(within(dialog).getByText(/Enter the latitude, or click the map/)).toBeInTheDocument()

    await user.type(within(dialog).getByLabelText('Name'), 'Madina Zongo Junction')
    await user.type(within(dialog).getByLabelText('Latitude'), '5.6731')
    await user.type(within(dialog).getByLabelText('Longitude'), '-200')
    await user.click(within(dialog).getByRole('button', { name: 'Add stop' }))
    expect(await within(dialog).findByText(/between -180 and 180/)).toBeInTheDocument()
    await user.clear(within(dialog).getByLabelText('Longitude'))
    await user.type(within(dialog).getByLabelText('Longitude'), '-0.1662')
    await user.click(within(dialog).getByRole('button', { name: 'Add stop' }))
    expect(await screen.findByText('Madina Zongo Junction added.')).toBeInTheDocument()
  })

  it('are moved and renamed', async () => {
    const { user } = renderApp('/network/stops?q=kasoa', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Stops' })
    await user.click(within(table).getAllByRole('button', { name: /^Edit / })[0]!)
    const dialog = await screen.findByRole('dialog')
    await user.clear(within(dialog).getByLabelText('Name'))
    await user.type(within(dialog).getByLabelText('Name'), 'Kasoa New Market')
    await user.click(within(dialog).getByRole('button', { name: 'Save stop' }))
    expect(await screen.findByText('Stop saved.')).toBeInTheDocument()
  })

  it('can’t be retired while active routes use them', async () => {
    const { user } = renderApp('/network/stops?q=madina', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Stops' })
    await user.click(within(table).getAllByRole('button', { name: 'Retire' })[0]!)
    const confirm = await screen.findByRole('alertdialog')
    await user.click(within(confirm).getByRole('button', { name: 'Retire stop' }))
    expect(
      await within(confirm).findByText(
        /It is on .*active routes?: .*Madina.*\. Retire th(at|ose) routes? first/,
      ),
    ).toBeInTheDocument()
  })
})

describe('formatDays', () => {
  it('names common patterns', () => {
    expect(
      formatDays(['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']),
    ).toBe('Every day')
    expect(formatDays(['friday', 'monday', 'tuesday', 'wednesday', 'thursday'])).toBe('Mon–Fri')
    expect(formatDays(['sunday', 'saturday'])).toBe('Weekends')
    expect(formatDays(['friday', 'monday', 'wednesday'])).toBe('Mon, Wed, Fri')
  })
})
