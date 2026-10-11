import { crc32, toXlsx, zip } from './xlsx'

const decoder = new TextDecoder()

/** The stored entries of a ZIP, by walking its local file headers. */
function entries(bytes: Uint8Array): Record<string, string> {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const found: Record<string, string> = {}
  let at = 0
  while (view.getUint32(at, true) === 0x04034b50) {
    const size = view.getUint32(at + 18, true)
    const nameLength = view.getUint16(at + 26, true)
    const name = decoder.decode(bytes.subarray(at + 30, at + 30 + nameLength))
    found[name] = decoder.decode(bytes.subarray(at + 30 + nameLength, at + 30 + nameLength + size))
    at += 30 + nameLength + size
  }
  return found
}

describe('the xlsx writer', () => {
  it('computes the standard CRC-32', () => {
    expect(crc32(new TextEncoder().encode('123456789'))).toBe(0xcbf43926)
  })

  it('zips its parts, readable back with their names', () => {
    const files = entries(
      zip([
        ['a.xml', '<a/>'],
        ['dir/b.xml', '<b>ŋ</b>'],
      ]),
    )
    expect(files).toEqual({ 'a.xml': '<a/>', 'dir/b.xml': '<b>ŋ</b>' })
  })

  it('writes a workbook with typed cells and escaped text', async () => {
    const blob = toXlsx(
      'Revenue',
      [
        { label: 'Period', kind: 'text' },
        { label: 'Gross (GHS)', kind: 'money' },
        { label: 'Occupancy', kind: 'ratio' },
      ],
      [
        ['1 Oct 2026', '1234.50', '0.7500'],
        ['Kejetia <-> Circle & co', null, '0.5'],
      ],
    )
    const files = entries(new Uint8Array(await blob.arrayBuffer()))
    expect(Object.keys(files)).toContain('xl/workbook.xml')
    const sheet = files['xl/worksheets/sheet1.xml']!
    expect(sheet).toContain('<c r="B2" s="3"><v>1234.5</v></c>')
    expect(sheet).toContain('<c r="C2" s="4"><v>0.75</v></c>')
    expect(sheet).toContain('Kejetia &lt;-&gt; Circle &amp; co')
    expect(sheet).not.toContain('r="B3"')
    expect(files['xl/workbook.xml']).toContain('name="Revenue"')
  })
})
