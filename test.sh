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
PF="$(cd "$(dirname "$0")" && pwd)/rmos/hooks/post-tool-fail.sh"

# Hooks krijgen JSON op stdin, niet losse tekst. Testen op de echte vorm, anders
# toetst de zelftest een payload die in productie niet bestaat.
payload() { printf '{"hook_event_name":"PostToolUse","tool_name":"%s","tool_response":"%s"}' "$1" "$2"; }

uit="$(bash "$SL")"
case "$uit" in *RMOS*) ok "statusbalk: toont een badge zonder standbestand" ;; *) fout "statusbalk: geen badge" ;; esac
case "$uit" in *"RMOS ]"*|*"RMOS 0"*) fout "statusbalk: toont een teller waar niets bekend is" ;; *) ok "statusbalk: geen verzonnen teller" ;; esac

payload mcp__claude_ai_RMOS__rmos_changes 'RMOS WIJZIGINGEN\n\nWACHT OP JOU (4) - werk dat stilstaat' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 4"*) ok "statusbalk: teller uit een boot-check" ;; *) fout "statusbalk: teller niet overgenomen" ;; esac

payload mcp__claude_ai_RMOS__rmos_changes 'RMOS 1.3.0 - niets veranderd sinds jouw laatste sessie' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 4"*) fout "statusbalk: oude teller bleef staan na een stille check" ;; *) ok "statusbalk: teller op nul na een stille check" ;; esac

# Een andere tool die het woord RMOS in zijn output heeft — een collega die dit
# script leest — mag de stand niet aanraken. Dat was de gate op tekst in plaats
# van op toolnaam.
payload mcp__claude_ai_RMOS__rmos_find 'RMOS ZOEKRESULTAAT - niets te maken met de boot-check' | bash "$PT"
[ -f "$CLAUDE_CONFIG_DIR/.rmos-status" ] && ok "statusbalk: andere RMOS-tools laten de teller met rust" || fout "statusbalk: stand verdween"
payload Bash 'RMOS WIJZIGINGEN en WACHT OP JOU (99)' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 99"*) fout "statusbalk: een Bash-call schreef de teller" ;; *) ok "statusbalk: niet-RMOS-tools schrijven niets" ;; esac

printf '%s 9 ok %s\n' "$(( $(date +%s) - 46800 ))" "$(date +%s)" > "$CLAUDE_CONFIG_DIR/.rmos-status"
case "$(bash "$SL")" in *"RMOS 9"*) fout "statusbalk: toont een teller van 13 uur oud" ;; *) ok "statusbalk: verouderde teller vervalt" ;; esac

# 6b. een kapotte connector: de plugin doet dan niets nuttigs, dus dat hoort te zien
payload mcp__claude_ai_RMOS__rmos_start 'MCP error: not authenticated' | bash "$PF"
case "$(bash "$SL")" in *"RMOS !"*) ok "statusbalk: storing zichtbaar na een gefaalde RMOS-call" ;; *) fout "statusbalk: gefaalde RMOS-call blijft onzichtbaar" ;; esac

payload mcp__claude_ai_RMOS__rmos_changes 'RMOS WIJZIGINGEN\n\nWACHT OP JOU (2) - werk dat stilstaat' | bash "$PT"
case "$(bash "$SL")" in
  *"RMOS !"*) fout "statusbalk: storing bleef staan na een geslaagde call" ;;
  *"RMOS 2"*) ok "statusbalk: geslaagde call wist de storing en zet de teller" ;;
  *)          fout "statusbalk: onverwachte weergave na herstel" ;;
esac

payload Bash 'exit 127' | bash "$PF"
case "$(bash "$SL")" in *"RMOS !"*) fout "statusbalk: een gefaalde Bash-call gold als connectorstoring" ;; *) ok "statusbalk: alleen RMOS-tools melden een storing" ;; esac

printf '%s 2 fail %s\n' "$(date +%s)" "$(( $(date +%s) - 46800 ))" > "$CLAUDE_CONFIG_DIR/.rmos-status"
case "$(bash "$SL")" in *"RMOS !"*) fout "statusbalk: toont een storing van 13 uur oud" ;; *) ok "statusbalk: verouderde storing vervalt" ;; esac

