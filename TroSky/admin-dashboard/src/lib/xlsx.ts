/**
 * A small Excel (.xlsx) writer for report exports: one sheet, typed cells
 * (numbers stay numbers, money and ratios keep a number format), no
 * dependency. An .xlsx file is a ZIP of XML parts; entries are stored
 * uncompressed, which every spreadsheet app reads.
 */
export type CellKind = 'text' | 'count' | 'money' | 'ratio'

export interface SheetColumn {
  label: string
  kind: CellKind
}

const encoder = new TextEncoder()

const escapeXml = (value: string) =>
  value.replace(/[<>&"']/g, (character) =>
    character === '<'
      ? '&lt;'
      : character === '>'
        ? '&gt;'
        : character === '&'
          ? '&amp;'
          : character === '"'
            ? '&quot;'
            : '&apos;',
  )

/** "A", "B", ... "Z", "AA" for a 0-based column. */
function columnName(index: number): string {
  let name = ''
  for (let rest = index + 1; rest > 0; rest = Math.floor((rest - 1) / 26)) {
    name = String.fromCharCode(65 + ((rest - 1) % 26)) + name
  }
  return name
}

// Styles: 0 plain, 1 bold header, 2 whole number, 3 money, 4 percent.
const STYLE: Record<CellKind, number> = { text: 0, count: 2, money: 3, ratio: 4 }

function cell(
  reference: string,
  value: string | number | null,
  kind: CellKind,
  bold = false,
): string {
  if (value === null || value === '') return ''
  const numeric =
    kind !== 'text' && typeof value === 'number' ? value : kind !== 'text' ? Number(value) : NaN
  if (!bold && kind !== 'text' && Number.isFinite(numeric)) {
    return `<c r="${reference}" s="${STYLE[kind]}"><v>${numeric}</v></c>`
  }
  return `<c r="${reference}" t="inlineStr"${bold ? ' s="1"' : ''}><is><t xml:space="preserve">${escapeXml(String(value))}</t></is></c>`
}

function sheetXml(columns: SheetColumn[], rows: (string | number | null)[][]): string {
  const header = `<row r="1">${columns.map((column, index) => cell(`${columnName(index)}1`, column.label, 'text', true)).join('')}</row>`
  const body = rows
    .map(
      (row, rowIndex) =>
        `<row r="${rowIndex + 2}">${row
          .map((value, index) =>
            cell(`${columnName(index)}${rowIndex + 2}`, value, columns[index]?.kind ?? 'text'),
          )
          .join('')}</row>`,
    )
    .join('')
  const widths = columns
    .map(
      (column, index) =>
        `<col min="${index + 1}" max="${index + 1}" width="${Math.min(40, Math.max(10, column.label.length + 4))}" customWidth="1"/>`,
    )
    .join('')
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols>${widths}</cols><sheetData>${header}${body}</sheetData></worksheet>`
}

const STYLES = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="1"><numFmt numFmtId="164" formatCode="&quot;GH₵&quot;#,##0.00"/></numFmts><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="5"><xf/><xf fontId="1" applyFont="1"/><xf numFmtId="3" applyNumberFormat="1"/><xf numFmtId="164" applyNumberFormat="1"/><xf numFmtId="10" applyNumberFormat="1"/></cellXfs></styleSheet>`

function workbookFiles(sheetName: string, sheet: string): [string, string][] {
  const name = escapeXml(sheetName.replace(/[\\/?*[\]:]/g, ' ').slice(0, 31))
  return [
    [
      '[Content_Types].xml',
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>`,
    ],
    [
      '_rels/.rels',
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
    ],
    [
      'xl/workbook.xml',
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="${name}" sheetId="1" r:id="rId1"/></sheets></workbook>`,
    ],
    [
      'xl/_rels/workbook.xml.rels',
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`,
    ],
    ['xl/styles.xml', STYLES],
    ['xl/worksheets/sheet1.xml', sheet],
  ]
}

// ------------------------------------------------------------------ ZIP
const CRC_TABLE = (() => {
  const table = new Uint32Array(256)
  for (let n = 0; n < 256; n += 1) {
    let c = n
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    table[n] = c >>> 0
  }
  return table
})()

export function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff
  for (const byte of bytes) crc = CRC_TABLE[(crc ^ byte) & 0xff]! ^ (crc >>> 8)
  return (crc ^ 0xffffffff) >>> 0
}

/** A ZIP archive of the files, stored (not compressed). */
export function zip(files: [string, string][]): Uint8Array {
  const chunks: Uint8Array[] = []
  const central: Uint8Array[] = []
  let offset = 0
  for (const [path, content] of files) {
    const name = encoder.encode(path)
    const data = encoder.encode(content)
    const crc = crc32(data)
    const local = new DataView(new ArrayBuffer(30))
    local.setUint32(0, 0x04034b50, true)
    local.setUint16(4, 20, true) // version needed
    local.setUint16(6, 0x0800, true) // UTF-8 names
    local.setUint16(8, 0, true) // stored
    local.setUint32(14, crc, true)
    local.setUint32(18, data.length, true)
    local.setUint32(22, data.length, true)
    local.setUint16(26, name.length, true)
    chunks.push(new Uint8Array(local.buffer), name, data)
    const entry = new DataView(new ArrayBuffer(46))
    entry.setUint32(0, 0x02014b50, true)
    entry.setUint16(4, 20, true)
    entry.setUint16(6, 20, true)
    entry.setUint16(8, 0x0800, true)
    entry.setUint32(16, crc, true)
    entry.setUint32(20, data.length, true)
    entry.setUint32(24, data.length, true)
    entry.setUint16(28, name.length, true)
    entry.setUint32(42, offset, true)
    central.push(new Uint8Array(entry.buffer), name)
    offset += 30 + name.length + data.length
  }
  const directorySize = central.reduce((sum, part) => sum + part.length, 0)
  const end = new DataView(new ArrayBuffer(22))
  end.setUint32(0, 0x06054b50, true)
  end.setUint16(8, files.length, true)
  end.setUint16(10, files.length, true)
  end.setUint32(12, directorySize, true)
  end.setUint32(16, offset, true)
  const parts = [...chunks, ...central, new Uint8Array(end.buffer)]
  const out = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0))
  let at = 0
  for (const part of parts) {
    out.set(part, at)
    at += part.length
  }
  return out
}

/** The rows as an .xlsx workbook. */
export function toXlsx(
  sheetName: string,
  columns: SheetColumn[],
  rows: (string | number | null)[][],
): Blob {
  const bytes = zip(workbookFiles(sheetName, sheetXml(columns, rows)))
  return new Blob([bytes as BlobPart], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  })
}

/** Hand a file to the browser to save. */
export function saveBlob(blob: Blob, filename: string): void {
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  link.download = filename
  document.body.append(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(link.href), 1000)
}
