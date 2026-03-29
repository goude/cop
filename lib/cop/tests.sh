# tests.sh — cop_run_tests

# --- Tests -------------------------------------------------------------------
cop_run_tests() {
  (
    set -euo pipefail

    COP_BIN="$0"

    fail() {
      printf 'TEST FAIL: %s\n' "$*" >&2
      exit 1
    }

    assert_eq() {
      local msg="$1" got="$2" expect="$3"
      if [[ "$got" != "$expect" ]]; then
        printf 'ASSERT EQ FAIL: %s\n' "$msg" >&2
        printf '  got:    [%s]\n' "$got" >&2
        printf '  expect: [%s]\n' "$expect" >&2
        exit 1
      fi
    }

    assert_ne() {
      local msg="$1" got="$2" expect="$3"
      if [[ "$got" == "$expect" ]]; then
        printf 'ASSERT NE FAIL: %s\n' "$msg" >&2
        printf '  got: [%s]\n' "$got" >&2
        printf '  expect: [%s]\n' "$expect" >&2
        exit 1
      fi
    }

    assert_fail() {
      local msg="$1"
      shift
      if "$@"; then
        printf 'ASSERT FAIL FAIL: %s (command succeeded, but should fail)\n' "$msg" >&2
        exit 1
      fi
    }

    # Auto-confirm uploads during tests.
    export COP_ASSUME_Y="1"
    # Flag that we're in test mode (for logging tweaks).
    export COP_TESTING="1"

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    cd "$tmpdir"

    printf 'Running cop self tests in %s\n' "$tmpdir"

    printf 'FILE content %s\n' "$RANDOM" >FILE
    printf 'FILE2 content %s\n' "$RANDOM" >FILE2
    printf 'FILE3 content %s\n' "$RANDOM" >FILE3

    f1="$(cat FILE)"
    f2="$(cat FILE2)"
    f3="$(cat FILE3)"

    unset COP_SECRET || true

    # 1) local copy + paste
    "$COP_BIN" FILE
    out="$("$COP_BIN" -p)"
    assert_eq "cop -p after 'cop FILE'" "$out" "$f1"

    # 2) cop -p FILE writes clipboard back into FILE (no stdout expected)
    "$COP_BIN" -p FILE
    out="$(cat FILE)"
    assert_eq "cop -p FILE after 'cop FILE'" "$out" "$f1"

    # 3) network -n (unencrypted)
    "$COP_BIN" -n FILE2
    out="$("$COP_BIN" -pn)"
    assert_eq "cop -pn after '-n FILE2'" "$out" "$f2"

    out="$("$COP_BIN" -p)"
    assert_eq "cop -p still FILE after network copy" "$out" "$f1"

    # 4) encrypted failure without COP_SECRET
    assert_fail "cop -ne FILE3 must fail without COP_SECRET" \
      "$COP_BIN" -ne FILE3

    # 5) encrypted network ops with dummy key (no decrypt-from-remote in test)
    export COP_SECRET="dummy-test-secret"

    "$COP_BIN" -ne FILE3

    # Remote encrypted value: pn should not equal plaintext FILE3
    out="$("$COP_BIN" -pn)"
    assert_ne "cop -pn must not equal FILE3 when encrypted" "$out" "$f3"

    # Local remains FILE
    out="$("$COP_BIN" -p)"
    assert_eq "cop -p still FILE after encrypted ops" "$out" "$f1"

    # 6) stdin copy cases
    "$COP_BIN" <FILE2
    out="$("$COP_BIN" -p)"
    assert_eq "cop -p after stdin FILE2" "$out" "$f2"

    cat FILE3 | "$COP_BIN"
    out="$("$COP_BIN" -p)"
    assert_eq "cop -p after stdin FILE3" "$out" "$f3"

    # 7) concatenation of multiple files
    "$COP_BIN" FILE FILE2 FILE3
    expect_concat="$(cat FILE FILE2 FILE3)"
    out="$("$COP_BIN" -p)"
    assert_eq "cop -p after concatenation" "$out" "$expect_concat"

    # 8) append mode
    "$COP_BIN" FILE
    "$COP_BIN" -a FILE2
    expect_append="${f1}${f2}"
    out="$("$COP_BIN" -p)"
    assert_eq "cop -p after append" "$out" "$expect_append"

    # 9) --completions fish emits valid-looking fish script
    comp="$("$COP_BIN" --completions fish)"
    [[ "$comp" == *"complete -c cop"* ]] || fail "--completions fish output missing 'complete -c cop'"

    # 10) --notes creates NOTES.md with expected content
    EDITOR="true" "$COP_BIN" --notes
    [[ -f "NOTES.md" ]] || fail "--notes did not create NOTES.md"
    grep -q "NOTES.md convention" NOTES.md || fail "--notes NOTES.md missing convention link"
    # second invocation should not overwrite
    printf "extra\n" >>NOTES.md
    EDITOR="true" "$COP_BIN" --notes
    grep -q "extra" NOTES.md || fail "--notes overwrote existing NOTES.md"

    # 11) directory copy: single directory arg gets delimited with filenames
    mkdir -p subdir
    printf 'alpha content\n' >"$tmpdir/subdir/alpha.txt"
    printf 'beta content\n'  >"$tmpdir/subdir/beta.txt"

    "$COP_BIN" subdir
    out="$("$COP_BIN" -p)"
    [[ "$out" == *"=== "* ]]          || fail "directory copy missing delimiter"
    [[ "$out" == *"alpha.txt"* ]]     || fail "directory copy missing filename alpha.txt"
    [[ "$out" == *"beta.txt"* ]]      || fail "directory copy missing filename beta.txt"
    [[ "$out" == *"alpha content"* ]] || fail "directory copy missing alpha content"
    [[ "$out" == *"beta content"* ]]  || fail "directory copy missing beta content"

    # 12) explicit multi-file args: concatenated content, no delimiters
    "$COP_BIN" subdir/alpha.txt subdir/beta.txt
    out="$("$COP_BIN" -p)"
    expect_concat="$(cat subdir/alpha.txt subdir/beta.txt)"
    assert_eq "explicit files no delimiters" "$out" "$expect_concat"
    [[ "$out" != *"==="* ]] || fail "explicit file args should not produce delimiters"

    echo "All cop self tests passed."
  )
}
