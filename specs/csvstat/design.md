# Design: csvstat

## Overview

`bin/csvstat.lpscr` is a `host.scripted` script. Its top-level statements
parse `args()` into `Options`, handle `--help` and `--version`, read the
input whole, turn it into a `Table`, select the columns, describe each one
and print the result in the chosen form. Everything else is in `lib/`, in
`host.scripted` modules (`.lpscr`): they use `system.text`, `system.json`,
sets and `Any`, which only the interpreters run, and the unit tests import
them directly.

```text
args() ─ parse_args ─► Options
text ─ split_records ─► (line, record) ─ data.csv.parse ─► Table (names, raw columns)
column ─ infer_column ─► (ColumnType, list[Cell]) ─ describe ─► ColumnStats
list[ColumnStats] ─ render_text / render_one / render_csv / render_look / render_json ─► stdout
```

## Modules

| Module | Contents |
|---|---|
| `bin/csvstat.lpscr` | top level: options, input checks, logging, output, exit status |
| `lib/appinfo.lpscr` | name, version, exit statuses |
| `lib/options.lpscr` | `OptionSpec` table, `Options`, `parse_args`, `parse_count` |
| `lib/usage.lpscr` | `usage()`, `version_line()` |
| `lib/console.lpscr` | `ConsoleLogger`, a `loup.log` `Logger` that writes to stderr; `make_logger` |
| `lib/reader.lpscr` | `CsvError`, `split_records`, `read_table`, `Table`, `letter_name`, `unique_names` |
| `lib/columns.lpscr` | `select_columns`: `-c`/`-C` lists against the header |
| `lib/infer.lpscr` | `ColumnType`, `Cell`, null set, `parse_bool/number/date/datetime`, `infer_column` |
| `lib/stats.lpscr` | `ColumnStats`, `describe`, generic `tally` and `extremes`, `median`, `sample_stdev` |
| `lib/format.lpscr` | `format_number`, `group_digits`, `show_cell` |
| `lib/report.lpscr` | the `Statistic` registry, `render_text`, `render_one`, `stats_table`, `render_csv`, `render_look`, `render_names` |
| `lib/report_json.lpscr` | `render_json` (`system.json`, `Any`) |

### Reading

`data.csv.parse` walks its input with `substring(i, i + 1)`, which costs time
in proportion to `i` in the interpreters, so parsing a whole 70 KB file takes
seconds. `split_records` therefore cuts the text into records first: it
splits at `\n` and keeps joining lines while the number of `"` seen is odd
(a quoted field spans the line break). Each record, usually one line, is
parsed alone; its first line number is kept for messages. A
`CSVParseError` from `parse` (stray or unterminated quote) becomes a
`CsvError` with the file's line and column.

`read_table` drops the byte order mark and the `-K` lines, takes the header
(or makes letter names for `-H`), fixes empty and repeated names with a
`set[string]` of names seen, and transposes the records into one list of
raw strings per column, padding short records with `""` and logging a
warning for long ones.

### Types and cells

```loup
pub enum ColumnType { Boolean, Number, Date, DateTime, Text }
pub enum Cell { Null, Flag(bool), Num(value: float, places: int),
                Day(days: int, iso: string), Moment(millis: int, iso: string), Str(text: string) }
```

`infer_column` tries the types in order with a labelled loop: for each
candidate it converts every raw value to a `Cell` (`parse_as`), and the first
value that does not fit continues the outer loop with the next type. It
returns the type and the cells as a tuple, so each value is parsed at most
once per candidate. Numbers are validated character by character and then
converted with `system.text.parseFloat`; dates and times go through
`core.datetime` (`Date.fromIsoformat`, `Time.fromIsoformat`, `DateTime`),
whose `ValueError` marks an invalid date.

### Statistics

