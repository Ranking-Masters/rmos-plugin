#!/bin/bash
# Zelftest voor de RMOS-plugin. Geen framework, geen fixtures: één bestand dat
# faalt als het gedrag verandert.
#
# Waarom dit bestaat: elke faalmodus van deze plugin is stil. Een hook die niets
# uitvoert ziet er precies zo uit als een hook die niets te melden heeft, en een
# badge die groen staat ziet er precies zo uit of RMOS nu geantwoord heeft of
# nooit. Dat is één keer echt misgegaan: boot.sh had een poort die hem in elke
# git-repo liet zwijgen, en omdat collega's hun dag in repo's doorbrengen stond
# de hele autonomie daar uit zonder dat iemand het kon zien. Deze test bestaat
# om dat soort stilte hard te laten falen.
set -uo pipefail

# Eerst de eigen omgeving leegvegen. Wie deze test draait met RMOS_BADGE_LINK of
# RMOS_BOOT in zijn shell, meet een andere wereld dan de collega die de plugin
# krijgt — en dan is de uitslag erger dan geen uitslag. De test zet zelf wat hij
# nodig heeft.
unset RMOS_BADGE_LINK RMOS_URL RMOS_BOOT RMOS_REFRESH RMOS_MAX_AGE RMOS_OFF

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

# 3. codebase (git): moet óók spreken. Dit is de regressie die één keer echt
#    is opgetreden: hier stond een poort en daarmee stond RMOS uit op de plek
#    waar collega's het grootste deel van hun dag zitten.
mkdir -p "$TMP/code" && (cd "$TMP/code" && git init -q 2>/dev/null)
uit2="$(cd "$TMP/code" && bash "$HOOK")"; code2=$?
[ $code2 -eq 0 ] && ok "codebase: exit 0" || fout "codebase: exit $code2, moet 0 zijn"
[ -n "$uit2" ] && ok "codebase: spreekt" || fout "codebase: zwijgt — dit is de regressie, RMOS staat dan uit in elke repo"
case "$uit2" in *rmos_changes*) ok "codebase: noemt rmos_changes" ;; *) fout "codebase: noemt rmos_changes niet" ;; esac
case "$uit2" in *rmos_start*)   ok "codebase: noemt rmos_start" ;;   *) fout "codebase: noemt rmos_start niet" ;; esac
case "$uit2" in *codebase*)     ok "codebase: verlegt de nadruk" ;;  *) fout "codebase: geen woord over de codebase, dan is de weging weg" ;; esac
[ "${#uit2}" -gt "${#uit}" ] && ok "codebase: langer dan de rolmap-tekst" || fout "codebase: niet langer, dus de extra alinea komt niet mee"

# 4. submap van een repo: zelfde verhaal, want dat is nog steeds diezelfde repo
mkdir -p "$TMP/code/diep/er"
uit3="$(cd "$TMP/code/diep/er" && bash "$HOOK")"
[ -n "$uit3" ] && ok "submap van een repo: spreekt" || fout "submap van een repo: zwijgt"
case "$uit3" in *codebase*) ok "submap: nog steeds de codebase-nadruk" ;; *) fout "submap: verliest de codebase-nadruk" ;; esac

# 5. faalt of ontbreekt git, dan mag de hook niet stuk. Zwijgen mag hier nooit
#    het gevolg zijn: git is alleen nog goed voor de nadruk, niet voor het wel
#    of niet vuren.
mkdir -p "$TMP/bin"
printf '#!/bin/sh\nexit 127\n' > "$TMP/bin/git" && chmod +x "$TMP/bin/git"
uit4="$(cd "$TMP/code" && PATH="$TMP/bin:$PATH" bash "$HOOK")"; code4=$?
[ $code4 -eq 0 ] && ok "git faalt: exit 0" || fout "git faalt: exit $code4, moet 0 zijn"
[ -n "$uit4" ] && ok "git faalt: spreekt alsnog" || fout "git faalt: zwijgt, en dan hangt het vuren tóch aan git"
case "$uit4" in *rmos_changes*) ok "git faalt: opdracht is intact" ;; *) fout "git faalt: opdracht kwijt" ;; esac

