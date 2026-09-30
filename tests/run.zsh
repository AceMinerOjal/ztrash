#!/usr/bin/env zsh
#
# ztrash test harness
#
# Pure zsh, no external test framework. Every case runs the real ztrash
# binary against a throwaway XDG_DATA_HOME so it never touches a real trash.
#
# Usage:
#   tests/run.zsh              run everything
#   tests/run.zsh <substring>  run cases whose name contains <substring>
#
# MIT License
# Copyright (c) 2026 AceMinerOjal

emulate -L zsh
setopt EXTENDED_GLOB NO_UNSET
# EPOCHREALTIME lives in zsh/datetime; the perf cases need it.
zmodload zsh/datetime 2>/dev/null

typeset -g TEST_ROOT=${0:A:h:h}
typeset -g ZTRASH=$TEST_ROOT/ztrash
typeset -g FILTER=${1:-}

typeset -g TMPBASE=$(mktemp -d "${TMPDIR:-/tmp}/ztrash-tests.XXXXXX") || exit 1
trap 'rm -rf -- "$TMPBASE"' EXIT INT TERM

# Real PATH, so a case that stubs out a command (fzf) cannot leak the stub
# into the cases that follow.
typeset -g REAL_PATH=$PATH
typeset -g PASS=0 FAIL=0 SKIP=0
typeset -ga FAILED=()

# --- Sandbox ---------------------------------------------------------------

# Each case gets a fresh home + trash. Colour and prompts are disabled so the
# output is deterministic, and COLUMNS is forced to something sane (zsh sets
# COLUMNS=0 in non-tty contexts, which is the bug class these tests guard).
setup_case() {
    typeset -g CASE_DIR=$TMPBASE/$1
    rm -rf -- "$CASE_DIR"
    mkdir -p "$CASE_DIR/home" "$CASE_DIR/work" "$CASE_DIR/share"
    typeset -g HOME=$CASE_DIR/home
    typeset -g XDG_DATA_HOME=$CASE_DIR/share
    typeset -g XDG_CONFIG_HOME=$CASE_DIR/home/.config
    typeset -g TRASH_DIR=$XDG_DATA_HOME/Trash
    typeset -g FILES_DIR=$TRASH_DIR/files
    typeset -g INFO_DIR=$TRASH_DIR/info
    mkdir -p "$FILES_DIR" "$INFO_DIR"
    ZTRASH_COLS=100
    export HOME XDG_DATA_HOME XDG_CONFIG_HOME ZTRASH_NO_COLOR=1 ZTRASH_COLS
    unset ZTRASH_TRASH_DIR ZTRASH_PURGE_DAYS ZTRASH_INTERVAL ZTRASH_FORCE_COLOR
    typeset -g PATH=$REAL_PATH
}

# Run the real binary from inside the sandbox work dir, so cases can use plain
# relative filenames the way a user would. Output is captured by the caller
# via $(...), so ztrash always sees a non-tty stdout here -- which is exactly
# the condition under which the COLUMNS=0 bug used to wipe the path column.
zt() {
    builtin cd -q -- "$CASE_DIR/work" || return 1
    command zsh "$ZTRASH" "$@"
}

# --- Assertions ------------------------------------------------------------

ok() { (( PASS++ )) }

bad() {
    (( FAIL++ ))
    FAILED+=("$CURRENT: $1")
    print -r -- "  \e[31mFAIL\e[0m $1"
    local -a extra
    extra=("${(@f)2}")
    local line
    for line in $extra; do
        [[ -n $line ]] && print -r -- "       $line"
    done
}

assert_eq() {
    local want=$1 got=$2 what=$3
    if [[ $want == "$got" ]]; then ok
    else bad "$what" "want: ${(qqq)want}
 got : ${(qqq)got}"; fi
}

assert_ne() {
    local a=$1 b=$2 what=$3
    if [[ $a != "$b" ]]; then ok
    else bad "$what" "both: ${(qqq)a}"; fi
}

