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

warn "window/document referenced outside onMount could break SSR (verify it's inside onMount/handlers)" \
  '^\s*(window|document)\.' \
  --include='*.tsx'

echo
if [ "$FAIL" -eq 1 ]; then
  echo "── audit FAILED: fix the ✗ items above (see SKILL.md and references/solid-reactivity.md)"
  exit 1
fi
echo "── audit passed (review any ⚠ warnings above)"
