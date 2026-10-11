import { useEffect, useState } from 'react'

/** ``value``, once it has stopped changing for ``delayMs`` (search boxes: 300 ms). */
export function useDebounced<T>(value: T, delayMs = 300): T {
  const [settled, setSettled] = useState(value)
  useEffect(() => {
    const timer = setTimeout(() => setSettled(value), delayMs)
    return () => clearTimeout(timer)
  }, [value, delayMs])
  return settled
}
