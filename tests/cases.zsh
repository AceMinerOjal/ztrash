#!/usr/bin/env zsh
#
# Regression cases for ztrash. Sourced by tests/run.zsh.
#
# Each case is a plain function; `it <name>` runs it. The name records the bug
# the case pins down.

# ===========================================================================
# Codec: byte-exact URL encoding with no python3 and no forks
# ===========================================================================

function codec_roundtrip_ascii {
    mkfile plain.txt >/dev/null
    zt plain.txt >/dev/null
    assert_eq "$CASE_DIR/work/plain.txt" "$(info_path)" 'unreserved path stored verbatim'
    zt -u >/dev/null
    assert_file "$CASE_DIR/work/plain.txt" 'restored'
}

function codec_encodes_reserved_bytes {
    mkfile 'a b+c&d.txt' >/dev/null
    zt 'a b+c&d.txt' >/dev/null
    local raw; raw=$(info_path)
    assert_contains "$raw" '%20' 'space encoded'
    assert_contains "$raw" '%2B' 'plus encoded'
    assert_contains "$raw" '%26' 'ampersand encoded'
    zt -u >/dev/null
    assert_file "$CASE_DIR/work/a b+c&d.txt" 'name restored byte for byte'
}

function codec_roundtrips_utf8 {
    mkfile 'üñí çödé ☕.txt' >/dev/null
    zt 'üñí çödé ☕.txt' >/dev/null
    local raw; raw=$(info_path)
    # The old pure-zsh fallback mangled this to %E9 / %2615.
    assert_not_contains "$raw" '%E9' 'no latin-1 mangling'
    assert_contains "$raw" '%C3%BC' 'utf-8 encoded as utf-8 bytes'
    zt -u >/dev/null
    assert_file "$CASE_DIR/work/üñí çödé ☕.txt" 'utf-8 name restored byte for byte'
}

function codec_roundtrips_percent_literals {
    mkfile '100%25 done.txt' >/dev/null
    zt '100%25 done.txt' >/dev/null
    zt -u >/dev/null
    assert_file "$CASE_DIR/work/100%25 done.txt" 'literal % survives the roundtrip'
}

function codec_survives_newline_in_name {
    mkfile $'two\nlines.txt' >/dev/null
    zt $'two\nlines.txt' >/dev/null
    zt -u >/dev/null
    assert_file "$CASE_DIR/work/two
lines.txt" 'newline in a filename restored'
}

function codec_fast_path_matches_loop {
    # url_encode/url_decode both short-circuit when there is nothing to do.
    # A fast path that disagrees with the byte loop is worse than no fast path,
    # so check the unencoded and the encoded case of the same name.
    mkfile 'plain-name.txt' >/dev/null
    zt 'plain-name.txt' >/dev/null
    local plain; plain=$(info_path)
    assert_contains "$plain" 'plain-name.txt' 'unreserved name stored verbatim'
    zt -u >/dev/null
    mkfile 'needs space&and#hash.txt' >/dev/null
    zt 'needs space&and#hash.txt' >/dev/null
    local enc; enc=$(info_path)
    assert_contains "$enc" '%20' 'space encoded on the slow path'
    assert_contains "$enc" '%26' 'ampersand encoded on the slow path'
    zt -u >/dev/null
    assert_file "$CASE_DIR/work/needs space&and#hash.txt" 'encoded name roundtrips'
}

it codec-roundtrip-ascii            codec_roundtrip_ascii
it codec-encodes-reserved-bytes     codec_encodes_reserved_bytes
it codec-roundtrips-utf8            codec_roundtrips_utf8
it codec-roundtrips-percent-literals codec_roundtrips_percent_literals
it codec-survives-newline-in-name   codec_survives_newline_in_name
it codec-fast-paths-agree-with-loop  codec_fast_path_matches_loop

# ===========================================================================
# COLUMNS=0 used to blank the path column whenever stdout was not a tty
# ===========================================================================