# 6c. een bestand van de vorige versie heeft twee kolommen en moet blijven werken
printf '%s 5\n' "$(date +%s)" > "$CLAUDE_CONFIG_DIR/.rmos-status"
case "$(bash "$SL")" in *"RMOS 5"*) ok "statusbalk: leest een standbestand van de vorige versie" ;; *) fout "statusbalk: oud standbestand niet meer leesbaar" ;; esac
unset CLAUDE_CONFIG_DIR

# 6d. de dragende reden dat dit script zijn eigen levendheid checkt: na een
#     uninstall blijft de cachemap staan tot geen sessie hem vasthoudt, en de
#     glob in settings.json vindt hem dan nog. Bleef de badge staan, dan meldt
#     hij een plugin die niet geladen is — en dat was precies de bug.
mkdir -p "$TMP/wees/hooks"
cp "$SL" "$TMP/wees/hooks/statusline.sh"
[ -n "$(bash "$TMP/wees/hooks/statusline.sh")" ] && ok "statusbalk: spreekt in een levende pluginmap" || fout "statusbalk: zwijgt in een levende pluginmap"
touch "$TMP/wees/.orphaned_at"
[ -z "$(bash "$TMP/wees/hooks/statusline.sh")" ] && ok "statusbalk: zwijgt in een verweesde pluginmap" || fout "statusbalk: badge blijft staan na uninstall"

# 6e. klikbaar: een badge die zegt "er wachten drie dingen" en je daarna zelf
#     laat zoeken, kost meer aandacht dan hij oplevert. Maar de escape mag
#     alleen naar buiten waar de terminal hem kent, anders staat er rommel.
export CLAUDE_CONFIG_DIR="$TMP/cfg2"; mkdir -p "$CLAUDE_CONFIG_DIR"
nu=$(date +%s)

printf '%s 0 ok %s\n' "$nu" "$nu" > "$CLAUDE_CONFIG_DIR/.rmos-status"
uit="$(RMOS_BADGE_LINK=1 bash "$SL")"
case "$uit" in *']8;;https://os.rankingmasters.nl'*) ok "klikbaar: groen linkt naar de basis-URL" ;; *) fout "klikbaar: groen mist de link" ;; esac

printf '%s 3 ok %s\n' "$nu" "$nu" > "$CLAUDE_CONFIG_DIR/.rmos-status"
uit="$(RMOS_BADGE_LINK=1 bash "$SL")"
case "$uit" in *']8;;https://os.rankingmasters.nl/inbox'*) ok "klikbaar: teller linkt naar de inbox" ;; *) fout "klikbaar: teller linkt niet naar de inbox" ;; esac

printf '%s 3 fail %s\n' "$nu" "$nu" > "$CLAUDE_CONFIG_DIR/.rmos-status"
uit="$(RMOS_BADGE_LINK=1 bash "$SL")"
case "$uit" in *']8;;https://os.rankingmasters.nl/agents'*) ok "klikbaar: storing linkt naar de verbindpagina" ;; *) fout "klikbaar: storing linkt niet naar /agents" ;; esac

uit="$(RMOS_BADGE_LINK=0 bash "$SL")"
case "$uit" in *']8;;'*) fout "klikbaar: escape lekt in een terminal die het niet kan" ;; *) ok "klikbaar: geen escape waar de terminal het niet kent" ;; esac
case "$uit" in *"RMOS !"*) ok "klikbaar: zonder link nog steeds een badge" ;; *) fout "klikbaar: zonder link geen badge" ;; esac

uit="$(RMOS_BADGE_LINK=1 RMOS_URL="https://os.test.nl/" bash "$SL")"
case "$uit" in *']8;;https://os.test.nl/agents'*) ok "klikbaar: RMOS_URL wint, dubbele slash weggepoetst" ;; *) fout "klikbaar: RMOS_URL niet overgenomen of slash blijft staan" ;; esac