assert_contains() {
    local haystack=$1 needle=$2 what=$3
    if [[ $haystack == *$needle* ]]; then ok
    else bad "$what" "looking for: ${(qqq)needle}
 in: ${(qqq)haystack}"; fi
}

assert_not_contains() {
    local haystack=$1 needle=$2 what=$3
    if [[ $haystack != *$needle* ]]; then ok
    else bad "$what" "should not contain: ${(qqq)needle}
 in: ${(qqq)haystack}"; fi
}

assert_file() {
    if [[ -e $1 ]]; then ok; else bad "file exists: $1" "missing: $1"; fi
}

assert_no_file() {
    if [[ ! -e $1 ]]; then ok; else bad "file gone: $1" "still present: $1"; fi
}

assert_dir() {
    if [[ -d $1 ]]; then ok; else bad "dir exists: $1" "missing: $1"; fi
}

assert_no_dir() {
    if [[ ! -d $1 ]]; then ok; else bad "dir gone: $1" "still present: $1"; fi
}

# --- Runner ----------------------------------------------------------------
CURRENT=""

# `it` runs the named case function. Cases are plain functions, which keeps
# each body a real syntax-checked block rather than a quoted string.
it() {
    local name=$1
    # Case bodies are functions, so their names use underscores. A second
    # argument overrides the derived name when that is clearer.
    local fn=${2:-${name//-/_}}
    [[ -n $FILTER && $name != *$FILTER* ]] && return 0
    CURRENT=$name
    if (( ! ${+functions[$fn]} )); then
        bad "case '$name' has no body" "expected function: $fn"
        return 1
    fi
    setup_case "$name"
    print -r -- "  \e[2m•\e[0m $name"
    $fn
    return 0
}

# --- Helpers used by cases -------------------------------------------------

# Write a file into the sandbox work dir.
mkfile() {
    local name=$1 content=${2:-x}
    mkdir -p -- "$CASE_DIR/work/${name:h}" 2>/dev/null
    print -r -- "$content" > "$CASE_DIR/work/$name"
    return 0
}

# Count trashinfo entries.
nitems() {
    local -a f
    f=("$INFO_DIR"/*.trashinfo(N))
    print -r -- ${#f}
}

# Path recorded in the (single) trashinfo.
info_path() {
    local -a f
    f=("$INFO_DIR"/*.trashinfo(N))
    (( ${#f} == 1 )) || return 1
    local line
    while IFS= read -r line; do
        [[ $line == (Path)=* ]] && { print -r -- "${line#*=}"; return 0 }
    done < $f[1]
    return 1
}

# The on-disk name of the (single) trashed payload.
info_base() {
    local -a f
    f=("$INFO_DIR"/*.trashinfo(N))
    print -r -- ${f[1]:t:r}
}

# Rewrite the DeletionDate of every entry whose trashinfo name contains $1.
# Tests that depend on list order use this instead of relying on the order two
# items happen to be binned in during the same second.
age_item() {
    local needle=$1 stamp=$2
    local -a f
    f=("$INFO_DIR"/*"$needle"*.trashinfo(N))
    (( ${#f} )) || return 1
    local file line
    local -a out
    for file in $f; do
        out=()
        while IFS= read -r line; do
            [[ $line == DeletionDate=* ]] && line="DeletionDate=$stamp"
            out+=("$line")
        done < $file
        print -l -- $out > $file
    done
    return 0
}

print -r -- "\e[1;36mztrash test suite\e[0m  (${ZTRASH:t})"
print -r -- ""

source ${0:A:h}/cases.zsh

print -r -- ""
print -r -- "\e[1mresults\e[0m  $PASS passed, $FAIL failed"
if (( FAIL )); then
    print -r -- "\e[31mfailures:\e[0m"
    local f
    for f in $FAILED; do print -r -- "  - $f"; done
    exit 1
fi
exit 0
