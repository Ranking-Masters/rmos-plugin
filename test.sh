#!/bin/bash
# Zelftest voor de RMOS-plugin. Geen framework, geen fixtures: één bestand dat
# faalt als het gedrag verandert.
#
# Waarom dit bestaat: de hook heeft één tak (git-repo of niet) en die is
# dragend. Breekt de detectie, dan zwijgt hij overal — feature dood, niemand
# merkt het — of hij vuurt in elke klantcodebase en wordt uitgezet. Beide
# faalmodi zijn stil, dus horen ze hier hard te falen.
set -uo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/rmos/hooks/boot.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fouten=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fout() { printf '  \033[31m✗\033[0m %s\n' "$1"; fouten=$((fouten + 1)); }

echo "RMOS-plugin zelftest"

# 1. rolmap (geen git): moet spreken
mkdir -p "$TMP/rolmap"
uit="$(cd "$TMP/rolmap" && bash "$HOOK")"; code=$?
[ $code -eq 0 ] && ok "rolmap: exit 0" || fout "rolmap: exit $code, moet 0 zijn"
[ -n "$uit" ] && ok "rolmap: zegt iets" || fout "rolmap: zwijgt, en dat is de dode-feature-faalmodus"

# 2. de inhoud moet de agent naar de twee tools sturen, anders doet de hook niets nuttigs
case "$uit" in *rmos_changes*) ok "noemt rmos_changes" ;; *) fout "noemt rmos_changes niet" ;; esac
case "$uit" in *rmos_start*)   ok "noemt rmos_start" ;;   *) fout "noemt rmos_start niet" ;; esac
case "$uit" in *"ack: true"*)  ok "legt ack uit" ;;       *) fout "legt ack niet uit" ;; esac

# 3. codebase (git): moet zwijgen
mkdir -p "$TMP/code" && (cd "$TMP/code" && git init -q 2>/dev/null)
uit2="$(cd "$TMP/code" && bash "$HOOK")"; code2=$?
[ $code2 -eq 0 ] && ok "codebase: exit 0" || fout "codebase: exit $code2, moet 0 zijn"
[ -z "$uit2" ] && ok "codebase: zwijgt" || fout "codebase: praat, en dan zet iemand de plugin uit"

# 4. submap van een repo hoort ook stil te zijn — daar werk je nog steeds aan code
mkdir -p "$TMP/code/diep/er"
uit3="$(cd "$TMP/code/diep/er" && bash "$HOOK")"
[ -z "$uit3" ] && ok "submap van een repo: zwijgt" || fout "submap van een repo: praat"

# 5. faalt of ontbreekt git, dan mag de hook niet stuk: 'geen repo' is de
#    veilige aanname, want zwijgen zou de feature stil doden
mkdir -p "$TMP/bin"
printf '#!/bin/sh\nexit 127\n' > "$TMP/bin/git" && chmod +x "$TMP/bin/git"
uit4="$(cd "$TMP/rolmap" && PATH="$TMP/bin:$PATH" bash "$HOOK")"; code4=$?
[ $code4 -eq 0 ] && ok "git faalt: exit 0" || fout "git faalt: exit $code4, moet 0 zijn"
[ -n "$uit4" ] && ok "git faalt: spreekt (veilige aanname)" || fout "git faalt: zwijgt"

# 6. de statusbalk: een badge die liegt is erger dan geen badge
export CLAUDE_CONFIG_DIR="$TMP/cfg"; mkdir -p "$CLAUDE_CONFIG_DIR"
SL="$(cd "$(dirname "$0")" && pwd)/rmos/hooks/statusline.sh"
PT="$(cd "$(dirname "$0")" && pwd)/rmos/hooks/post-tool.sh"

uit="$(bash "$SL")"
case "$uit" in *RMOS*) ok "statusbalk: toont een badge zonder standbestand" ;; *) fout "statusbalk: geen badge" ;; esac
case "$uit" in *"RMOS ]"*|*"RMOS 0"*) fout "statusbalk: toont een teller waar niets bekend is" ;; *) ok "statusbalk: geen verzonnen teller" ;; esac

printf 'RMOS WIJZIGINGEN\n\nWACHT OP JOU (4) — werk dat stilstaat\n' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 4"*) ok "statusbalk: teller uit een boot-check" ;; *) fout "statusbalk: teller niet overgenomen" ;; esac

printf 'RMOS 1.3.0 · niets veranderd sinds jouw laatste sessie en niets dat op jou wacht.\n' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 4"*) fout "statusbalk: oude teller bleef staan na een stille check" ;; *) ok "statusbalk: teller op nul na een stille check" ;; esac

printf 'RMOS ZOEKRESULTAAT · niets te maken met de boot-check\n' | bash "$PT"
[ -f "$CLAUDE_CONFIG_DIR/.rmos-status" ] && ok "statusbalk: andere tools laten de stand met rust" || fout "statusbalk: stand verdween"
printf '%s 9\n' "$(( $(date +%s) - 46800 ))" > "$CLAUDE_CONFIG_DIR/.rmos-status"
case "$(bash "$SL")" in *"RMOS 9"*) fout "statusbalk: toont een teller van 13 uur oud" ;; *) ok "statusbalk: verouderde teller vervalt" ;; esac
unset CLAUDE_CONFIG_DIR

# 7. de manifesten moeten geldige JSON zijn, anders weigert Claude Code de plugin
for f in .claude-plugin/marketplace.json rmos/.claude-plugin/plugin.json rmos/hooks/hooks.json; do
  p="$(dirname "$0")/$f"
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$p" 2>/dev/null; then
    ok "$f is geldige JSON"
  else
    fout "$f is geen geldige JSON"
  fi
done

# 8. hooks.json moet naar een bestaand script wijzen
if grep -q 'boot.sh' "$(dirname "$0")/rmos/hooks/hooks.json" && [ -f "$HOOK" ]; then
  ok "hooks.json wijst naar een bestaande boot.sh"
else
  fout "hooks.json en boot.sh lopen uit elkaar"
fi

echo
if [ $fouten -eq 0 ]; then echo "Alles goed."; else echo "$fouten controle(s) gefaald."; exit 1; fi
