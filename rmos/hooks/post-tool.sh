#!/bin/bash
# Vangt het antwoord van een RMOS-tool op en onthoudt twee dingen: hoeveel er op
# deze persoon wacht, en dat de connector nog antwoordde. De statusbalk leest dat
# zonder zelf te hoeven bellen.
#
# Bewust géén tweede bron van waarheid: dit is een gecachet gétal uit een
# antwoord dat de agent tóch al ophaalde, geen kopie van bedrijfskennis. Er
# staat geen sleutel in en geen inhoud. Weg is weg: dan toont de badge gewoon
# geen teller.
set -uo pipefail

# Bounded lezen met een bash-ingebouwde: `timeout` bestaat niet overal (macOS
# heeft het niet), en een blokkerende lees na élke tool-call is erger dan een
# gemiste teller.
payload=""
IFS= read -r -d '' -t 2 payload || true
[ -n "$payload" ] || exit 0

# Gate op de toolnaam, niet op de inhoud. Een Bash-call die 'RMOS WIJZIGINGEN'
# print — een collega die dit script leest, bijvoorbeeld — hoort de stand niet
# te overschrijven. Ontbreekt tool_name (andere payloadvorm dan verwacht), dan
# valt hij terug op de oude tekstgate: liever een teller te veel dan een hook
# die stil niets meer doet.
naam=$(printf '%s' "$payload" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1)
if [ -n "$naam" ]; then
  case "$naam" in *RMOS*) ;; *) exit 0 ;; esac
else
  case "$payload" in
    *"RMOS WIJZIGINGEN"*|*"niets veranderd sinds jouw laatste sessie"*|*"niets veranderd in de kennis"*|*"eerste keer dat deze toegang verbindt"*) ;;
    *) exit 0 ;;
  esac
fi

stand="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rmos-status"
nu=$(date +%s)

# Vorm: "<epoch teller> <aantal> <staat> <epoch staat>". Twee klokken, want het
# zijn twee feiten: wanneer de teller gemeten is, en wanneer de connector voor
# het laatst antwoordde. Eén klok zou een oude teller verjongen bij elke
# willekeurige RMOS-call.
gezet=""; aantal=""
[ -f "$stand" ] && read -r gezet aantal _ _ < "$stand" 2>/dev/null || true
case "${gezet}${aantal}" in *[!0-9]*|"") gezet=""; aantal="" ;; esac

# Alleen het antwoord van de boot-check bevat een teller. "WACHT OP JOU (3)" → 3.
# Staat het blok er niet in een boot-check-antwoord, dan wacht er niets op deze
# persoon: dat is een geldige uitkomst en hoort óók vastgelegd te worden, anders
# blijft er een oud getal in de balk staan.
case "$payload" in
  *"RMOS WIJZIGINGEN"*|*"niets veranderd sinds jouw laatste sessie"*|*"niets veranderd in de kennis"*|*"eerste keer dat deze toegang verbindt"*)
    n=$(printf '%s' "$payload" | grep -oE 'WACHT OP JOU \(([0-9]+)\)' | head -1 | grep -oE '[0-9]+' || true)
    [ -n "$n" ] || n=0
    gezet="$nu"; aantal="$n"
    ;;
esac

# Elke geslaagde RMOS-call is bewijs dat de connector staat, dus die wist een
# eerdere storing. Is er nooit een teller gemeten, dan blijft die leeg — onbekend
# is geen nul.
printf '%s %s ok %s\n' "${gezet:-0}" "${aantal:-0}" "$nu" > "$stand" 2>/dev/null
exit 0