# een badge zonder terminalinfo hoort plat te zijn: onbekend is niet ondersteund
uit="$(env -u TERM_PROGRAM -u KITTY_WINDOW_ID -u WT_SESSION -u VTE_VERSION bash "$SL")"
case "$uit" in *']8;;'*) fout "klikbaar: onbekende terminal krijgt toch een escape" ;; *) ok "klikbaar: onbekende terminal krijgt een platte badge" ;; esac
unset CLAUDE_CONFIG_DIR

# 6f. de teller actueel houden terwijl iemand werkt. Deze hook mag maar in één
#     situatie iets zeggen, en moet in alle andere zwijgen — hij vuurt bij élk
#     bericht, dus een valse positief is meteen zeventien keer per dag ruis.
RF="$(cd "$(dirname "$0")" && pwd)/rmos/hooks/refresh.sh"
export CLAUDE_CONFIG_DIR="$TMP/cfg3"; mkdir -p "$CLAUDE_CONFIG_DIR"
mkdir -p "$TMP/rolmap2"; oud=$(( $(date +%s) - 3600 ))

[ -z "$(cd "$TMP/rolmap2" && bash "$RF")" ] && ok "verversen: zwijgt zonder standbestand (boot.sh doet dat al)" || fout "verversen: praat zonder stand"

printf '%s 0 ok %s\n' "$(date +%s)" "$(date +%s)" > "$CLAUDE_CONFIG_DIR/.rmos-status"
[ -z "$(cd "$TMP/rolmap2" && bash "$RF")" ] && ok "verversen: zwijgt bij een verse teller" || fout "verversen: dringt aan op een verse teller"

printf '%s 2 ok %s\n' "$oud" "$oud" > "$CLAUDE_CONFIG_DIR/.rmos-status"
uit="$(cd "$TMP/rolmap2" && bash "$RF")"
case "$uit" in *rmos_changes*) ok "verversen: vraagt om rmos_changes bij een oude teller" ;; *) fout "verversen: zwijgt bij een oude teller" ;; esac
case "$uit" in *"60 minuten"*) ok "verversen: noemt de leeftijd" ;; *) fout "verversen: noemt de leeftijd niet" ;; esac

[ -z "$(cd "$TMP/rolmap2" && bash "$RF")" ] && ok "verversen: dringt niet twee keer binnen hetzelfde interval aan" || fout "verversen: blijft aandringen — ruis bij elk bericht"

rm -f "$CLAUDE_CONFIG_DIR/.rmos-nudged"
printf '%s 2 ok %s\n' "$oud" "$oud" > "$CLAUDE_CONFIG_DIR/.rmos-status"
mkdir -p "$TMP/code2" && (cd "$TMP/code2" && git init -q 2>/dev/null)
[ -z "$(cd "$TMP/code2" && bash "$RF")" ] && ok "verversen: zwijgt in een codebase" || fout "verversen: praat in een codebase"

[ -z "$(cd "$TMP/rolmap2" && RMOS_REFRESH=0 bash "$RF")" ] && ok "verversen: RMOS_REFRESH=0 zet het uit" || fout "verversen: laat zich niet uitzetten"

printf 'rommel\n' > "$CLAUDE_CONFIG_DIR/.rmos-status"
[ -z "$(cd "$TMP/rolmap2" && bash "$RF")" ] && ok "verversen: zwijgt bij een onleesbare stand" || fout "verversen: praat op rommel"
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

# 8. hooks.json moet naar bestaande scripts wijzen — een typo hier is een hook
#    die stil nooit vuurt
H="$(dirname "$0")/rmos/hooks/hooks.json"
for s in boot.sh post-tool.sh post-tool-fail.sh refresh.sh; do
  if grep -q "$s" "$H" && [ -f "$(dirname "$0")/rmos/hooks/$s" ]; then
    ok "hooks.json wijst naar een bestaande $s"
  else
    fout "hooks.json en $s lopen uit elkaar"
  fi
done

echo
if [ $fouten -eq 0 ]; then echo "Alles goed."; else echo "$fouten controle(s) gefaald."; exit 1; fi
