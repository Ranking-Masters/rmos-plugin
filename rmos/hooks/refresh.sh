#!/bin/bash
# Houdt de teller in de statusbalk actueel terwijl iemand werkt.
#
# Het probleem: de teller wordt geschreven uit een RMOS-antwoord, en die komt
# alleen als de agent RMOS aanroept. Dient een collega om 11:00 iets in, dan
# weet jouw balk dat om 15:00 nog niet. Voor een bureau dat de hele dag naar dit
# scherm kijkt is dat het verschil tussen een badge die je vertrouwt en een
# badge die je negeert.
#
# Waarom niet gewoon zelf bellen: de RMOS-verbinding loopt via het claude.ai-
# token in de keychain. Dat in een shellscript trekken zet een sleutel op elke
# laptop van het bureau, voor een getal in een balk. Dat is de verkeerde ruil.
# De agent ís de geauthenticeerde weg naar RMOS; deze hook geeft hem alleen een
# zetje wanneer het getal oud is.
#
# Eén regel, maximaal één keer per interval, en alleen als er al een teller
# bestaat die verlopen is — bij sessiestart doet boot.sh dit werk al. Dat is
# ook de hele rem: hier stond een git-poort naast, en die maakte de hook dood
# in elke repo terwijl de teller daar net zo hard verouderd.
set -uo pipefail

case "${RMOS_REFRESH:-1}" in 0|off|false) exit 0 ;; esac

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
stand="$cfg/.rmos-status"
zetje="$cfg/.rmos-nudged"

# Geen stand betekent: deze sessie heeft RMOS nog niet gesproken. Dan heeft
# boot.sh de opdracht al gegeven en zou dit een tweede stem zijn.
[ -f "$stand" ] || exit 0

max="${RMOS_MAX_AGE:-600}"
case "$max" in *[!0-9]*|"") max=600 ;; esac

nu=$(date +%s)
read -r gezet _ _ _ _ < "$stand" 2>/dev/null || exit 0
case "${gezet:-}" in *[!0-9]*|"") exit 0 ;; esac
[ $((nu - gezet)) -lt "$max" ] && exit 0

# Eigen klok voor het zetje, los van de teller. Anders blijft dit elke prompt
# vuren zolang RMOS onbereikbaar is: de call faalt, de teller wordt niet
# verjongd, en de hook zou blijven aandringen.
if [ -f "$zetje" ]; then
  read -r vorig _ < "$zetje" 2>/dev/null || vorig=0
  case "${vorig:-}" in *[!0-9]*|"") vorig=0 ;; esac
  [ $((nu - vorig)) -lt "$max" ] && exit 0
fi
printf '%s\n' "$nu" > "$zetje" 2>/dev/null

minuten=$(( (nu - gezet) / 60 ))
cat <<EOF
RMOS · de teller in de statusbalk is $minuten minuten oud. Roep bij dit antwoord
één keer rmos_changes aan (zonder ack) zodat de balk klopt. Verder niets: is er
niets veranderd, zeg er dan niets over en doe gewoon waar de gebruiker om vroeg.
Is er wél iets, meld het in één regel na je antwoord.
EOF
exit 0
