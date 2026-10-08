/**
 * A seeded random source, so demo data is the same on every load (and in
 * every test): mulberry32, small and fast, good enough for fake data.
 */
export class Random {
  private state: number

  constructor(seed: number) {
    this.state = seed >>> 0
  }

  /** In [0, 1). */
  next(): number {
    this.state = (this.state + 0x6d2b79f5) | 0
    let t = Math.imul(this.state ^ (this.state >>> 15), 1 | this.state)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4_294_967_296
  }

  /** An integer in [min, max]. */
  int(min: number, max: number): number {
    return min + Math.floor(this.next() * (max - min + 1))
  }

  float(min: number, max: number): number {
    return min + this.next() * (max - min)
  }

  chance(probability: number): boolean {
    return this.next() < probability
  }

  pick<T>(items: readonly T[]): T {
    if (items.length === 0) throw new Error('pick() from an empty list')
    return items[Math.floor(this.next() * items.length)] as T
  }

  /** One of ``entries``, in proportion to its weight. */
  weighted<T>(entries: readonly (readonly [T, number])[]): T {
    const total = entries.reduce((sum, [, weight]) => sum + weight, 0)
    let roll = this.next() * total
    for (const [value, weight] of entries) {
      roll -= weight
      if (roll < 0) return value
    }
    return entries[entries.length - 1]![0]
  }

  shuffle<T>(items: readonly T[]): T[] {
    const copy = [...items]
    for (let index = copy.length - 1; index > 0; index -= 1) {
      const other = Math.floor(this.next() * (index + 1))
      ;[copy[index], copy[other]] = [copy[other] as T, copy[index] as T]
    }
    return copy
  }

  sample<T>(items: readonly T[], count: number): T[] {
    return this.shuffle(items).slice(0, count)
  }

  /** A version-4-shaped UUID, deterministic for this seed. */
  uuid(): string {
    const part = () =>
      Math.floor(this.next() * 0x1_0000_0000)
        .toString(16)
        .padStart(8, '0')
    const hex = part() + part() + part() + part()
    const variant = ((parseInt(hex.charAt(16), 16) & 0x3) | 0x8).toString(16)
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-${variant}${hex.slice(17, 20)}-${hex.slice(20, 32)}`
  }
}
