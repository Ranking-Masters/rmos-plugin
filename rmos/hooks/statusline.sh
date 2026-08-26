#!/bin/bash
# RMOS-badge voor de statusbalk.
#
# Drie dingen zichtbaar maken: dat RMOS meedraait, of er iets op je wacht, en of
# de connector nog antwoordt. Dat eerste is de helft van de waarde — een collega
# die niet weet of de plugin aan staat, gaat het navragen, en navragen is precies
# wat hier weg moest.
#
# Claude Code kent maar één `statusLine` en die staat per definitie in iemands
# persoonlijke settings.json: een plugin mag dat veld niet zetten (`plugin.json`
# noemt het een onbekend veld en negeert het, en `StatusLine` is geen hook-event).
# Gevolg: de regel in settings.json roept dit script aan, en dit script moet dus
# zélf weten of het nog bij een levende plugin hoort. Anders blijft de badge
# staan na een uninstall, en een badge die liegt is erger dan geen badge.
set -uo pipefail

# Ben ik nog van een levende plugin?
#
# Bij een uninstall laat Claude Code de cachemap staan tot geen enkele sessie
# hem nog vasthoudt, en zet er `.orphaned_at` in. Het script bestaat dan nog,
# de glob in settings.json vindt het nog, en de badge bleef daardoor hangen op
# een plugin die niet meer geladen was.
#
# Bewust géén check op registratie in installed_plugins.json of enabledPlugins:
# een organisatie-uitrol via claude.ai zet die niet in de persoonlijke config,
# dus dat zou de badge bij iedereen stil uitzetten. Deze kant faalt open —
# geen doodsbriefje betekent levend.
zelf="${BASH_SOURCE[0]:-$0}"
wortel="$(cd "$(dirname "$zelf")/.." 2>/dev/null && pwd)" || wortel=""
[ -n "$wortel" ] && [ -e "$wortel/.orphaned_at" ] && exit 0

GROEN='\033[38;5;108m'
ORANJE='\033[38;5;208m'
ROOD='\033[38;5;167m'
UIT='\033[0m'

# Vorm: "<epoch teller> <aantal> <staat> <epoch staat>". Twee klokken, want het
# zijn twee feiten die apart verlopen: wanneer de teller gemeten is, en wanneer
# de connector voor het laatst antwoordde. Een bestand van de vorige versie heeft
# twee kolommen en telt als 'ok' zonder staatsklok. Geen flag day.
#
# Ouder dan 12 uur zegt niets meer over vandaag. Dat geldt voor beide: een
# verlopen teller verdwijnt, en een storing van gisteravond is geen storing van nu.
stand="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rmos-status"
aantal=""
staat="ok"
if [ -f "$stand" ]; then
  read -r gezet n s gezet_s _ < "$stand" 2>/dev/null || true
  nu=$(date +%s)
  case "${gezet:-}${n:-}" in
    *[!0-9]*|"") ;;
    *) [ $((nu - gezet)) -lt 43200 ] && aantal="$n" ;;
  esac
  case "${gezet_s:-}" in
    *[!0-9]*|"") ;;
    *) [ "${s:-ok}" = "fail" ] && [ $((nu - gezet_s)) -lt 43200 ] && staat="fail" ;;
  esac
fi

# Een kapotte connector eerst: de teller is dan per definitie oud, en die naast
# een storing tonen wekt de indruk dat hij nog ergens op gebaseerd is.
if [ "$staat" = "fail" ]; then
  printf "${ROOD}[RMOS !]${UIT}"
elif [ -n "$aantal" ] && [ "$aantal" -gt 0 ] 2>/dev/null; then
  printf "${ORANJE}[RMOS %s]${UIT}" "$aantal"
else
  printf "${GROEN}[RMOS]${UIT}"
fi
