import { QueryErrorResetBoundary } from '@tanstack/react-query'
import { Component, type ErrorInfo, type ReactNode } from 'react'

import { ErrorState } from './states'

interface BoundaryProps {
  children: ReactNode
  onReset?: () => void
  title?: string
}

interface BoundaryState {
  error: unknown
}

class Boundary extends Component<BoundaryProps, BoundaryState> {
  state: BoundaryState = { error: null }

  static getDerivedStateFromError(error: unknown): BoundaryState {
    return { error }
  }

  componentDidCatch(error: unknown, info: ErrorInfo) {
    // No personal data is logged: the component stack and the error only.
    console.error('Widget failed', error, info.componentStack)
  }

  render() {
    if (this.state.error) {
      return (
        <ErrorState
          error={this.state.error}
          title={this.props.title ?? 'This part of the page failed'}
          onRetry={() => {
            this.props.onReset?.()
            this.setState({ error: null })
          }}
        />
      )
    }
    return this.props.children
  }
}

/**
 * Wraps one widget so its failure is shown in its place, with a retry,
 * instead of blanking the whole page.
 */
export function WidgetBoundary({ children, title }: { children: ReactNode; title?: string }) {
  return (
    <QueryErrorResetBoundary>
      {({ reset }) => (
        <Boundary onReset={reset} title={title}>
          {children}
        </Boundary>
      )}
    </QueryErrorResetBoundary>
  )
}
