// Loaded up front: the screens these tests open are lazy.
import './ApprovalsScreen'

import { screen, waitFor, within } from '@testing-library/react'

import { addDemoDriverApplication } from '@/api/demo/triggers'
import { ADMIN, renderApp, staffWith } from '@/test/render'

type User = ReturnType<typeof renderApp>['user']

async function openFirst(user: User, queue: 'Drivers waiting' | 'Vehicles waiting') {
  const list = await screen.findByRole('list', { name: queue })
  const first = within(list).getAllByRole('link')[0]!
  const title = first.querySelector('.font-medium')!.textContent!
  await user.click(first)
  await screen.findByRole('heading', { level: 2, name: title })
  return { title, total: within(list).getAllByRole('link').length }
}

async function tickEveryCheck(user: User) {
  const checks = within(await screen.findByRole('group', { name: /Checks/ })).getAllByRole(
    'checkbox',
  )
  for (const check of checks) await user.click(check)
}

describe('Approvals', () => {
  it('queue applications oldest first, with how long each has waited', async () => {
    renderApp('/approvals', { as: ADMIN })
    const list = await screen.findByRole('list', { name: 'Drivers waiting' })
    const ages = within(list)
      .getAllByRole('link')
      .map((link) => link.lastElementChild!.textContent!)
    expect(ages.length).toBeGreaterThan(1)
    const hours = ages.map((age) => (age.endsWith(' d') ? parseInt(age) * 24 : parseInt(age) || 0))
    expect([...hours].sort((a, b) => b - a)).toEqual(hours)
    expect(screen.getByRole('link', { name: /Drivers/ })).toHaveAttribute('aria-current', 'page')
  })

  it('approve only once every check is ticked, then open the next one', async () => {
    const { user } = renderApp('/approvals', { as: ADMIN })
    const { title } = await openFirst(user, 'Drivers waiting')
    expect(await screen.findByRole('img', { name: /Driver’s licence for/ })).toBeInTheDocument()
    const approve = screen.getByRole('button', { name: 'Approve driver' })
    expect(approve).toBeDisabled()

    await tickEveryCheck(user)
    await user.click(approve)
    const confirm = await screen.findByRole('alertdialog')
    expect(within(confirm).getByText(`Approve ${title}?`)).toBeInTheDocument()
    await user.click(within(confirm).getByRole('button', { name: 'Approve driver' }))

    expect(await screen.findByText(`${title} approved.`)).toBeInTheDocument()
    await waitFor(() =>
      expect(screen.getByRole('heading', { level: 2 })).not.toHaveTextContent(title),
    )
    // The next one starts with no checks ticked.
    expect(await screen.findByRole('button', { name: 'Approve driver' })).toBeDisabled()
  })

  it('reject only with a reason the applicant sees', async () => {
    const { user } = renderApp('/approvals', { as: ADMIN })
    const { title } = await openFirst(user, 'Drivers waiting')
    await user.click(screen.getByRole('button', { name: 'Reject' }))
    const confirm = await screen.findByRole('alertdialog')
    const reject = within(confirm).getByRole('button', { name: 'Reject' })
    expect(reject).toBeDisabled()
    await user.type(within(confirm).getByLabelText(/Reason/), 'The licence has expired.')
    await user.click(reject)
    expect(await screen.findByText(`${title} rejected.`)).toBeInTheDocument()
  })

  it('ask for documents again instead of rejecting', async () => {
    const { user } = renderApp('/approvals', { as: ADMIN })
    const { title } = await openFirst(user, 'Drivers waiting')
    await user.click(screen.getByRole('button', { name: 'Ask for documents' }))
    const dialog = await screen.findByRole('dialog')
    const send = within(dialog).getByRole('button', { name: 'Send request' })
    expect(send).toBeDisabled()
    await user.click(within(dialog).getByLabelText('Driver’s licence'))
    await user.type(within(dialog).getByLabelText(/What’s wrong/), 'The photo is blurred.')
    await user.click(send)
    expect(await screen.findByText(`Asked ${title} for a document.`)).toBeInTheDocument()
  })

  it('show the documents zoomed and turned', async () => {
    const { user } = renderApp('/approvals', { as: ADMIN })
    await openFirst(user, 'Drivers waiting')
    const image = await screen.findByRole('img', { name: /Driver’s licence for/ })
    await user.click(screen.getByRole('button', { name: 'Zoom in' }))
    expect(screen.getByText('125%')).toBeInTheDocument()
    expect(image).toHaveStyle({ width: '125%' })
    await user.click(screen.getByRole('button', { name: 'Rotate a quarter turn' }))
    expect(image).toHaveStyle({ transform: 'rotate(90deg)' })
    await user.click(screen.getByRole('button', { name: /^Profile photo/ }))
    expect(await screen.findByRole('img', { name: /Profile photo for/ })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /^Profile photo/ })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
  })

  it('cover vehicles too', async () => {
    const { user } = renderApp('/approvals?queue=vehicles', { as: ADMIN })
    await openFirst(user, 'Vehicles waiting')
    expect(await screen.findByRole('img', { name: /Vehicle registration for/ })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Approve vehicle' })).toBeDisabled()
    await tickEveryCheck(user)
    expect(screen.getByRole('button', { name: 'Approve vehicle' })).toBeEnabled()
  })

  it('put a new application at the back of the queue', async () => {
    const driver = addDemoDriverApplication()
    renderApp('/approvals', { as: ADMIN })
    const list = await screen.findByRole('list', { name: 'Drivers waiting' })
    const last = within(list).getAllByRole('link').at(-1)!
    expect(last).toHaveTextContent(`Licence ${driver.license_number}`)
    expect(last).toHaveTextContent('under 1 h')
  })

  it('show only the queues an admin may work', async () => {
    renderApp('/approvals', { as: staffWith('vehicles:approve') })
    expect(await screen.findByRole('list', { name: 'Vehicles waiting' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /^Drivers/ })).not.toBeInTheDocument()
  })
})
