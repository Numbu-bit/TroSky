export interface TableColumn<T> {
  key: string
  label: string
  value: (row: T) => string | number
  align?: 'right'
}

/** Rows as a CSV file, downloaded in the browser. */
export function downloadCsv<T>(rows: T[], columns: TableColumn<T>[], name: string): void {
  const cell = (value: string | number) => {
    const text = String(value)
    return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text
  }
  const lines = [
    columns.map((column) => cell(column.label)).join(','),
    ...rows.map((row) => columns.map((column) => cell(column.value(row))).join(',')),
  ]
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' })
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  link.download = `${name}.csv`
  document.body.append(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(link.href), 1000)
}
