#!/usr/bin/env bash
# End-to-end tests: run bin/csvstat.lpscr with `loup run` and compare its
# standard output (byte for byte), standard error where it matters, and exit
# status with the expected ones.
#
# usage: tests/e2e.sh [LOUP]     (run from the repository root)

set -u
LOUP=${1:-loup}
SCRIPT=bin/csvstat.lpscr
PEOPLE=tests/fixtures/people.csv
ORDERS=tests/fixtures/orders.tsv
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# run ARGS...: the script under test, with ARGS after `--` so that long
# options reach it, standard input from the file named by $IN (default
# /dev/null), output to $TMP/out and $TMP/err. Returns its exit status.
run() {
    "$LOUP" run "$SCRIPT" -- "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
}

report() {
    local name=$1 status=$2 want_status=$3 want_file=$4 got_file=$5
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$got_file"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$want_file" "$got_file" | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check_file NAME STATUS EXPECTED_FILE [ARGS...]: compare standard output.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    run "$@"
    report "$name" $? "$want_status" "$want_file" "$TMP/out"
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]: compare standard error.
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    run "$@"
    report "$name" $? "$want_status" "$TMP/want" "$TMP/err"
}

# --- full reports (expected files reviewed by hand) ---------------------------

check_file "text report" 0 tests/expected/people.txt  "$PEOPLE"
check_file "csv report"  0 tests/expected/people.csv  --csv "$PEOPLE"
check_file "json report" 0 tests/expected/people.json --json "$PEOPLE"
check_file "look report" 0 tests/expected/people.look --look "$PEOPLE"

# --- single statistics ----------------------------------------------------------

check "mean per column" 0 '  1. name: None
  2. age: 36.143
  3. height: 1.746
  4. member: None
  5. joined: None
  6. last_login: None
  7. city: None
  8. score: 1,027.196
' --mean "$PEOPLE"

check "one column: bare value" 0 $'Number\n' --type -c score "$PEOPLE"
check "freq" 0 $'{ "Lisbon": 4, "Porto, Norte": 1, "Faro": 1 }\n' --freq --freq-count 3 -c city "$PEOPLE"
check "max of dates" 0 $'  5. joined: 2023-02-28\n  6. last_login: 2026-10-03T23:59:59\n' --max -c joined,last_login "$PEOPLE"
check "unique and prefix" 0 $'  4. member: 2\n  7. city: 5\n' --uniq -c member,city "$PEOPLE"
check "count" 0 $'8\n' --count "$PEOPLE"
check "names" 0 '  1: name
  2: age
  3: height
  4: member
  5: joined
  6: last_login
  7: city
  8: score
' -n "$PEOPLE"

# --- columns ----------------------------------------------------------------------

check "range and name, csv" 0 'column_id,column_name,type,nulls,nonnulls,unique,min,max,sum,mean,median,stdev,len,maxprecision,freq
8,score,Number,True,7,6,-35.25,2400,7190.375,1027.196,980,734.648,,3,"980, 1250.5, 2400, -35.25, 1000"
2,age,Number,True,7,5,28,51,253,36.143,34,9.227,,0,"28, 34, 45, 51, 39"
3,height,Number,True,7,7,1.6,1.9,12.22,1.746,1.75,0.098,,2,"1.68, 1.82, 1.75, 1.9, 1.6"
' --csv -c score,2-3 "$PEOPLE"

check "exclude" 0 $'  1. name: Text\n  4. member: Boolean\n  7. city: Text\n' --type -C 2-3,5-6,score "$PEOPLE"

# --- delimiters, currency, grouping, --look -----------------------------------------

check "tabs and currency" 0 '| column_id | column_name | type   | nulls | nonnulls | unique | min | max       | sum       | mean       | median   | stdev      | len | maxprecision | freq                                   |
| --------- | ----------- | ------ | ----- | -------- | ------ | --- | --------- | --------- | ---------- | -------- | ---------- | --- | ------------ | -------------------------------------- |
|         3 | units       | Number | False |        6 |      6 |   0 |     2,500 |     4,137 |      689.5 |    197.5 |    994.246 |     |            0 | 1,200, 85, 310, 42, 2,500              |
|         4 | revenue     | Number | False |        6 |      6 |   0 | 61,250.75 | 86,030.25 | 14,338.375 | 4,937.75 | 23,623.356 |     |            2 | 14,400, 2,125.5, 7,750, 504, 61,250.75 |
' -t --look -c units,revenue "$ORDERS"

check "no grouping" 0 $'86030.25\n' -tG --sum -c revenue "$ORDERS"
check "semicolons" 0 $'  1. a: 3.5\n  2. b: None\n' --mean -d ';' <(printf 'a;b\n3;x\n4;y\n')
check "json one line" 0 '[{"column_id":3,"column_name":"units","type":"Number","nulls":false,"nonnulls":6,"unique":6,"min":0,"max":2500,"sum":4137,"mean":689.5,"median":197.5,"stdev":994.246,"len":null,"maxprecision":0,"freq":[{"value":1200,"count":1},{"value":85,"count":1}]}]
' -t --json --indent 0 --freq-count 2 -c units "$ORDERS"

# --- input shapes ----------------------------------------------------------------------

