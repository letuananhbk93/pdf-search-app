# PROCESS table: Excel colors and QC dates (frontend changes)

Goal: the app's Process tables should look like the uploaded PROCESS Excel file.

- **Order** cell uses the fill color of the **SHIP TO** cell in Excel.
- **Carcass QC** cell uses the fill color of the **RAW CARCASS** cell.
- **Final QC** cell uses the fill color of the **FINAL QC** cell.
- **RAW CARCASS** and **FINAL QC** dates show as `dd/mm`. Anything that is not a date is shown as text, exactly as typed.

## Changed file

`lib/screens/projects_screen.dart` (only file changed in the Flutter app for this feature)

### Project table (`_buildTableView`) and search results (`ProcessSearchDelegate`)

- Both tables use the same fixed column widths (`_columns`) and row height (`_kProcessRowHeight = 110`).
- Each cell is built with `_processCell(...)`. It paints a background color when a color is given. Text turns white when the background is dark (luminance < 0.4).
- Header labels come from `_processHeader(...)`, sized to match the body column.
- Sorting on Carcass QC and Final QC uses the formatted date, in chronological order (`_qcSortKey`). Blank values and text come after dates.

### Helpers added

| Helper | Purpose |
|---|---|
| `_parseExcelColor(value)` | Accepts `"#RRGGBB"` or `"RRGGBB"`. Returns `null` for empty or invalid values, which means no fill. |
| `_formatQcDate(value)` | `"2026-10-22 00:00:00"` or `"2026-10-22"` becomes `"22/10"`. `"NaT"`, `"None"`, `"nan"` and empty become `""`. Other text is returned as is. |
| `_qcSortKey(formatted)` | Builds a sort key from `dd/mm`, month first, so the order is chronological. |

### Detail dialog (`_showDetailDialog`, both screens)

- Fields whose key ends with `_color` are hidden.
- `carcass_qc_day` and `final_qc_date` are shown through `_formatQcDate`.

## Data the frontend now expects from `/process/{project}` and `/process/search`

Every process record should contain these fields. They are added to the existing fields, which are unchanged.

| Field | Type | Meaning |
|---|---|---|
| `order_color` | string | `"#RRGGBB"` fill of the SHIP TO cell, or `""` when there is no fill |
| `carcass_color` | string | `"#RRGGBB"` fill of the RAW CARCASS cell, or `""` |
| `final_color` | string | `"#RRGGBB"` fill of the FINAL QC cell, or `""` |
| `carcass_qc_day` | string | `"dd/mm"` for a date cell. Otherwise the cell text (e.g. `"AVAILABLE"`, `"22/10 TOP"`). `""` if empty. |
| `final_qc_date` | string | Same rule as `carcass_qc_day`, for FINAL QC |

Notes:
- The frontend still accepts ISO strings (`2026-10-22 00:00:00`) in these fields, so older data keeps working. It converts them to `dd/mm`.
- Colors are case-insensitive. `#FFFF00` (yellow) and `#00B0F0` (light blue) are the colors seen in the test file.

## Backend work this implies (for reference)

Implemented in `D:\Projects\pdf_backend` (not deployed):
- `process_excel_styles.py` (new): reads fills (rgb, theme+tint, indexed) and resolves the date text.
- `main.py` `/upload-process-excel`: stores `order_color`, `carcass_color`, `final_color` as TEXT columns and writes the `dd/mm` / cell text values.

Verified on `24-10 -2026-PO9-26_PRODUCTION_TIMELINE.xlsx`: 8 sheets, row alignment matches the existing pandas import, and the fills and dates come out as expected.

## Not yet verified

- The table has not been checked visually in a browser. Column widths and row height may need adjusting.
- The live backend does not return the new fields until the backend is deployed and the Excel files are uploaded again.
- A local preview server is still running on port 8765, serving `build\web_preview`.