# 5a. de diagnose die één collega stil zonder RMOS liet zitten. Wie RMOS destijds
#     zelf toevoegde, heeft een server 'rmos' in ~/.claude.json; Claude Code
#     verbergt de connector van de organisatie dan als duplicaat en dan zijn er
#     nul rmos_-tools terwijl alles goed lijkt te staan.
mkdir -p "$TMP/thuis-vies" "$TMP/thuis-schoon" "$TMP/thuis-leeg"
python3 - "$TMP" <<'PYEOF'
import json, io, os, sys
t = sys.argv[1]
io.open(os.path.join(t, "thuis-vies", ".claude.json"), "w", encoding="utf-8").write(json.dumps({
  "mcpServers": {"meta-ads": {"url": "https://meta.example/mcp"},
                 "rmos": {"type": "http", "url": "https://os.rankingmasters.nl/mcp"}}}))
# de valstrik: ~/.claude.json bewaart ook getypte prompts, dus grep op de URL
# zou hier een valse melding geven
io.open(os.path.join(t, "thuis-schoon", ".claude.json"), "w", encoding="utf-8").write(json.dumps({
  "mcpServers": {"meta-ads": {"url": "https://meta.example/mcp"}},
  "projects": {"/ergens": {"history": [{"display": "kijk op os.rankingmasters.nl/landing"}]}}}))
PYEOF

uitv="$(cd "$TMP/rolmap" && HOME="$TMP/thuis-vies" bash "$HOOK")"
case "$uitv" in *"claude mcp remove rmos"*) ok "eigen rmos-entry: noemt het exacte commando" ;; *) fout "eigen rmos-entry: geen commando, dan blijft die collega stil zonder RMOS" ;; esac
case "$uitv" in *"EERST DIT"*) ok "eigen rmos-entry: staat vooraan" ;; *) fout "eigen rmos-entry: niet vooraan, dan wordt het overgeslagen" ;; esac
case "$uitv" in *rmos_changes*) ok "eigen rmos-entry: de rest van de opdracht blijft staan" ;; *) fout "eigen rmos-entry: overschrijft de opdracht" ;; esac

uits="$(cd "$TMP/rolmap" && HOME="$TMP/thuis-schoon" bash "$HOOK")"
case "$uits" in *"claude mcp remove"*) fout "schone config: valse melding (URL in getypte historie)" ;; *) ok "schone config: geen valse melding" ;; esac

uitl="$(cd "$TMP/rolmap" && HOME="$TMP/thuis-leeg" bash "$HOOK")"
case "$uitl" in *"claude mcp remove"*) fout "geen config: valse melding" ;; *) ok "geen config: geen melding" ;; esac
[ -n "$uitl" ] && ok "geen config: de opdracht komt er nog" || fout "geen config: hook zwijgt helemaal"

# Ontbreekt of faalt python3, dan mag de diagnose wegblijven maar de opdracht
# niet. Twee echte varianten: een stukkende python3 vóór in PATH, en een PATH
# zonder python3 maar met de rest van het systeem. (PATH helemaal leegmaken
# toetst niets nuttigs — dan is er ook geen `cat` voor de heredocs, en een
# machine zonder coreutils draait geen Claude Code.)
mkdir -p "$TMP/stukbin"
printf '#!/bin/sh\nexit 127\n' > "$TMP/stukbin/python3" && chmod +x "$TMP/stukbin/python3"
uitp="$(cd "$TMP/rolmap" && HOME="$TMP/thuis-vies" PATH="$TMP/stukbin:$PATH" bash "$HOOK")"
case "$uitp" in *rmos_changes*) ok "stukke python3: opdracht blijft intact" ;; *) fout "stukke python3: hook valt om" ;; esac
case "$uitp" in *"claude mcp remove"*) fout "stukke python3: diagnose alsnog geprint" ;; *) ok "stukke python3: diagnose blijft stil" ;; esac