`describe` fills a `ColumnStats` struct. The `system.collections` functions
do the work: `filter` keeps the non-null cells, `tally[T]` (generic) groups
them with `groupBy` by an identity string, turns the groups into
`(first cell, count)` tuples with `toEntries` and a comprehension, and orders
them with `sortByDesc`, which is stable, so ties keep the order of first
appearance; `extremes[T]` returns the `minBy`/`maxBy` pair as a tuple;
`sumFloat` gives the sum, `max` the decimal places and `maxBy` the longest
text. `median` sorts a copy; `sample_stdev` divides by `n - 1` and uses
`core.math.sqrt`.

### Output

`statistics()` returns the registry of the thirteen statistics in csvkit's
order: a `Statistic` class with a `name` (CSV column, JSON key, option name),
a `label` (text report) and a function field `value: fn(ColumnStats, bool):
Option[string]`. The text report, the single-statistic output and the CSV and
look tables all walk this list, so a statistic is defined once. `nulls`,
`len` and `freq` get the small decorations csvkit gives them in the text
report.

`render_csv` writes the table with `data.csv.write`; each most-common value
is first quoted with `escapeField`, so a value holding `, ` can be told apart
in the joined `freq` field. `render_look` measures each column, right-aligns
the columns whose cells are all numbers (`system.text.padStart`) and
left-aligns the rest (`padEnd`). `render_json` builds `dict[string, Any]`
objects and prints them with `system.json.stringifyIndented`; numbers are
rounded to three decimals and whole numbers are written as integers.

### Options

`OptionSpec` values (built with named arguments: `opt(long = "--columns",
short = "c", value = true)`) describe every option. `parse_args` expands the
words into `(spec, value)` steps, then applies them in order to an `Options`
value with `with` copies (`o with (delimiter = value)`), validating values
as it goes. Output modes and single statistics are each recorded once; a
second one is a usage error.

### Logging

`ConsoleLogger` extends `loup.log`'s `Logger` and overrides `log` to write
`csvstat: LEVEL: message` to stderr (the stock logger prints to stdout,
which would mix with the report). The level is WARN by default, INFO with
`-v` and DEBUG with `-vv`.

## Error handling

| Situation | Message | Status |
|---|---|---|
| usage error | `csvstat: MESSAGE` + `Try 'csvstat --help' ...` | 2 |
| missing file, directory | `csvstat: FILE: No such file or directory` / `Is a directory` | 1 |
| malformed CSV | `csvstat: FILE:LINE:COLUMN: stray quote ...`, `csvstat: FILE:LINE: unterminated quoted field` (the record's first line) | 1 |
| invalid column | csvkit's messages (Requirement 4.3) | 1 |
| long record, renamed header | `csvstat: warning: ...` | (continues) |

The self-hosted `loup run` cannot catch `IoError`, so the script checks
`exists` and `isDir` before `readText`.

## Testing

- Unit tests (`tests/*_test.lpscr`, `make test`): options, reader, columns,
  inference, statistics, formatting, the reports. The CSV report is read
  back with `data.csv.parseRecords`.
- `tests/e2e.sh` (`make e2e`) runs the script with `loup run` on the
  fixtures in `tests/fixtures/` and compares stdout, stderr and the exit
  status with expected text; the full reports of `people.csv` are kept in
  `tests/expected/`.

## Differences from the original

- Types are inferred by this program's own rules: `0`/`1` columns are
  Number (csvkit makes them Boolean), dates must be ISO `YYYY-MM-DD`, and
  there is no TimeDelta type; such values are Text.
- `Unique values` and `Most common values` leave nulls out.
- The median is the usual middle value; agate's percentile method can differ
  on even counts.
- Numbers are rounded half up to three decimals; there is no
  `--decimal-format`, `--locale`, `-e/--encoding`, `-S`, `--sniff-limit` or
  `--zero`.
- Blank lines are skipped; a short record is padded with nulls and a long
  record is cut with a warning (agate refuses ragged tables).
- `--count` prints the number of data rows read, after `-K` and the header.
- `-v` logs progress to stderr instead of enabling Python tracebacks.
