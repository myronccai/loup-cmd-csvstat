# AGENTS.md

This repository is `csvstat`, csvkit's CSV statistics command written in
the Loup programming language, part of the loup-cmd series of example
applications. It is a `host.scripted` project: the program is the `.lpscr`
script `bin/csvstat.lpscr`, which `loup run` executes from source, over
`host.scripted` modules in `lib/`. Nothing is compiled.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # manifest: name, version, toolchain, [build] entry (bin/csvstat.lpscr), [test] pattern
├── Makefile                     # run, check, test, e2e, ci, clean
├── LICENSE                      # MIT license (copyright Code Craft AI LLC)
├── bin/
│   └── csvstat.lpscr            # the program: arguments, input, output, exit status (executable, shebang `loup run`)
├── lib/                         # the program's modules, all host.scripted
│   ├── appinfo.lpscr            # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── options.lpscr            # OptionSpec table, struct Options, parse_args(), parse_count()
│   ├── usage.lpscr              # usage(), version_line()
│   ├── console.lpscr            # enum Level, class Console (stderr diagnostics), make_console()
│   ├── reader.lpscr             # CsvError, Table, split_records(), parse_record(), unique_names(), read_table()
│   ├── columns.lpscr            # match_column(), parse_identifiers(), select_columns()
│   ├── infer.lpscr              # ColumnType, Cell, null_set(), parse_*(), infer_column(), identity(), sort_key()
│   ├── stats.lpscr              # ColumnStats, tally[T](), extremes[T](), median(), sample_stdev(), describe()
│   ├── format.lpscr             # group_digits(), format_number(), show_cell()
│   ├── report.lpscr             # class Statistic, statistics(), render_text/one/csv/look/names(), stats_table()
│   └── report_json.lpscr        # render_json() (system.json, Any)
├── tests/
│   ├── *_test.lpscr             # unit tests: func test_*(): void
│   ├── e2e.sh                   # end-to-end tests: runs the script with loup run
│   ├── fixtures/                # people.csv (every type, nulls, quotes), orders.tsv (tabs, currency)
│   └── expected/                # people.csv's full reports: people.txt, .csv, .json, .look
├── specs/csvstat/               # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
└── .github/workflows/ci.yml     # installs Loup and runs `make ci`
```

## Check, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`
and `bash`.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="--look tests/fixtures/people.csv"` | `loup run bin/csvstat.lpscr -- ARGS` |
| Run directly | `./bin/csvstat.lpscr -c 2-4 FILE` | long options only after `--` (see below) |
| Type-check | `make check` | `loup-bootstrap check bin/csvstat.lpscr` and the modules it imports |
| Unit tests | `make test` | each `tests/*_test.lpscr` in turn |
| One test file | `make test TESTS=tests/stats_test.lpscr` | |
| Matching tests | `make test TEST_ARGS="--filter median"` | tests whose name contains `median` |
| End-to-end tests | `make e2e` | `tests/e2e.sh`: output and exit status of `loup run` |
| Everything CI runs | `make ci` | check, test, e2e, then `--version` |
| Clean | `make clean` | removes `.temp/` |

Run `make ci` before reporting a change as done. Unit tests run under Stage0
(`loup-bootstrap`); the script runs under the self-hosted `loup run`, which
behaves differently in places (below), so only `make e2e` shows what users get.

Toolchain facts this project depends on (Loup 1.26.0, Linux x86-64):

- A script entry cannot be built (`E-BUILD-COMPILED`), so there is no build
  target. `loup-bootstrap check FILE` does type-check a script and its
  imports; `[build] entry` points at `bin/csvstat.lpscr`.
- `loup run SCRIPT --long` treats `--long` as its own flag; the self-hosted
  driver drops it silently. Script options go after `--`:
  `loup run bin/csvstat.lpscr -- --json FILE`. Short options pass through.
- `loup-bootstrap check` cannot resolve `loup.log` (`E-CHECK-DEP: module
  'loup/log' not found`), though `loup run` and `loup-bootstrap test` can;
  that is why `lib/console.lpscr` exists.
- Under the self-hosted `loup run`, a function that returns a struct or class
  gets no default parameter values when another module calls it (the
  parameters come through empty): `read_table` takes every argument.
- In both interpreters, constructing an enum payload or a struct with named
  arguments inside a lambda or a comprehension (`Cell.Str(text = v)`) fails
  once any function declares a `var` of the same name (`var text`); construct
  positionally there (`Cell.Str(v)`).
- Calling a function-typed field on a `for` loop variable (`stat.value(s, g)`
  in `for (stat in ...)`) fails in both interpreters; call it through a
  typed parameter (`evaluate(stat, s, g)`).
- Stage0's checker: a named function whose signature mentions a type from
  another module cannot be passed to a two-parameter generic such as
  `filterMap` or `map` (`expected 'list[T0]', found 'list[Cell]'`); pass a
  lambda.
- `unique` is a reserved word (the field is `distinct`); a top-level script
  variable must not share its name with an imported module (`columns`).
- The self-hosted `loup run` cannot catch `IoError`; check `exists`/`isDir`
  before `readText`.
- `data.csv.parse` slows down with the length of its input in the
  interpreters; parse one record at a time (`split_records`).
- `loup-bootstrap test` with all files at once fails random tests with an
  empty `RuntimeError` on a busy machine; the Makefile runs one file at a time
  with `--no-parallel`.

## Making a change

1. Update the spec in `specs/csvstat/` (see [specs/README.md](specs/README.md)).
2. Change the code: behaviour in `lib/`, top-level flow in `bin/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`. If a
   report changes, regenerate and review `tests/expected/`:
   `loup run bin/csvstat.lpscr -- --csv tests/fixtures/people.csv > tests/expected/people.csv`
   (likewise `people.txt` with no option, `people.json` with `--json` and
   `people.look` with `--look`).
4. Run `make ci`.
5. Tick the finished tasks in `specs/csvstat/tasks.md`.

Keep behaviour in functions that return values (the renderers return the
whole output), so unit tests can check it; only `bin/csvstat.lpscr` prints
the report, reads the input and calls `exit` (lib/console.lpscr prints
diagnostics to standard error).

## Conventions

- Every source file is `@mode(host.scripted)` (`.lpscr`); the entry script
  has a `#!/usr/bin/env -S loup run` line and the executable bit. Keep it
  thin: arguments, I/O, exit status.
- Imports are relative: `from ..lib.stats import (...)` in `bin/` and
  `tests/`, `from .infer import (...)` inside `lib/`. A script's package root
  is its own directory, so `from lib.stats` would not resolve.
- Add a statistic by adding a `Statistic` to `statistics()` in
  `lib/report.lpscr` (and a field to `ColumnStats`, a key in
  `lib/report_json.lpscr` and an option in `lib/options.lpscr`).
- Keep `APP_VERSION` in `lib/appinfo.lpscr` equal to `version` in
  `package.lppkg`.
- The skill documents toolchain 1.25.1; this project targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