echte_py="$(command -v python3 || true)"
if [ -n "$echte_py" ]; then
  zonder="$(dirname "$echte_py")"
  schoon_pad="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v "^${zonder}$" | paste -sd: -)"
  uitz="$(cd "$TMP/rolmap" && HOME="$TMP/thuis-vies" PATH="$schoon_pad" bash "$HOOK" 2>/dev/null)"
  case "$uitz" in *rmos_changes*) ok "python3 niet in PATH: opdracht blijft intact" ;; *) fout "python3 niet in PATH: hook valt om" ;; esac
fi

# de melding bij nul tools moet vóór punt 1 staan, anders wordt hij overgeslagen
geen="$(printf '%s' "$uitl" | grep -n "geen rmos_-tools" | head -1 | cut -d: -f1)"
een="$(printf '%s' "$uitl" | grep -n "Roep rmos_changes aan" | head -1 | cut -d: -f1)"
if [ -n "$geen" ] && [ -n "$een" ] && [ "$geen" -lt "$een" ]; then
  ok "melding bij nul tools staat vóór de opdracht"
else
  fout "melding bij nul tools staat niet vooraan (regel ${geen:-?} vs ${een:-?})"
fi

# 5b. de uitweg moet werken, anders heeft niemand een antwoord op de privacyvraag
uit5="$(cd "$TMP/rolmap" && RMOS_BOOT=0 bash "$HOOK")"; code5=$?
[ $code5 -eq 0 ] && ok "RMOS_BOOT=0: exit 0" || fout "RMOS_BOOT=0: exit $code5"
[ -z "$uit5" ] && ok "RMOS_BOOT=0: zwijgt" || fout "RMOS_BOOT=0: praat toch, dan is er geen uitweg"
uit5b="$(cd "$TMP/rolmap" && RMOS_BOOT=off bash "$HOOK")"
[ -z "$uit5b" ] && ok "RMOS_BOOT=off: zwijgt ook" || fout "RMOS_BOOT=off: praat toch"

# 5c. de hele plugin uit — de knop voor wie even privé werkt. Die moet twee
#     dingen tegelijk doen: de opdracht weglaten én zeggen dát RMOS uit staat.
#     Alleen zwijgen is hier niet genoeg, en dat is geen detail: de connector
#     zet zijn eigen gebruiksinstructie in de systeemprompt, dus een stille hook
#     laat de agent alsnog naar rmos_start grijpen. Dan heet het uit en is het aan.
mkdir -p "$TMP/uitcfg"
uit6="$(cd "$TMP/rolmap" && CLAUDE_CONFIG_DIR="$TMP/uitcfg" RMOS_OFF=1 bash "$HOOK")"; code6=$?
[ $code6 -eq 0 ] && ok "RMOS_OFF=1: exit 0" || fout "RMOS_OFF=1: exit $code6"
case "$uit6" in *"staat uit"*) ok "RMOS_OFF=1: zegt dat RMOS uit staat" ;; *) fout "RMOS_OFF=1: zwijgt, en dan grijpt de agent alsnog naar de tools" ;; esac
case "$uit6" in *"Roep rmos_changes aan"*) fout "RMOS_OFF=1: geeft de opdracht toch nog" ;; *) ok "RMOS_OFF=1: geen opdracht meer" ;; esac
touch "$TMP/uitcfg/rmos-off"
uit6b="$(cd "$TMP/rolmap" && CLAUDE_CONFIG_DIR="$TMP/uitcfg" bash "$HOOK")"
case "$uit6b" in *"staat uit"*) ok "bestand rmos-off: werkt zonder omgevingsvariabele" ;; *) fout "bestand rmos-off: wordt genegeerd, dan is er geen permanente uit" ;; esac

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

