#!/bin/bash
# Vangt het antwoord van rmos_changes op en onthoudt hoeveel er op deze persoon
# wacht, zodat de statusbalk dat kan tonen zonder zelf te hoeven bellen.
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

# Alleen het antwoord van de boot-check telt. Gate op de vaste kop, niet op de
# toolnaam alleen: die kan ook in andere teksten voorkomen.
case "$payload" in
  *"RMOS WIJZIGINGEN"*|*"niets veranderd sinds jouw laatste sessie"*|*"niets veranderd in de kennis"*|*"eerste keer dat deze toegang verbindt"*) ;;
  *) exit 0 ;;
esac

stand="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rmos-status"
nu=$(date +%s)

# "WACHT OP JOU (3)" → 3. Staat het blok er niet, dan wacht er niets op deze
# persoon: dat is een geldige uitkomst en hoort óók vastgelegd te worden,
# anders blijft er een oud getal in de balk staan.
n=$(printf '%s' "$payload" | grep -oE 'WACHT OP JOU \(([0-9]+)\)' | head -1 | grep -oE '[0-9]+' || true)
[ -n "$n" ] || n=0
printf '%s %s\n' "$nu" "$n" > "$stand" 2>/dev/null
exit 0
