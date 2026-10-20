import { zodResolver } from '@hookform/resolvers/zod'
import { Eye, EyeOff, Info, LogIn } from 'lucide-react'
import { lazy, Suspense, useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { Navigate, useSearchParams } from 'react-router'
import { z } from 'zod'

import { errorMessage } from '@/api/errors'
import { DemoBadge } from '@/app/layout/TopBar'
import { Spinner } from '@/components/feedback/states'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

import { useAuth } from './auth-context'
import { safeNext } from './next'

// Only demo builds carry the demo accounts: elsewhere this is null and the
// import is dropped from the bundle.
const DemoAccounts =
  import.meta.env.VITE_DEMO_MODE === 'true' ? lazy(() => import('@/api/demo/DemoAccounts')) : null

const schema = z.object({
  identifier: z.string().trim().min(3, 'Enter your phone number or email.'),
  password: z.string().min(1, 'Enter your password.'),
})

type Values = z.infer<typeof schema>

/** A sign-in still waiting after this long is most likely waking a server
 * that went to sleep (Render's free plan, after 15 quiet minutes). */
const WAKING_UP_AFTER_MS = 6_000

export default function LoginPage() {
  const { state, login } = useAuth()
  const [params] = useSearchParams()
  const next = safeNext(params.get('next'))
  const [showPassword, setShowPassword] = useState(false)
  const [failure, setFailure] = useState<string | null>(null)
  const form = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: { identifier: '', password: '' },
  })
  const { errors, isSubmitting } = form.formState
  const [slow, setSlow] = useState(false)

  useEffect(() => {
    document.title = 'Sign in · TroSky Admin'
  }, [])

  useEffect(() => {
    if (!isSubmitting) return
    const timer = setTimeout(() => setSlow(true), WAKING_UP_AFTER_MS)
    return () => clearTimeout(timer)
  }, [isSubmitting])

  if (state.status === 'signed-in') return <Navigate to={next} replace />

  const onSubmit = form.handleSubmit(async ({ identifier, password }) => {
    setFailure(null)
    setSlow(false)
    try {
      await login(identifier, password)
    } catch (error) {
      setFailure(errorMessage(error, 'Sign-in failed.'))
      form.setValue('password', '')
    }
  })

  return (
    <div className="flex min-h-svh items-center justify-center bg-navy p-4">
      <div className="w-full max-w-sm space-y-4">
        <div className="flex items-center justify-center gap-2 text-white">
          <img src="/favicon.svg" alt="" className="size-10" />
          <div className="leading-tight">
            <p className="text-xl font-bold">TroSky</p>
            <p className="text-sm text-white/70">Admin dashboard</p>
          </div>
        </div>
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between gap-2">
              <h1 className="text-lg">Sign in</h1>
              <DemoBadge />
            </CardTitle>
            <CardDescription>Use your TroSky admin account.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {state.status === 'signed-out' && state.reason === 'expired' ? (
              <p className="flex gap-2 rounded-md bg-info-soft p-3 text-sm text-info-text">
                <Info className="mt-0.5 size-4 shrink-0" aria-hidden />
                Your session ended. Sign in again to go back to where you were.
              </p>
            ) : null}
            {failure ? (
              <p role="alert" className="rounded-md bg-danger-soft p-3 text-sm text-danger-text">
                {failure}
              </p>
            ) : null}
            <div role="status" aria-live="polite">
              {isSubmitting && slow ? (
                <p className="flex gap-2 rounded-md bg-info-soft p-3 text-sm text-info-text">
                  <Info className="mt-0.5 size-4 shrink-0" aria-hidden />
                  The server is waking up. After a quiet spell this can take up to a minute.
                </p>
              ) : null}
            </div>
            <form className="space-y-4" onSubmit={onSubmit} noValidate>
              <div className="space-y-1.5">
                <Label htmlFor="identifier">Phone number or email</Label>
                <Input
                  id="identifier"
                  autoComplete="username"
                  inputMode="email"
                  placeholder="024 000 0000 or name@example.com"
                  aria-invalid={errors.identifier ? true : undefined}
                  aria-describedby={errors.identifier ? 'identifier-error' : undefined}
                  {...form.register('identifier')}
                />
                {errors.identifier ? (
                  <p id="identifier-error" className="text-sm text-danger-text">
                    {errors.identifier.message}
                  </p>
                ) : null}
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="password">Password</Label>
                <div className="relative">
                  <Input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    autoComplete="current-password"
                    className="pr-10"
                    aria-invalid={errors.password ? true : undefined}
                    aria-describedby={errors.password ? 'password-error' : undefined}
                    {...form.register('password')}
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    className="absolute top-0 right-0"
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                    aria-pressed={showPassword}
                    onClick={() => setShowPassword((shown) => !shown)}
                  >
                    {showPassword ? <EyeOff aria-hidden /> : <Eye aria-hidden />}
                  </Button>
                </div>
                {errors.password ? (
                  <p id="password-error" className="text-sm text-danger-text">
                    {errors.password.message}
                  </p>
                ) : null}
              </div>
              <Button type="submit" className="w-full" disabled={isSubmitting}>
                {isSubmitting ? <Spinner label="Signing in" /> : <LogIn aria-hidden />}
                Sign in
              </Button>
            </form>
            {DemoAccounts ? (
              <Suspense fallback={null}>
                <DemoAccounts
                  onPick={(identifier, password) => {
                    form.setValue('identifier', identifier)
                    form.setValue('password', password)
                  }}
                />
              </Suspense>
            ) : null}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
