# loup-cmd-csvstat

csvkit's `csvstat` written as a [Loup](https://code-craft.ai/references/loup)
script: it infers the type of every column of a CSV file and prints its
nulls, distinct values, range, sum, mean, median, standard deviation, longest
text and most common values, as csvkit's report, as CSV, as JSON, or as one
aligned csvlook-style table (`--look`).

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is a `host.scripted` program: a thin `.lpscr` entry script in `bin/`
over `.lpscr` modules in `lib/`, run with `loup run`.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later (`loup` and `loup-bootstrap` on `PATH`); see [Installing Loup Lite](#installing-loup-lite).
- `make` and `bash` for the checks and tests. No C compiler: nothing is built.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make run ARGS="--look tests/fixtures/people.csv"   # loup run bin/csvstat.lpscr -- ARGS
make ci                                           # check, unit tests, end-to-end tests
```

The script is executable (`#!/usr/bin/env -S loup run`).
[`tests/fixtures/people.csv`](tests/fixtures/people.csv) has a column of each
type, nulls written several ways, and quoted fields:

```text
$ head -4 tests/fixtures/people.csv
name,age,height,member,joined,last_login,city,score
Alice,34,1.68,yes,2019-03-14,2026-10-01 08:15,Lisbon,"1,250.5"
Bob,28,1.82,no,2021-07-01,2026-09-30T22:05:10,"Porto, Norte",980
Carol,n/a,1.75,yes,2018-11-23,,Lisbon,"2,400"
$ ./bin/csvstat.lpscr -c age,city tests/fixtures/people.csv
  2. "age"

	Type of data:          Number
	Contains null values:  True (excluded from calculations)
	Non-null values:       7
	Unique values:         5
	Smallest value:        28
	Largest value:         51
	Sum:                   253
	Mean:                  36.143
	Median:                34
	StDev:                 9.227
	Most decimal places:   0
	Most common values:    28 (3x)
	                       34 (1x)
	                       45 (1x)
	                       51 (1x)
	                       39 (1x)

  7. "city"

	Type of data:          Text
	Contains null values:  False
	Non-null values:       8
	Unique values:         5
	Longest value:         12 characters
	Most common values:    Lisbon (4x)
	                       Porto, Norte (1x)
	                       Faro (1x)
	                       Coimbra (1x)
	                       Braga (1x)

Row count: 8
```

`--look` prints the statistics as one table, a row per column, with the
numeric columns right-aligned; `--csv` prints the same table as CSV:

```text
$ loup run bin/csvstat.lpscr -- --look -c 2-4 tests/fixtures/people.csv
| column_id | column_name | type    | nulls | nonnulls | unique | min | max | sum   | mean   | median | stdev | len | maxprecision | freq                       |
| --------- | ----------- | ------- | ----- | -------- | ------ | --- | --- | ----- | ------ | ------ | ----- | --- | ------------ | -------------------------- |
|         2 | age         | Number  | True  |        7 |      5 |  28 |  51 |   253 | 36.143 |     34 | 9.227 |     |            0 | 28, 34, 45, 51, 39         |
|         3 | height      | Number  | True  |        7 |      7 | 1.6 | 1.9 | 12.22 |  1.746 |   1.75 | 0.098 |     |            2 | 1.68, 1.82, 1.75, 1.9, 1.6 |
|         4 | member      | Boolean | False |        8 |      2 |     |     |       |        |        |       |     |              | True, False                |
```

One statistic at a time, for every column or (bare) for one:

```text
$ ./bin/csvstat.lpscr -- --median tests/fixtures/people.csv
  1. name: None
  2. age: 34
  3. height: 1.75
  4. member: None
  5. joined: None
  6. last_login: None
  7. city: None
  8. score: 980
$ ./bin/csvstat.lpscr -t -c units,revenue -- --sum tests/fixtures/orders.tsv
  3. units: 4,137
  4. revenue: 86,030.25
$ ./bin/csvstat.lpscr -t -c revenue -- --json --indent 0 --freq-count 2 tests/fixtures/orders.tsv
[{"column_id":4,"column_name":"revenue","type":"Number","nulls":false,"nonnulls":6,"unique":6,"min":0,"max":61250.75,"sum":86030.25,"mean":14338.375,"median":4937.75,"stdev":23623.356,"len":null,"maxprecision":2,"freq":[{"value":14400,"count":1},{"value":2125.5,"count":1}]}]
```

Diagnostics go to standard error. Forgetting `-t` on a tab-separated file
whose amounts hold commas shows the reader's warnings; `-v` adds progress:

```text
$ ./bin/csvstat.lpscr -v -n tests/fixtures/orders.tsv
csvstat: info: reading tests/fixtures/orders.tsv
csvstat: info: tests/fixtures/orders.tsv: 7 record(s)
csvstat: warning: tests/fixtures/orders.tsv:2: 2 fields, but the header has 1; ignoring the rest
csvstat: warning: tests/fixtures/orders.tsv:3: 2 fields, but the header has 1; ignoring the rest
csvstat: warning: tests/fixtures/orders.tsv:4: 2 fields, but the header has 1; ignoring the rest
csvstat: warning: tests/fixtures/orders.tsv:6: 2 fields, but the header has 1; ignoring the rest
csvstat: info: 1 column(s), 6 row(s)
  1: region	product	units	revenue	shipped
$ ./bin/csvstat.lpscr broken.csv; echo "status $?"
csvstat: broken.csv:3:4: stray quote after unquoted text
status 1
$ ./bin/csvstat.lpscr -c zip tests/fixtures/people.csv; echo "status $?"
csvstat: Column 'zip' is invalid. It is neither an integer nor a column name. Column names are: 'name', 'age', 'height', 'member', 'joined', 'last_login', 'city', 'score'
status 1
```

[`tests/expected/`](tests/expected/) holds the complete reports of
`people.csv` in all four forms.

### Options

| Option | Meaning |
|---|---|
| `-d`, `--delimiter CHAR` / `-t`, `--tabs` | field delimiter (default `,`) / tab |
| `-H`, `--no-header-row` | the first record is data; columns are named `a`, `b`, ... `z`, `aa`, `bb`, ... |
| `-K`, `--skip-lines N` | ignore the first N lines |
| `--null-value TEXT` | also treat TEXT as null (repeatable, any case) |
| `--blanks` | do not treat `""`, `na`, `n/a`, `none`, `null` and `.` as null |
| `-I`, `--no-inference` | every column is Text |
| `-c`, `--columns LIST` / `-C`, `--not-columns LIST` | describe only / all but these columns: names, 1-based indexes, ranges `2-4`, `3-`, `-2`, `1:3` |
| `-n`, `--names` | print the column indexes and names |
| `--look` / `--csv` / `--json` | one table with a row per column / the same as CSV / a JSON array (`--indent N`, default 2; 0 for one line) |
| `--type`, `--nulls`, `--non-nulls`, `--unique`, `--min`, `--max`, `--sum`, `--mean`, `--median`, `--stdev`, `--len`, `--max-precision`, `--freq` | print only that statistic |
| `--count` | print only the number of data rows |
| `--freq-count N` | most common values to list (default 5) |
| `-G`, `--no-grouping-separator` | numbers without thousands separators |
| `-v`, `--verbose` | progress on standard error; `-vv` adds a line per column |
| `-h`, `--help` / `-V`, `--version` | help text / `csvstat (loup-cmd-csvstat) 0.1.0` |

With no FILE, or with `-`, csvstat reads standard input. Short options can
be combined (`-tG`) and take attached values (`-d;`, `-K2`); long options
can be shortened to any unambiguous prefix (`--no-header`, `--uniq`).

**Long options need `--` under `loup run`.** `loup run SCRIPT ARGS` treats
words starting with `--` as its own flags, and the self-hosted `loup run` on
Linux x86-64 drops unknown ones silently. Write
`loup run bin/csvstat.lpscr -- --json FILE` (or
`./bin/csvstat.lpscr -- --json FILE`), or use the short options, which pass
through unchanged. `make run` adds the `--` for you.

**Types.** A column gets the first of Boolean (`true`/`false`, `yes`/`no`,
`t`/`f`, `y`/`n`), Number (`-1,234.50`, `$12`, `2.5e3`), Date
(`2026-10-20`), DateTime (a date, or a date and `HH:MM[:SS[.fff]]` after `T`
or a space, optional `Z`) and Text that accepts every non-null value. Numbers
print rounded to three decimals.

Exit status: `0` success, `1` the input cannot be read or parsed or a column
is invalid, `2` usage error.

## Differences from the original

- Types follow this program's rules: a column of `0` and `1` is Number
  (csvkit makes it Boolean), dates must be ISO `YYYY-MM-DD`, times are taken
  as written (no zones, no offsets), and there is no TimeDelta type; such
  values are Text.
- `Unique values` and `Most common values` leave nulls out; the median is
  the usual middle value (agate's percentile method can differ on even
  counts); numbers are rounded half away from zero.
- `--look` is new: csvkit gets the same table from `csvstat --csv | csvlook`.
  In the CSV and look tables a most-common value that holds `, ` is quoted.
- Blank lines are skipped, a short record is padded with nulls and a long
  record is cut with a warning (agate refuses ragged tables); a malformed
  record stops the run with its line and column.
- `-v` logs progress to standard error instead of enabling Python
  tracebacks. There is no `-e/--encoding`, `-S`, `-L/--locale`,
  `--decimal-format`, `-y/--snifflimit`, `-z/--maxfieldsize` or `--zero`.
- `--count` prints the number of data rows read (after `-K` and the header).

## What this example shows

- **`data.csv`**: `parse` per record (its parser slows down on long texts,
  so `lib/reader.lpscr` cuts the text into records first), `CSVParseError`
  turned into the program's own `CsvError` with line and column, `write` and
  `escapeField` for the CSV report, and `parseRecords` in the tests to read
  that report back.
- **`system.collections`** as the statistics engine: `groupBy`, `toEntries`
  and the stable `sortByDesc` rank the most common values; `minBy`/`maxBy`,
  `filter`, `filterMap`, `map`, `sumFloat`, `max`, `countWhere`, `find`,
  `all` and `rangeFrom` do the rest.
- **`system.text`**: `parseFloat` behind a hand-written number check,
  `padStart`/`padEnd` for the aligned reports, `count` and `parseInt`.
- **Generic functions and higher-order functions**: `tally[T]` and
  `extremes[T]` take a key function; the thirteen statistics are a registry
  of `Statistic` objects with a function-typed field, walked by every
  report; lambdas everywhere, arrow lambdas (`func(s: string) => s.len()`)
  for keys, `Option.map` to carry values through.
- **Enums**: `ColumnType` for the inferred type and `Cell` with payloads
  (`Num(value, places)`, `Day(days, iso)`, ...) for typed values, matched
  with nested patterns such as `Some(Cell.Num(value, _))`.
- **Tuples, comprehensions, labelled loops**: records are `(line, text)`
  pairs, `infer_column` returns `(ColumnType, list[Cell])` and tries the
  types with `continue candidates;`, and reports build their rows with list
  comprehensions.
- **Structs with `with` copies** (`o with (delimiter = value)` in the option
  parser), named arguments and defaults (`opt(long = "--csv")`), sets
  (`set[string]` for null words and header names), `core.datetime` to
  validate dates and times, `core.math`, `system.json` for `--json`, a custom
  exception with fields, and a `noreturn` failure helper.

## Limitations

- About 2,500 values a second under `loup run` (2,000 rows of 6 columns in
  5 s): every value is converted by interpreted Loup.
- The input is read whole. A file that exists but cannot be read
  (permissions) ends the run with `IoError` and status 1: the self-hosted
  `loup run` cannot catch `IoError`, so csvstat checks only that the file
  exists and is not a directory.
- `loup.log` would have carried the `-v` messages, but `make check`
  (`loup-bootstrap check`) cannot resolve a `loup.*` import in 1.26.0, so
  `lib/console.lpscr` is a small logger of its own.

## Layout

```text
bin/csvstat.lpscr          # the program (host.scripted entry script)
lib/appinfo.lpscr          # name, version, exit statuses
lib/options.lpscr          # option table, Options, parse_args
lib/usage.lpscr            # --help and --version text
lib/console.lpscr          # warnings and -v logging on standard error
lib/reader.lpscr           # records, header names, Table (data.csv)
lib/columns.lpscr          # -c and -C lists
lib/infer.lpscr            # nulls, ColumnType, Cell, the parser of each type
lib/stats.lpscr            # ColumnStats, describe, tally, extremes, median, stdev
lib/format.lpscr           # number and cell formatting
lib/report.lpscr           # the statistics registry, text, single, CSV and look output
lib/report_json.lpscr      # JSON output (system.json)
tests/*_test.lpscr         # unit tests (make test)
tests/e2e.sh               # end-to-end tests with loup run (make e2e)
tests/fixtures/            # people.csv, orders.tsv
tests/expected/            # people.csv's full reports: text, CSV, JSON, look
specs/csvstat/             # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every check and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
