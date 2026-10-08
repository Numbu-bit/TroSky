// Loaded up front: the screen these tests open is lazy.
import './DriverRatingsPage'

import { screen, within } from '@testing-library/react'

import { getDb, index } from '@/api/demo/db'
import { ADMIN, renderApp } from '@/test/render'

describe('Driver ratings', () => {
  it('show a driver’s overall score and each category, as bars or a table', async () => {
    const [driverId, ratings] = [...index().ratingsByDriver.entries()].find(
      ([, list]) => list.length > 10,
    )!
    const { user } = renderApp(`/driver-ratings?driver=${driverId}`, { as: ADMIN })
    expect(await screen.findByText('Overall')).toBeInTheDocument()
    expect(screen.getByText(`From ${ratings.length} ratings`)).toBeInTheDocument()
    const average = ratings.reduce((sum, rating) => sum + rating.overall, 0) / ratings.length
    expect(screen.getByRole('img', { name: `${average.toFixed(1)} out of 5` })).toBeInTheDocument()

    const bars = screen.getByRole('list', { name: 'Averages out of 5' })
    expect(
      within(bars)
        .getAllByRole('listitem')
        .map((item) => item.firstChild?.textContent),
    ).toEqual(['Safety', 'Cleanliness', 'Professionalism', 'Timeliness'])
    await user.click(screen.getByRole('button', { name: 'Show as a table' }))
    const table = screen.getByRole('table', { name: 'By what passengers rated' })
    expect(within(table).getAllByRole('row')).toHaveLength(5)
  })

  it('say when a driver has no ratings yet', async () => {
    const newcomer = getDb().drivers.find((driver) => driver.status === 'pending')!
    renderApp(`/driver-ratings?driver=${newcomer.id}`, { as: ADMIN })
    expect(await screen.findByText('No ratings yet')).toBeInTheDocument()
  })

  it('ask for a driver first', async () => {
    renderApp('/driver-ratings', { as: ADMIN })
    expect(
      await screen.findByText('Or open one from a trip, an approval or an account.'),
    ).toBeInTheDocument()
    expect(screen.getByRole('combobox', { name: 'Driver' })).toHaveTextContent('Choose a driver')
  })
})