function list_shows_paths_when_piped {
    mkfile visible.txt >/dev/null
    zt visible.txt >/dev/null
    local out; out=$(zt -l)
    assert_contains "$out" 'visible.txt' 'path column survives a pipe'
    assert_not_contains "$out" '%20' 'no percent-encoded fallback leaks out'
}

function find_shows_paths_when_piped {
    mkfile needle-here.txt >/dev/null
    zt needle-here.txt >/dev/null
    local out; out=$(zt find needle)
    assert_contains "$out" 'needle-here.txt' 'find prints the path column'
}

function interactive_menu_shows_original_path {
    mkfile menu-item.txt >/dev/null
    zt menu-item.txt >/dev/null
    local out; out=$(print -n 'q' | zt -r)
    assert_contains "$out" "$CASE_DIR/work/menu-item.txt" 'menu shows the original path'
}

function list_survives_narrow_terminal {
    mkfile narrow.txt >/dev/null
    zt narrow.txt >/dev/null
    local out; out=$(ZTRASH_COLS=20 zt -l)
    assert_contains "$out" 'narrow.txt' 'path still shown at 20 columns'
}

# `$scalar[a,b]` is a character *range* in zsh, not a start plus a count, so
# format_date used to slice "2026-09-29T14:35:00" as [12,5] and print nothing.
# The Binned column came out blank for anything from this year or earlier.
function list_shows_human_dates {
    local now; now=$(date +%Y-%m-%dT%H:%M:%S)
    local year; year=$(date +%Y)

    mkfile today.txt >/dev/null
    zt today.txt >/dev/null
    mkfile thisyear.txt >/dev/null
    zt thisyear.txt >/dev/null
    mkfile older.txt >/dev/null
    zt older.txt >/dev/null

    age_item today "$now"
    age_item thisyear "${year}-03-14T08:05:00"
    age_item older 2019-11-02T07:00:00

    local out; out=$(zt -l)
    assert_contains "$out" "${now[12,16]}" 'today shows just the time'
    assert_contains "$out" '03-14 08:05'   'same year shows month, day and time'
    assert_contains "$out" '2019-11-02'   'older items show the full date'

    local find_out; find_out=$(zt find thisyear)
    assert_contains "$find_out" '03-14 08:05' 'find renders dates too'
}

it list-shows-paths-when-piped      list_shows_paths_when_piped
it find-shows-paths-when-piped      find_shows_paths_when_piped
it interactive-menu-shows-original-path interactive_menu_shows_original_path
it list-survives-narrow-terminal   list_survives_narrow_terminal
it list-shows-human-dates          list_shows_human_dates

# ===========================================================================
# Restoring onto an existing directory used to nest it and eat the trashinfo
# ===========================================================================

