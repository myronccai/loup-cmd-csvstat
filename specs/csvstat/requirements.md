# Requirements: csvstat

## Introduction

`csvstat` prints descriptive statistics for every column of a CSV file, like
csvkit's `csvstat`: the inferred type of each column, how many values are
null, distinct and present, the smallest and largest values, sum, mean,
median and standard deviation of numbers, the longest text, and the most
common values. Besides csvkit's text report and its `--csv` and `--json`
tables, `--look` prints the statistics as one aligned table, the way
`csvstat --csv | csvlook` would.

It is a `host.scripted` program (`bin/csvstat.lpscr`, run with `loup run`)
for people who explore data files in a shell.

## Requirements

### Requirement 1: Reading CSV

**User Story:** As a user, I want csvstat to read the CSV files I have, with
their quirks, so that I do not have to clean them first.

#### Acceptance Criteria

1. WHEN a FILE operand is given, THE reader SHALL read it; WHEN it is `-` or absent, THE reader SHALL read standard input.
2. THE reader SHALL parse RFC 4180 CSV: quoted fields, `""` inside quotes, delimiters and line breaks inside quoted fields, `\n` and `\r\n` line ends, a missing final line break.
3. WHEN `-d CHAR` or `-t` is given, THE reader SHALL split fields at CHAR or at a tab instead of `,`.
4. WHEN `-K N` is given, THE reader SHALL ignore the first N lines.
5. THE reader SHALL take the first record as the header, unless `-H` is given; then it SHALL name the columns `a`, `b`, ... `z`, `aa`, `bb`, ... and count the first record as data.
6. THE reader SHALL name an empty header cell by its letter name and rename a repeated name `NAME_2`, `NAME_3`, ..., with a warning.
7. THE reader SHALL skip blank lines, pad a short record with nulls, and ignore the extra fields of a long record with a warning that names the line.
8. THE reader SHALL drop a UTF-8 byte order mark at the start of the input.
9. WHEN a record has a stray quote, THE program SHALL print `csvstat: FILE:LINE:COLUMN: stray quote after unquoted text`; WHEN a quoted field is never closed, `csvstat: FILE:LINE: unterminated quoted field` with the line its record starts on; both exit 1.
10. WHEN the FILE does not exist or is a directory, THE program SHALL print `csvstat: FILE: No such file or directory` or `csvstat: FILE: Is a directory` and exit 1.

### Requirement 2: Nulls and types

**User Story:** As a user, I want each column's type inferred so that numbers
and dates get the statistics that make sense for them.

#### Acceptance Criteria

1. THE program SHALL treat a value as null when, trimmed and lower-cased, it is empty, `na`, `n/a`, `none`, `null` or `.`, or equals a `--null-value` given on the command line.
2. WHEN `--blanks` is given, THE program SHALL treat only the `--null-value` strings as null.
3. THE program SHALL give each column the first type, in the order Boolean, Number, Date, DateTime, Text, that accepts every non-null value of the column; a column with no non-null value is Text.
4. Boolean SHALL accept `true`, `false`, `yes`, `no`, `t`, `f`, `y`, `n` in any case.
5. Number SHALL accept an optional sign, an optional currency sign (`$`, `€`, `£`, `¥`), digits with optional `,` thousands separators in groups of three, an optional fraction and an optional exponent.
6. Date SHALL accept a valid ISO date `YYYY-MM-DD`; DateTime SHALL accept a date, or a date and a time `HH:MM`, `HH:MM:SS` or `HH:MM:SS.fff` separated by `T` or a space, with an optional `Z`.
7. WHEN `-I` is given, THE program SHALL treat every column as Text.

### Requirement 3: Statistics

**User Story:** As a user, I want the usual descriptive statistics per column
so that I can see what a file holds at a glance.

#### Acceptance Criteria