# A byte order mark, CRLF line ends, an empty and a repeated header name, a
# quoted line break, a blank line, a short and a long record.
printf '\357\273\277id,,id\r\n1,"two\r\nlines",x\r\n\r\n2,b\r\n3,c,y,extra\r\n' > "$TMP/quirks.csv"
check "quirks" 0 '  1: id
  2: b
  3: id_2
' -n "$TMP/quirks.csv"
check "quirks values" 0 $'  1. id: 1\n  2. b: 10\n  3. id_2: 1\n' --len -I "$TMP/quirks.csv"
check_err "quirks warnings" 0 "csvstat: warning: column 3 is also named 'id'; calling it 'id_2'
csvstat: warning: $TMP/quirks.csv:6: 4 fields, but the header has 3; ignoring the rest
" --count "$TMP/quirks.csv"

printf '# exported 2026-10-20\n\n10,x\n20,y\n30,z\n' > "$TMP/noheader.csv"
check "skip lines, no header" 0 $'  1. a: 60\n  2. b: None\n' -K 2 -H --sum "$TMP/noheader.csv"
check "no header names" 0 $'  1: a\n  2: b\n' -K2 -H -n "$TMP/noheader.csv"

printf 'v\n1\n-\n?\n3\n' > "$TMP/nulls.csv"
check "null values" 0 $'Number\n' --type --null-value - --null-value '?' "$TMP/nulls.csv"
check "without them: text" 0 $'Text\n' --type "$TMP/nulls.csv"
check "blanks" 0 $'4\n' --non-nulls --blanks <(printf 'x\n""\nn/a\nnull\n.\n')
check "blanks off" 0 $'0\n' --non-nulls <(printf 'x\n""\nn/a\nnull\n.\n')

IN=$PEOPLE check "standard input" 0 $'8\n' --count
IN=$PEOPLE check "dash is standard input" 0 $'2\n' --unique -c member -
check "empty input" 0 $'Row count: 0\n' /dev/null
check "header only" 0 '  1. "a"

	Type of data:          Text
	Contains null values:  False
	Non-null values:       0
	Unique values:         0

Row count: 0
' <(printf 'a\n')

# --- logging ------------------------------------------------------------------------------

check_err "verbose" 0 "csvstat: info: reading $PEOPLE
csvstat: info: $PEOPLE: 9 record(s)
csvstat: info: 8 column(s), 8 row(s)
csvstat: info: describing 1 of 8 column(s)
" -v --type -c age "$PEOPLE"
IN=$PEOPLE check_err "very verbose" 0 "csvstat: info: reading (standard input)
csvstat: info: (standard input): 9 record(s)
csvstat: info: 8 column(s), 8 row(s)
csvstat: debug: column 2 'age': Number, 7 value(s), 1 null(s)
csvstat: info: describing 1 of 8 column(s)
" -vv --type -c age

# --- errors and exit statuses -----------------------------------------------------------

check_err "missing file" 1 $'csvstat: nope.csv: No such file or directory\n' nope.csv
check "missing file, no output" 1 '' nope.csv
check_err "directory" 1 $'csvstat: tests: Is a directory\n' tests
printf 'a,b\n1,2\n3,x"y\n' > "$TMP/stray.csv"
check_err "stray quote" 1 "csvstat: $TMP/stray.csv:3:4: stray quote after unquoted text
" "$TMP/stray.csv"
printf 'a,b\n1,"open\n2,3\n' > "$TMP/open.csv"
check_err "unterminated quote" 1 "csvstat: $TMP/open.csv:2: unterminated quoted field
" "$TMP/open.csv"
check_err "unknown column" 1 "csvstat: Column 'zip' is invalid. It is neither an integer nor a column name. Column names are: 'name', 'age', 'height', 'member', 'joined', 'last_login', 'city', 'score'
" -c zip "$PEOPLE"
check_err "column out of range" 1 $'csvstat: Column 9 is invalid. The last column is \'score\' at index 8.\n' -c 7-9 "$PEOPLE"

USAGE_HINT="Try 'csvstat --help' for more information."
check_err "unknown long option" 2 "csvstat: unrecognized option '--bogus'
$USAGE_HINT
" --bogus
check_err "unknown short option" 2 "csvstat: invalid option -- 'x'
$USAGE_HINT
" -x
check_err "missing value" 2 "csvstat: option requires an argument -- 'c'
$USAGE_HINT
" -c
check_err "ambiguous" 2 "csvstat: option '--me' is ambiguous; possibilities: '--mean' '--median'
$USAGE_HINT
" --me "$PEOPLE"
check_err "two outputs" 2 "csvstat: --csv and --look cannot be combined
$USAGE_HINT
" --csv --look "$PEOPLE"
check_err "two statistics" 2 "csvstat: only one statistic may be given (--min, --max)
$USAGE_HINT
" --min --max "$PEOPLE"
check_err "bad delimiter" 2 "csvstat: the delimiter must be a single character, not '::'
$USAGE_HINT
" -d :: "$PEOPLE"
check_err "two files" 2 "csvstat: extra operand '$ORDERS'
$USAGE_HINT
" "$PEOPLE" "$ORDERS"
check "usage error, no output" 2 '' --freq-count 0 "$PEOPLE"

check "version" 0 $'csvstat (loup-cmd-csvstat) 0.1.0\n' --version
run -h
status=$?
head -1 "$TMP/out" > "$TMP/got"
printf 'usage: csvstat [OPTION]... [FILE]\n' > "$TMP/want"
report "help" $status 0 "$TMP/want" "$TMP/got"

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