# 6a. dof versus groen. Dit was een echte leugen: wie de connector nooit had
#     verbonden, zag een groene badge — "alles goed" — terwijl RMOS nog nooit
#     iets had gezegd. Groen mag alleen bij een actuele teller op nul.
case "$uit" in *"RMOS ·"*)   ok "statusbalk: dof zolang RMOS niets gezegd heeft" ;; *) fout "statusbalk: geen dof-staat, dan liegt groen" ;; esac
case "$uit" in *"38;5;108"*) fout "statusbalk: groen zonder één antwoord van RMOS" ;; *) ok "statusbalk: niet groen zonder antwoord" ;; esac
# link geforceerd, want anders toetst deze regel de terminal van wie de test
# draait in plaats van het doel van de badge — precies zoals dit lokaal groen
# was in Warp en op de runner rood.
case "$(RMOS_BADGE_LINK=1 bash "$SL")" in *']8;;'*"/agents"*) ok "statusbalk: dof linkt naar de verbinduitleg" ;; *) fout "statusbalk: dof linkt niet naar /agents" ;; esac

# Uit hoort in de balk te staan, niet weg te vallen. Een lege plek is niet te
# onderscheiden van een plugin die niet geladen is, en dan gaat iemand navragen.
case "$(RMOS_OFF=1 bash "$SL")" in *"RMOS uit"*) ok "statusbalk: toont dat RMOS uit staat" ;; *) fout "statusbalk: verzwijgt dat RMOS uit staat" ;; esac
printf '%s 0 ok %s\n' "$(date +%s)" "$(date +%s)" > "$CLAUDE_CONFIG_DIR/.rmos-status"
case "$(bash "$SL")" in *"38;5;108"*) ok "statusbalk: groen bij een actuele teller op nul" ;; *) fout "statusbalk: niet groen terwijl er niets wacht" ;; esac
rm -f "$CLAUDE_CONFIG_DIR/.rmos-status"

payload mcp__claude_ai_RMOS__rmos_changes 'RMOS WIJZIGINGEN\n\nWACHT OP JOU (4) - werk dat stilstaat' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 4"*) ok "statusbalk: teller uit een boot-check" ;; *) fout "statusbalk: teller niet overgenomen" ;; esac

payload mcp__claude_ai_RMOS__rmos_changes 'RMOS 1.3.0 - niets veranderd sinds jouw laatste sessie' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 4"*) fout "statusbalk: oude teller bleef staan na een stille check" ;; *) ok "statusbalk: teller op nul na een stille check" ;; esac

# 6b. de staartregel: elke RMOS-tool verjongt de teller, niet alleen de boot-check
payload mcp__claude_ai_RMOS__rmos_find 'ZOEKRESULTAAT\n\n1. Iets\n\nRMOS-stand: 7 punten wachten op jou -> https://os.rankingmasters.nl/inbox' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 7"*) ok "statusbalk: teller uit de staartregel van rmos_find" ;; *) fout "statusbalk: staartregel niet gelezen — de teller leeft dan alleen bij sessiestart" ;; esac
payload mcp__claude_ai_RMOS__rmos_read 'DOCUMENT\n\nRMOS-stand: 0 punten wachten op jou' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 0"*|*"RMOS 7"*) fout "statusbalk: nul uit de staartregel niet overgenomen" ;; *) ok "statusbalk: nul uit de staartregel wist de oude teller" ;; esac
case "$(bash "$SL")" in *"38;5;108"*) ok "statusbalk: groen na een verse nul" ;; *) fout "statusbalk: niet groen na een verse nul" ;; esac
# een teller in een gewone Bash-call blijft buiten de deur, ook in deze vorm
payload Bash 'RMOS-stand: 42 punten wachten op jou' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 42"*) fout "statusbalk: Bash-call schreef via de staartregel" ;; *) ok "statusbalk: staartregel geldt alleen voor RMOS-tools" ;; esac

