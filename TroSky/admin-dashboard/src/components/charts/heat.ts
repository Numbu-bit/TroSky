/**
 * The one-hue magnitude ramp (light to dark blue; lighter means more in
 * dark mode): a share 0-1 to a background, with text that stays readable.
 */
export function heatStyle(share: number): { backgroundColor: string; color: string } {
  const step = share <= 0 ? 0 : Math.min(5, Math.max(1, Math.ceil(share * 5)))
  if (step === 0) return { backgroundColor: 'transparent', color: 'inherit' }
  return {
    backgroundColor: `var(--heat-${step})`,
    // The darkest two steps (or the lightest two in dark mode) take light
    // text; the middle step is too light for white and too dark for the
    // ramp's own navy, so it takes a deeper navy (5.6:1).
    color:
      step >= 4
        ? 'var(--heat-text-strong, #ffffff)'
        : step === 3
          ? 'var(--heat-text-mid, #08213f)'
          : 'var(--heat-text, #0d366b)',
  }
}