function restore_onto_existing_dir_replaces_not_nests {
    mkdir -p "$CASE_DIR/work/adir"
    print -r -- old > "$CASE_DIR/work/adir/old.txt"
    zt adir >/dev/null
    # something else recreates the original path in the meantime
    mkdir -p "$CASE_DIR/work/adir"
    print -r -- new > "$CASE_DIR/work/adir/new.txt"
    print -n 'y' | zt -u >/dev/null

    assert_file "$CASE_DIR/work/adir/old.txt" 'restored payload landed in place'
    assert_eq 0 "$(nitems)" 'trash entry consumed exactly once'
    local nested
    nested=("$CASE_DIR"/work/adir/*(N:n))
    nested=(${~nested})
    local found_nesting=0 f
    for f in $nested; do
        [[ -d $f ]] && found_nesting=1
    done
    assert_eq 0 $found_nesting 'nothing nested inside the target directory'
}

function restore_onto_existing_dir_declined_preserves_both {
    mkdir -p "$CASE_DIR/work/adir"
    print -r -- old > "$CASE_DIR/work/adir/old.txt"
    zt adir >/dev/null
    mkdir -p "$CASE_DIR/work/adir"
    print -r -- new > "$CASE_DIR/work/adir/new.txt"
    print -n 'n' | zt -u >/dev/null
    assert_file "$CASE_DIR/work/adir/new.txt" 'pre-existing file untouched'
    assert_eq 1 "$(nitems)" 'declined restore keeps the item binned'
}

function restore_onto_existing_file_declined_preserves {
    mkfile clash.txt 'mine' >/dev/null
    zt clash.txt >/dev/null
    mkfile clash.txt 'theirs' >/dev/null
    print -n 'n' | zt -u >/dev/null
    assert_eq 'theirs' "$(<$CASE_DIR/work/clash.txt)" 'existing file not clobbered'
}

it restore-onto-existing-dir-replaces-not-nests restore_onto_existing_dir_replaces_not_nests
it restore-onto-existing-dir-declined-preserves-both restore_onto_existing_dir_declined_preserves_both
it restore-onto-existing-file-declined-preserves restore_onto_existing_file_declined_preserves

# ===========================================================================
# A literal | in a filename used to corrupt the internal record format
# ===========================================================================

function pipe_in_filename_restores {
    mkfile 'we|ird.txt' >/dev/null
    zt 'we|ird.txt' >/dev/null
    print -n '1' | zt -r >/dev/null
    assert_file "$CASE_DIR/work/we|ird.txt" 'pipe filename restored'
    assert_eq 0 "$(nitems)" 'trash metadata cleaned up'
}

function pipe_in_filename_lists_whole_path {
    mkfile 'a|b|c.txt' >/dev/null
    zt 'a|b|c.txt' >/dev/null
    local out; out=$(zt -l)
    assert_contains "$out" 'a|b|c.txt' 'all pipe segments shown'
}

function pipe_in_filename_finds {
    mkfile 'x|y.txt' >/dev/null
    zt 'x|y.txt' >/dev/null
    local out; out=$(zt find 'x|y')
    assert_contains "$out" 'x|y.txt' 'pattern containing a pipe matches'
}

it pipe-in-filename-restores        pipe_in_filename_restores
it pipe-in-filename-lists-whole-path pipe_in_filename_lists_whole_path
it pipe-in-filename-finds           pipe_in_filename_finds

# ===========================================================================
# Exit codes used to be inverted: success returned 1, failure returned 0
# ===========================================================================

function exit_zero_on_success {
    mkfile ok.txt >/dev/null
    zt ok.txt >/dev/null
    assert_eq 0 $? 'successful trash exits 0'
}

function exit_zero_on_success_verbose {
    mkfile ok2.txt >/dev/null
    zt -v ok2.txt >/dev/null
    assert_eq 0 $? 'successful verbose trash exits 0'
}

function exit_nonzero_on_missing_file {
    zt definitely-not-here >/dev/null 2>&1
    assert_eq 1 $? 'missing file exits 1'
}

function exit_nonzero_when_one_fails {
    mkfile good.txt >/dev/null
    zt good.txt missing.txt >/dev/null 2>&1
    assert_eq 1 $? 'partial failure exits 1'
    assert_contains "$(zt -l)" 'good.txt' 'the good file is still binned'
}

function exit_2_on_usage_error {
    zt --definitely-not-a-flag >/dev/null 2>&1
    assert_eq 2 $? 'unknown option exits 2'
}

function exit_2_on_bad_purge_arg {
    zt -p notanumber >/dev/null 2>&1
    assert_eq 2 $? 'bad --purge argument exits 2'
}

it exit-zero-on-success            exit_zero_on_success
it exit-zero-on-success-verbose    exit_zero_on_success_verbose
it exit-nonzero-on-missing-file    exit_nonzero_on_missing_file
it exit-nonzero-when-one-fails     exit_nonzero_when_one_fails
it exit-2-on-usage-error           exit_2_on_usage_error
it exit-2-on-bad-purge-arg         exit_2_on_bad_purge_arg

# ===========================================================================
# Trashing something already inside the bin used to nest trash in trash
# ===========================================================================

function refuse_to_trash_from_inside_the_bin {
    mkfile nested.txt >/dev/null
    zt nested.txt >/dev/null
    local base; base=$(info_base)
    local out; out=$(zt "$FILES_DIR/$base" 2>&1)
    local -i rc=$?
    assert_eq 1 $rc 'refuses with a failure code'
    assert_contains "$out" 'inside' 'explains why'
    assert_file "$FILES_DIR/$base" 'payload left untouched'
    assert_eq 1 "$(nitems)" 'no second trashinfo created'
}

it refuse-to-trash-from-inside-the-bin refuse_to_trash_from_inside_the_bin

# ===========================================================================
# A relative Path= (the spec's topdir form) used to be treated as absolute
# ===========================================================================

function relative_path_resolves_against_topdir {
    local -i uid=${EUID:-$(id -u)}
    local top=$CASE_DIR/mnt
    local bin=$top/.Trash-$uid
    mkdir -p "$bin/files" "$bin/info"
    print -r -- payload > "$bin/files/rel.txt"
    {
        print -r -- "[Trash Info]"
        print -r -- "Path=sub/dir/rel.txt"
        print -r -- "DeletionDate=2020-01-01T00:00:00"
    } > "$bin/info/rel.txt.trashinfo"
    ZTRASH_TRASH_DIR=$bin zt -u >/dev/null
    assert_file "$top/sub/dir/rel.txt" 'relative path anchored to the topdir'
    assert_no_dir "$CASE_DIR/sub" 'nothing created relative to $PWD'
}

function home_bin_entries_store_absolute_paths {
    mkfile abs.txt >/dev/null
    zt abs.txt >/dev/null
    assert_eq "$CASE_DIR/work/abs.txt" "$(info_path)" 'home bin stores an absolute Path='
}

it relative-path-resolves-against-topdir relative_path_resolves_against_topdir
it absolute-path-kept-absolute       home_bin_entries_store_absolute_paths

# ===========================================================================
# Performance: the whole point of the rewrite
# ===========================================================================

function perf_list_is_not_forked_per_item {
    local i
    local -a names
    names=()
    for (( i = 1; i <= 40; i++ )); do
        print -r -- data > "$CASE_DIR/work/perf$i.txt"
        names+=(perf$i.txt)
    done
    zt $names >/dev/null
    local -F start=$EPOCHREALTIME
    local out; out=$(zt -l)
    local -F elapsed=$(( EPOCHREALTIME - start ))
    # The old implementation forked ~4x per item; 40 items took over 6s.
    if (( elapsed < 2 )); then ok
    else bad "listing 40 items took ${elapsed}s" 'expected under 2s'; fi
    assert_contains "$out" 'perf1.txt' 'all items listed'
}

function perf_purge_does_not_fork_date {
    local i
    for (( i = 1; i <= 40; i++ )); do
        print -r -- data > "$CASE_DIR/work/pp$i.txt"
        zt "pp$i.txt" >/dev/null
    done
    local -F start=$EPOCHREALTIME
    zt -p 0 -y >/dev/null
    local -F elapsed=$(( EPOCHREALTIME - start ))
    if (( elapsed < 3 )); then ok
    else bad "purging 40 items took ${elapsed}s" 'expected under 3s'; fi
    assert_eq 0 "$(nitems)" 'all purged'
}

it perf-list-is-not-forked-per-item  perf_list_is_not_forked_per_item
it perf-purge-does-not-fork-date    perf_purge_does_not_fork_date

# ===========================================================================
# fzf picker
# ===========================================================================

# A stub fzf so the picker's wire format can be asserted without depending on
# fzf being installed. $1 is the 1-based line of fzf's stdin to select.
stub_fzf() {
    local n=$1
    mkdir -p "$CASE_DIR/bin"
    print -rl -- '#!/bin/sh' "sed -n ${n}p" > "$CASE_DIR/bin/fzf"
    chmod +x "$CASE_DIR/bin/fzf"
    # typeset -g: a plain assignment inside a function would only be visible
    # for the rest of the function. setup_case restores PATH for every case.
    typeset -g PATH=$CASE_DIR/bin:$PATH
}

function fzf_picker_lines_up_with_list_order {
    mkfile one.txt >/dev/null
    mkfile two.txt >/dev/null
    mkfile three.txt >/dev/null
    zt one.txt two.txt three.txt >/dev/null
    # Make the listing order explicit: three.txt is the newest.
    age_item one 2001-01-01T00:00:00
    age_item two 2002-02-02T00:00:00
    stub_fzf 1
    # ztrash reads fzf's stdin as one line per item. `print -r a b` would join
    # the array with spaces and hand fzf a single unusable line.
    local out
    out=$(print d | zt -d --fzf 2>&1)
    assert_contains "$out" 'three.txt' 'first listed item is selectable'
    assert_not_contains "$out" 'one.txt' 'only the selected item is acted on'
    assert_eq 2 "$(nitems)" 'one item left'
}

function fzf_picker_handles_paths_with_spaces {
    mkfile 'a b.txt' >/dev/null
    mkfile plain.txt >/dev/null
    zt 'a b.txt' plain.txt >/dev/null
    # plain.txt is binned first, so the space-named path is listed first.
    age_item plain 2001-01-01T00:00:00
    stub_fzf 1
    local out
    out=$(print d | zt -d --fzf 2>&1)
    assert_contains "$out" "a b.txt" 'a path containing a space is selectable'
    assert_eq 1 "$(nitems)" 'the space-named item is gone'
}

function fzf_picker_without_selection_changes_nothing {
    mkfile keep.txt >/dev/null
    zt keep.txt >/dev/null
    stub_fzf 9
    print d | zt -d --fzf >/dev/null 2>&1
    assert_eq 1 "$(nitems)" 'nothing deleted when fzf selects nothing'
}

it fzf-picker-lines-up-with-list-order  fzf_picker_lines_up_with_list_order
it fzf-picker-handles-spaces-in-paths    fzf_picker_handles_paths_with_spaces
it fzf-picker-empty-selection-is-a-no-op fzf_picker_without_selection_changes_nothing

# ===========================================================================
# Core behaviour that must keep working
# ===========================================================================

function trashes_and_restores_roundtrip {
    mkfile rt.txt hello >/dev/null
    zt rt.txt >/dev/null
    assert_no_file "$CASE_DIR/work/rt.txt" 'removed from the work dir'
    assert_eq 1 "$(nitems)" 'one trashinfo written'
    zt -u >/dev/null
    assert_file "$CASE_DIR/work/rt.txt" 'restored by undo'
    assert_eq hello "$(<$CASE_DIR/work/rt.txt)" 'contents intact'
    assert_eq 0 "$(nitems)" 'trashinfo cleaned up'
}

function writes_spec_conformant_trashinfo {
    mkfile spec.txt >/dev/null
    zt spec.txt >/dev/null
    local f; f=("$INFO_DIR"/*.trashinfo(N))
    local body; body=$(<$f[1])
    assert_contains "$body" '[Trash Info]' 'has the [Trash Info] header'
    if [[ $body == *'DeletionDate='????-??-??T??:??:?? ]]; then ok
    else bad 'DeletionDate is ISO-8601' "$body"; fi
}

function empty_asks_first {
    mkfile e1.txt >/dev/null
    zt e1.txt >/dev/null
    local out; out=$(print -n 'n' | zt -e)
    assert_contains "$out" 'Really empty' 'prompts'
    assert_contains "$out" 'Aborted' 'declining says so'
    assert_eq 1 "$(nitems)" 'nothing removed'
}

function empty_with_yes_needs_no_prompt {
    mkfile e2.txt >/dev/null
    zt e2.txt >/dev/null
    local out; out=$(zt -e -y)
    assert_contains "$out" 'emptied' 'emptied with -y'
    assert_eq 0 "$(nitems)" 'info dir cleared'
}

function empty_refuses_without_a_terminal {
    mkfile e3.txt >/dev/null
    zt e3.txt >/dev/null
    local out; out=$(zt -e </dev/null 2>&1)
    assert_not_contains "$out" 'Trash emptied' 'did not empty'
    assert_eq 1 "$(nitems)" 'still binned'
}

function size_reports_count {
    mkfile s1.txt >/dev/null
    mkfile s2.txt >/dev/null
    zt s1.txt s2.txt >/dev/null
    local out; out=$(zt -s)
    assert_contains "$out" '2 item' 'counts items'
    assert_contains "$out" 'Trash size' 'labels the size'
}

function restore_by_pattern {
    mkfile one.bak >/dev/null
    mkfile two.bak >/dev/null
    mkfile three.txt >/dev/null
    zt one.bak two.bak three.txt >/dev/null
    local out; out=$(zt restore '*.bak')
    assert_contains "$out" 'Restored 2' 'restored both matches'
    assert_file "$CASE_DIR/work/one.bak" 'one.bak back'
    assert_file "$CASE_DIR/work/two.bak" 'two.bak back'
    assert_eq 1 "$(nitems)" 'three.txt still binned'
}

function flags_after_a_subcommand_are_not_part_of_the_pattern {
    mkfile 'has space.log' >/dev/null
    zt 'has space.log' >/dev/null
    # A subcommand owns the rest of the line, but the modifier flags have to be
    # recognised wherever they appear: `restore '*.log' -y` is what people type.
    local out; out=$(zt restore '*.log' -y 2>&1)
    assert_not_contains "$out" 'No items matched' 'the pattern is not polluted by -y'
    assert_file "$CASE_DIR/work/has space.log" 'item restored'
}

function subcommand_without_a_pattern_is_a_usage_error {
    local -i rc=0
    zt restore >/dev/null 2>&1 || rc=$?
    assert_eq 2 "$rc" 'bare restore exits 2'
    rc=0
    zt find >/dev/null 2>&1 || rc=$?
    assert_eq 2 "$rc" 'bare find exits 2'
}

function delete_by_number {
    mkfile del1.txt >/dev/null
    mkfile del2.txt >/dev/null
    zt del1.txt del2.txt >/dev/null
    # Make the listing order explicit rather than depending on the second in
    # which the two files happened to be binned.
    age_item del1 2001-01-01T00:00:00
    print -n '1' | zt -d >/dev/null
    assert_eq 1 "$(nitems)" 'one item removed'
    local out; out=$(zt -l)
    assert_contains "$out" 'del1.txt' 'surviving item still listed'
    assert_not_contains "$out" 'del2.txt' 'deleted item gone from the list'
}

function purge_by_age {
    mkfile old.txt >/dev/null
    mkfile new.txt >/dev/null
    zt old.txt new.txt >/dev/null
    local f
    for f in "$INFO_DIR"/*.trashinfo(N); do
        if [[ $(<$f) == *old.txt* ]]; then
            {
                print -r -- "[Trash Info]"
                print -r -- "Path=%2Ftmp%2Fold.txt"
                print -r -- "DeletionDate=2001-01-01T00:00:00"
            } > $f
        fi
    done
    local out; out=$(zt -p 30 -y)
    assert_contains "$out" 'Purged' 'reports what it purged'
    assert_eq 1 "$(nitems)" 'only the aged entry went'
}

function purge_dry_run_changes_nothing {
    mkfile dr.txt >/dev/null
    zt dr.txt >/dev/null
    local out; out=$(zt -p 0 -n)
    assert_contains "$out" 'Would purge' 'dry run says so'
    assert_eq 1 "$(nitems)" 'nothing removed'
}

function json_output_is_parseable {
    mkfile j1.txt >/dev/null
    zt j1.txt >/dev/null
    local out; out=$(zt -l --json)
    if command -v python3 >/dev/null 2>&1; then
        if print -r -- "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["count"] == 1, d["count"]
assert d["items"][0]["name"] == "j1.txt", d["items"][0]
assert d["items"][0]["present"] is True
' 2>/dev/null; then ok
        else bad 'json parses with the expected shape' "$out"; fi
    else
        assert_contains "$out" '"count"' 'emits a count field'
    fi
}

function json_escapes_special_characters {
    mkfile 'quote"name.txt' >/dev/null
    zt 'quote"name.txt' >/dev/null
    local out; out=$(zt -l --json)
    if command -v python3 >/dev/null 2>&1; then
        if print -r -- "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["items"][0]["name"] == "quote\"name.txt", d["items"][0]["name"]
' 2>/dev/null; then ok
        else bad 'quotes are escaped for json' "$out"; fi
    fi
}

function gc_removes_orphans {
    mkfile orphan.txt >/dev/null
    zt orphan.txt >/dev/null
    rm -f "$FILES_DIR/$(info_base)"                   # trashinfo, no payload
    mkdir -p "$FILES_DIR/ghost"; : > "$FILES_DIR/ghost/x"   # payload, no trashinfo
    local out; out=$(zt --gc)
    assert_eq 0 "$(nitems)" 'stale trashinfo removed'
    assert_no_file "$FILES_DIR/ghost" 'untracked payload removed'
    assert_contains "$out" 'Collected 2' 'reports the count'
}

function list_flags_missing_payloads {
    mkfile gone.txt >/dev/null
    zt gone.txt >/dev/null
    rm -f "$FILES_DIR/$(info_base)"
    local out; out=$(zt -l)
    assert_contains "$out" 'missing' 'missing payload is flagged'
    assert_contains "$out" 'gone.txt' 'and the entry is still listed'
}

function help_and_version {
    assert_contains "$(zt --help)" 'Usage' 'help works'
    assert_contains "$(zt --help)" '--dry-run' 'help documents new flags'
    assert_contains "$(zt --version)" 'ztrash version' 'version works'
}

function completions_match_committed_files {
    local shell
    for shell in bash zsh fish; do
        local -a want
        case $shell in
            bash) want=($TEST_ROOT/completions/ztrash.bash) ;;
            zsh)  want=($TEST_ROOT/completions/ztrash.zsh) ;;
            fish) want=($TEST_ROOT/completions/ztrash.fish) ;;
        esac
        if zt --print-completion $shell | diff -q - $want[1] >/dev/null 2>&1; then ok
        else bad "completions/${want[1]:t} matches --print-completion $shell" "the committed file is stale"; fi
    done
}

function verbose_flag_works_in_any_position {
    mkfile vp.txt >/dev/null
    local out; out=$(zt vp.txt -v 2>&1)
    assert_contains "$out" 'binned' 'trailing -v honoured'
    assert_no_file "$CASE_DIR/work/vp.txt" 'and the file was moved'
}

function double_dash_ends_option_parsing {
    mkfile --dashy >/dev/null
    zt -- --dashy >/dev/null
    assert_no_file "$CASE_DIR/work/--dashy" 'leading-dash filename binned'
    zt -u >/dev/null
    assert_file "$CASE_DIR/work/--dashy" 'and restored'
}

function watch_refuses_without_a_tty {
    local out; out=$(zt -w 2>&1)
    local -i rc=$?
    assert_eq 2 $rc 'watch exits 2 without a tty'
    assert_not_contains "$out" $'\e[2J' 'no clear-screen escapes leaked'
}

function no_color_env_is_respected {
    mkfile nc.txt >/dev/null
    zt nc.txt >/dev/null
    assert_not_contains "$(zt -l)" $'\e[' 'no escapes when ZTRASH_NO_COLOR is set'
}

function dry_run_trash_changes_nothing {
    mkfile dry.txt >/dev/null
    local out; out=$(zt -n dry.txt)
    assert_contains "$out" 'would bin' 'dry run announces the action'
    assert_file "$CASE_DIR/work/dry.txt" 'file left alone'
    assert_eq 0 "$(nitems)" 'nothing binned'
}

function multiple_targets_all_fail_reported {
    zt a-missing b-missing >/dev/null 2>&1
    assert_eq 1 $? 'all-missing still exits 1'
    assert_eq 0 "$(nitems)" 'and wrote nothing'
}

function empty_trash_reports_when_already_empty {
    local out; out=$(zt -e -y)
    assert_contains "$out" 'already empty' 'says so plainly'
}

it trashes-and-restores-roundtrip  trashes_and_restores_roundtrip
it writes-spec-conformant-info    writes_spec_conformant_trashinfo
it empty-asks-first               empty_asks_first
it empty-with-yes                 empty_with_yes_needs_no_prompt
it empty-refuses-without-a-tty    empty_refuses_without_a_terminal
it empty-reports-when-already-empty empty_trash_reports_when_already_empty
it size-reports-count             size_reports_count
it restore-by-pattern             restore_by_pattern
it flags-after-subcommand-are-modifiers flags_after_a_subcommand_are_not_part_of_the_pattern
it subcommand-requires-a-pattern  subcommand_without_a_pattern_is_a_usage_error
it delete-by-number               delete_by_number
it purge-by-age                   purge_by_age
function purge_uses_configured_age_by_default {
    # An item binned "now" is younger than the default 30 days, so a bare
    # --purge must leave it alone.
    mkfile keepme.txt >/dev/null
    zt keepme.txt >/dev/null
    local out; out=$(zt -p -y 2>&1)
    assert_contains "$out" 'Purged 0' 'nothing old enough to purge'
    assert_eq 1 "$(nitems)" 'young item survives the default purge'
}

function purge_days_env_is_honoured {
    mkfile aged.txt >/dev/null
    zt aged.txt >/dev/null
    # Force an old DeletionDate so the item is unambiguously past the cutoff.
    local -a f
    f=("$INFO_DIR"/*.trashinfo(N))
    local -a lines
    lines=("${(@f)$(<$f[1])}")
    local l
    for l in $lines; do
        [[ $l == DeletionDate=* ]] && lines[$lines[(i)$l]]=${l/DeletionDate=/DeletionDate=2001-01-01T00:00:00}
    done
    print -l -- $lines > $f[1]
    ZTRASH_PURGE_DAYS=7 zt -p -y >/dev/null
    assert_eq 0 "$(nitems)" 'ZTRASH_PURGE_DAYS=7 purged the old item'
}

function size_reports_real_byte_totals {
    # Sizes come from a batched du pass keyed by path. That lookup used to store
    # the whole du line as the key, so every size came back 0B.
    # Only regular files are used here: the size du attributes to a directory
    # inode is filesystem dependent, which would make the total meaningless.
    print -rn -- '12345' > "$CASE_DIR/work/five.txt"
    print -rn -- '1234567' > "$CASE_DIR/work/seven.txt"
    zt five.txt seven.txt >/dev/null

    local out; out=$(zt -s)
    assert_contains "$out" '12B' 'size reflects the real byte total'

    local total
    total=$(zt -l --json | sed -n 's/.*"total_bytes": \([0-9]*\).*/\1/p')
    assert_eq 12 "$total" 'json total_bytes is the real byte total'

    local -a per
    per=("${(@f)$(zt -l --json | sed -n 's/.*"size_bytes": \([0-9]*\).*/\1/p')}")
    assert_eq 2 "${#per}" 'both items reported'
    assert_ne 0 "${per[1]}" 'first per-item size_bytes is not zero'
    assert_ne 0 "${per[2]}" 'second per-item size_bytes is not zero'
}

it purge-dry-run-changes-nothing  purge_dry_run_changes_nothing
it size-reports-real-byte-totals size_reports_real_byte_totals
it purge-uses-configured-age      purge_uses_configured_age_by_default
it purge-days-env-is-honoured     purge_days_env_is_honoured
it json-output-is-parseable       json_output_is_parseable
it json-escapes-special-chars     json_escapes_special_characters
it gc-removes-orphans             gc_removes_orphans
it list-flags-missing-payloads    list_flags_missing_payloads
it help-and-version               help_and_version
it completions-match-committed    completions_match_committed_files
it verbose-in-any-position        verbose_flag_works_in_any_position
it double-dash-ends-options       double_dash_ends_option_parsing
it watch-refuses-without-a-tty    watch_refuses_without_a_tty
it no-color-env                   no_color_env_is_respected
it dry-run-trash-changes-nothing  dry_run_trash_changes_nothing
it multiple-targets-fail-reported multiple_targets_all_fail_reported
