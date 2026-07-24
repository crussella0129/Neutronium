#!/usr/bin/env bash
# Neutronium self-audit — mechanical scan for patterns that are always (or
# almost always) defects in an Astro + SolidJS + TypeScript codebase.
#
# Usage: bash scripts/audit.sh [src-dir]   (defaults to ./src)
#
# Hard failures (exit 1): patterns with no legitimate use in this stack.
# Warnings (exit 0): heuristics that deserve a human/agent look.

set -u
SRC="${1:-src}"
FAIL=0

if [ ! -d "$SRC" ]; then
  echo "audit: source directory '$SRC' not found" >&2
  exit 2
fi

hard() {
  local desc="$1" pattern="$2"; shift 2
  local matches
  matches=$(grep -rnE "$pattern" "$SRC" "$@" 2>/dev/null)
  if [ -n "$matches" ]; then
    printf '✗ FAIL  %s\n' "$desc"
    printf '%s\n' "$matches" | sed 's/^/        /'
    FAIL=1
  else
    printf '✓ ok    %s\n' "$desc"
  fi
}

warn() {
  local desc="$1" pattern="$2"; shift 2
  local matches
  matches=$(grep -rnE "$pattern" "$SRC" "$@" 2>/dev/null)
  if [ -n "$matches" ]; then
    printf '⚠ WARN  %s\n' "$desc"
    printf '%s\n' "$matches" | sed 's/^/        /'
  fi
}

echo "── Neutronium audit: $SRC"
echo

# ── Hard failures ────────────────────────────────────────────────────────────

hard "No imports from react / react-dom" \
  "from ['\"]react(-dom)?(/|['\"])" \
  --include='*.tsx' --include='*.ts' --include='*.astro'

hard "No React hooks (useState/useEffect/useRef/useMemo/useCallback/useReducer/useLayoutEffect)" \
  '\b(useState|useEffect|useLayoutEffect|useRef|useMemo|useCallback|useReducer)\s*\(' \
  --include='*.tsx' --include='*.ts'

hard "No className= (Solid and Astro use class=)" \
  '\bclassName=' \
  --include='*.tsx' --include='*.astro'

hard "No htmlFor= (use native for=)" \
  '\bhtmlFor=' \
  --include='*.tsx' --include='*.astro'

hard "No destructuring of props in component parameters" \
  '(function\s+[A-Z][A-Za-z0-9]*\s*\(\s*\{|(const|let)\s+[A-Z][A-Za-z0-9]*\s*(:[^=]*)?=\s*\(\s*\{)' \
  --include='*.tsx'

hard "No destructuring from the props object in component bodies" \
  '(const|let|var)\s*\{[^}]*\}\s*=\s*(raw)?[pP]rops\b' \
  --include='*.tsx'

hard "No dangerouslySetInnerHTML (Solid uses the innerHTML prop)" \
  'dangerouslySetInnerHTML' \
  --include='*.tsx'

# ── Warnings (heuristics — verify by reading the match) ──────────────────────

warn "key= prop found: Solid has no key; <For> keys by reference (verify this isn't a React habit)" \
  '\skey=\{' \
  --include='*.tsx'

warn ".map( in a .tsx file: if this renders JSX, it must be <For>/<Index> (data transforms are fine)" \
  '\.map\(' \
  --include='*.tsx'

warn "Possible camelCase key in a style object: Solid style objects use dash-case ('background-color')" \
  'style=\{\{[^}]*[a-z][A-Z]' \
  --include='*.tsx'

warn "onChange on an input/select: Solid's onChange is the native commit event; live typing needs onInput" \
  '<(input|select|textarea)[^>]*onChange=' \
  --include='*.tsx'

# ── Browser globals: severity by scope depth ─────────────────────────────────
#
# A flat grep for `document.` fires on every theme toggle and storage-backed
# island, because it cannot tell setup-time access from a click handler. Scope
# depth can, and it maps onto the actual failure:
#
#   depth 0  module top level      runs on import — breaks SSR unconditionally
#   depth 1  component setup body  runs during SSR render — usually a defect
#   depth 2+ onMount/handler/effect  client-only — correct, stay silent
#
# Depth is tracked by counting braces. Strings and comments are deliberately
# NOT stripped: JSX expression braces balance within a line and cancel out,
# whereas stripping quotes breaks on apostrophes in JSX prose. If a file's
# braces do not close at EOF the count is untrustworthy, so that file falls
# back to reporting every hit as a warning.
dom_scope_check() {
  local out skew
  out=$(
    find "$SRC" -type f -name '*.tsx' -print0 2>/dev/null |
      while IFS= read -r -d '' f; do
        awk -v file="$f" '
          BEGIN { depth = 0; n = 0 }
          {
            if ($0 ~ /(^|[^A-Za-z0-9_$.])(window|document|localStorage|sessionStorage|navigator)\./) {
              n++
              hit_depth[n] = depth
              hit_line[n]  = FNR
              t = $0; sub(/^[ \t]+/, "", t)
              hit_text[n]  = t
            }
            opened = gsub(/\{/, "{")
            closed = gsub(/\}/, "}")
            depth += opened - closed
          }
          END {
            trustworthy = (depth == 0)
            if (!trustworthy && n > 0) printf "SKEW\t%s\t0\t\n", file
            for (i = 1; i <= n; i++) {
              if (!trustworthy)            sev = "WARN"
              else if (hit_depth[i] <= 0)  sev = "FAIL"
              else if (hit_depth[i] == 1)  sev = "WARN"
              else                         continue
              printf "%s\t%s\t%d\t%s\n", sev, file, hit_line[i], hit_text[i]
            }
          }
        ' "$f"
      done
  )

  local fails warns
  fails=$(printf '%s\n' "$out" | grep '^FAIL' | cut -f2,3,4 | sed 's/\t/:/;s/\t/:  /')
  warns=$(printf '%s\n' "$out" | grep '^WARN' | cut -f2,3,4 | sed 's/\t/:/;s/\t/:  /')
  skew=$(printf '%s\n' "$out" | grep '^SKEW' | cut -f2)

  if [ -n "$fails" ]; then
    printf '✗ FAIL  Browser global at module top level (runs on import — breaks SSR)\n'
    printf '%s\n' "$fails" | sed 's/^/        /'
    FAIL=1
  else
    printf '✓ ok    No browser globals at module top level\n'
  fi

  if [ -n "$warns" ]; then
    printf '⚠ WARN  Browser global in setup body (runs during SSR — move into onMount)\n'
    printf '%s\n' "$warns" | sed 's/^/        /'
  fi

  if [ -n "$skew" ]; then
    printf 'ℹ INFO  Brace depth unreliable (unbalanced at EOF); all hits shown as warnings:\n'
    printf '%s\n' "$skew" | sed 's/^/        /'
  fi
}

dom_scope_check

echo
if [ "$FAIL" -eq 1 ]; then
  echo "── audit FAILED: fix the ✗ items above (see SKILL.md and references/solid-reactivity.md)"
  exit 1
fi
echo "── audit passed (review any ⚠ warnings above)"