# Een andere tool die het woord RMOS in zijn output heeft — een collega die dit
# script leest — mag de stand niet aanraken. Dat was de gate op tekst in plaats
# van op toolnaam.
payload mcp__claude_ai_RMOS__rmos_find 'RMOS ZOEKRESULTAAT - niets te maken met de boot-check' | bash "$PT"
[ -f "$CLAUDE_CONFIG_DIR/.rmos-status" ] && ok "statusbalk: andere RMOS-tools laten de teller met rust" || fout "statusbalk: stand verdween"
payload Bash 'RMOS WIJZIGINGEN en WACHT OP JOU (99)' | bash "$PT"
case "$(bash "$SL")" in *"RMOS 99"*) fout "statusbalk: een Bash-call schreef de teller" ;; *) ok "statusbalk: niet-RMOS-tools schrijven niets" ;; esac

printf '%s 9 ok %s\n' "$(( $(date +%s) - 46800 ))" "$(date +%s)" > "$CLAUDE_CONFIG_DIR/.rmos-status"
case "$(bash "$SL")" in *"RMOS 9"*) fout "statusbalk: toont een teller van 13 uur oud" ;; *) ok "statusbalk: verouderde teller vervalt" ;; esac
case "$(bash "$SL")" in *"RMOS ·"*) ok "statusbalk: verouderde teller wordt dof, niet groen" ;; *) fout "statusbalk: verouderde teller staat groen alsof hij actueel is" ;; esac

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
case "$(cd "$TMP/code2" && bash "$RF")" in
  *rmos_changes*) ok "verversen: dringt ook in een codebase aan" ;;
  *) fout "verversen: zwijgt in een codebase — de teller verouderd daar net zo hard" ;;
esac

[ -z "$(cd "$TMP/rolmap2" && RMOS_REFRESH=0 bash "$RF")" ] && ok "verversen: RMOS_REFRESH=0 zet het uit" || fout "verversen: laat zich niet uitzetten"

# De grote knop moet ook hier gelden, en bij de twee schrijvers. Een teller die
# doorloopt terwijl iemand denkt dat hij privé werkt is precies de leugen waar
# deze badge om begonnen is.
rm -f "$CLAUDE_CONFIG_DIR/.rmos-nudged"
printf '%s 2 ok %s\n' "$oud" "$oud" > "$CLAUDE_CONFIG_DIR/.rmos-status"
[ -z "$(cd "$TMP/rolmap2" && RMOS_OFF=1 bash "$RF")" ] && ok "verversen: RMOS_OFF=1 zet het ook uit" || fout "verversen: negeert RMOS_OFF"

rm -f "$CLAUDE_CONFIG_DIR/.rmos-status"
payload "mcp__claude_ai_RMOS__rmos_changes" "RMOS WIJZIGINGEN. WACHT OP JOU (3)" | RMOS_OFF=1 bash "$PT"
[ -f "$CLAUDE_CONFIG_DIR/.rmos-status" ] && fout "post-tool: schrijft de teller toch met RMOS_OFF=1" || ok "post-tool: schrijft niets met RMOS_OFF=1"

payload "mcp__claude_ai_RMOS__rmos_find" "boem" | RMOS_OFF=1 bash "$PF"
[ -f "$CLAUDE_CONFIG_DIR/.rmos-status" ] && fout "post-tool-fail: schrijft de staat toch met RMOS_OFF=1" || ok "post-tool-fail: schrijft niets met RMOS_OFF=1"

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
[ -f "$(dirname "$0")/rmos/hooks/eigen-rmos.py" ] && ok "eigen-rmos.py wordt meegeleverd" || fout "eigen-rmos.py ontbreekt, dan is de diagnose dood"
for c in uit aan; do
  [ -f "$(dirname "$0")/rmos/commands/$c.md" ] && ok "/rmos:$c wordt meegeleverd" || fout "/rmos:$c ontbreekt, dan is er geen permanente knop"
done
for s in boot.sh post-tool.sh post-tool-fail.sh refresh.sh; do
  if grep -q "$s" "$H" && [ -f "$(dirname "$0")/rmos/hooks/$s" ]; then
    ok "hooks.json wijst naar een bestaande $s"
  else
    fout "hooks.json en $s lopen uit elkaar"
  fi
done

echo
if [ $fouten -eq 0 ]; then echo "Alles goed."; else echo "$fouten controle(s) gefaald."; exit 1; fi