1. THE program SHALL report for every column its type, whether it has nulls, the number of non-null values, the number of distinct non-null values and the most common values.
2. FOR Number, Date and DateTime columns THE program SHALL report the smallest and largest value.
3. FOR Number columns THE program SHALL report the sum, the mean, the median (the middle value, or the mean of the two middle values), the sample standard deviation (with at least two values) and the most decimal places written.
4. FOR Text columns THE program SHALL report the length of the longest value in characters.
5. THE most common values SHALL be the `--freq-count` (default 5) most frequent distinct values, most frequent first and, among equals, in the order they first appear.
6. THE program SHALL print numbers rounded to at most three decimals, with `,` thousands separators unless `-G` is given.

### Requirement 4: Column selection

**User Story:** As a user, I want to describe only some columns so that a
wide file stays readable.

#### Acceptance Criteria

1. WHEN `-c LIST` is given, THE program SHALL describe only the listed columns, in the order listed; WHEN `-C LIST` is given, THE program SHALL leave the listed columns out.
2. A LIST item SHALL be a column name, a 1-based index, a range `N-M` or `N:M`, or an open range (`N-`, `-M`); an item made only of digits SHALL be an index, as in csvkit, and any other item that equals a column name SHALL be that name.
3. WHEN an item names no column, THE program SHALL print `csvstat: Column 'X' is invalid. It is neither an integer nor a column name. Column names are: ...` and exit 1; WHEN an index is out of range, `csvstat: Column N is invalid. The last column is 'NAME' at index M.` and exit 1.
4. WHEN `-n` is given, THE program SHALL print each column's index and name (`  1: name`) and exit 0.

### Requirement 5: Output

**User Story:** As a user, I want the statistics as a readable report or as
data for other tools.

#### Acceptance Criteria

1. By default THE program SHALL print, per column, a block headed `  N. "NAME"` with one labelled line per statistic, and end with `Row count: N`.
2. WHEN `--csv` is given, THE program SHALL print a CSV table with the header `column_id,column_name,type,nulls,nonnulls,unique,min,max,sum,mean,median,stdev,len,maxprecision,freq` and a row per column.
3. WHEN `--look` is given, THE program SHALL print the same table framed with `|`, numeric columns right-aligned, and a `| --- |` rule under the header.
4. WHEN `--json` is given, THE program SHALL print a JSON array with an object per column holding the same keys, numbers as JSON numbers, `null` where a statistic does not apply and `freq` as a list of `{"value", "count"}`; `--indent N` sets the indentation (0: one line).
5. WHEN one statistic option (`--type`, `--nulls`, `--non-nulls`, `--unique`, `--min`, `--max`, `--sum`, `--mean`, `--median`, `--stdev`, `--len`, `--max-precision`, `--freq`) is given, THE program SHALL print only that statistic, as `  N. NAME: VALUE` per column, or the bare value when one column is described.
6. WHEN `--count` is given, THE program SHALL print only the number of data rows.

### Requirement 6: Command line and diagnostics

**User Story:** As a user and script author, I want conventional options,
messages and exit statuses.

#### Acceptance Criteria

1. THE parser SHALL accept short options alone, combined (`-tH`) or with attached values (`-d;`), long options as `--name VALUE` or `--name=VALUE`, options after the operand, and `--` to end the options.
2. WHEN an option is unknown, lacks its value or gets a bad value, or when two output modes or two statistics are combined, or more than one FILE is given, THE program SHALL print `csvstat: MESSAGE` and `Try 'csvstat --help' for more information.` to stderr and exit 2.
3. WHEN `-h` or `--help` is given, THE program SHALL print the usage text; WHEN `-V` or `--version` is given, `csvstat (loup-cmd-csvstat) 0.1.0`; both exit 0.
4. WHEN `-v` is given, THE program SHALL log what it reads and infers to stderr (`csvstat: info: ...`); `-vv` SHALL add a line per column. Warnings SHALL be printed without `-v`.
5. THE program SHALL exit 0 on success, 1 when the input cannot be read or parsed or a column is invalid, and 2 on a usage error.
