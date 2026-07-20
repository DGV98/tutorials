#!/usr/bin/env bash
# check.sh — run the tests for a module (or everything).
#
#   ./check.sh 03            # run all exercises in module 03
#   ./check.sh 03 2          # run only exercise 02 of module 03
#   ./check.sh all           # run every module
#   ./check.sh solutions 03  # run the reference solutions for module 03
set -u
cd "$(dirname "$0")"

GREEN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
pass=0; fail=0; failed_files=()

run_file() {
    local f="$1"
    local dir; dir="$(dirname "$f")"
    local base; base="$(basename "$f")"
    local out
    if grep -q '^test\|^    test\|test "' "$f"; then
        out=$(cd "$dir" && zig test "$base" 2>&1)
    elif grep -q 'pub fn main' "$f"; then
        # main-based exercise: check that it compiles; running it is on you
        out=$(cd "$dir" && zig build-exe "$base" -fno-emit-bin 2>&1)
    else
        return 0
    fi
    if [ $? -eq 0 ]; then
        printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$f"
        pass=$((pass + 1))
    else
        printf "  %s✗%s %s\n" "$RED" "$RESET" "$f"
        printf "%s%s%s\n" "$DIM" "$(echo "$out" | head -15 | sed 's/^/      /')" "$RESET"
        fail=$((fail + 1)); failed_files+=("$f")
    fi
}

run_module() {
    local dir="$1" only="${2:-}"
    [ -d "$dir" ] || { echo "no such module: $dir"; exit 1; }
    echo "── $dir"
    # exercises may live in the module root or (module 12) one dir deeper
    while IFS= read -r f; do
        if [ -n "$only" ]; then
            case "$(basename "$f")" in
                "$(printf '%02d' "$only")"_*) ;;
                *) continue ;;
            esac
        fi
        run_file "$f"
    done < <(find "$dir" -maxdepth 2 -name '*.zig' | sort)
}

case "${1:-}" in
    "" | -h | --help)
        sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    all)
        for d in [0-9][0-9]_*/; do run_module "${d%/}"; done
        ;;
    solutions)
        [ -n "${2:-}" ] || { echo "usage: ./check.sh solutions <module-number>"; exit 1; }
        run_module "$(find solutions -maxdepth 1 -type d -name "${2}_*" | head -1)"
        ;;
    *)
        mod="$(find . -maxdepth 1 -type d -name "${1}_*" | head -1)"
        [ -n "$mod" ] || { echo "no module matching '$1'"; exit 1; }
        run_module "${mod#./}" "${2:-}"
        ;;
esac

echo
echo "passed: $pass  failed: $fail"
[ $fail -eq 0 ]
