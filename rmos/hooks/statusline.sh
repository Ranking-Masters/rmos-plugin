#!/bin/bash
# RMOS-badge voor de statusbalk.
#
# Twee dingen zichtbaar maken: dat RMOS meedraait, en of er iets op je wacht.
# Dat eerste is de helft van de waarde — een collega die niet weet of de plugin
# aan staat, gaat het navragen, en navragen is precies wat hier weg moest.
#
# De teller komt uit ~/.claude/.rmos-status, dat de PostToolUse-hook schrijft
# uit het antwoord dat de agent tóch al ophaalde. Dus geen sleutel op schijf en
# geen netwerkcall in je statusbalk. Staat het bestand er niet, dan tonen we
# alleen de badge: onbekend is geen nul.
set -uo pipefail

GROEN='\033[38;5;108m'
ORANJE='\033[38;5;208m'
UIT='\033[0m'

stand="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rmos-status"
aantal=""
if [ -f "$stand" ]; then
  # vorm: "<epoch> <aantal>"; ouder dan 12 uur zegt niets meer over vandaag
  gezet=$(cut -d' ' -f1 "$stand" 2>/dev/null)
  n=$(cut -d' ' -f2 "$stand" 2>/dev/null)
  nu=$(date +%s)
  case "$gezet$n" in
    *[!0-9]*|"") ;;
    *) [ $((nu - gezet)) -lt 43200 ] && aantal="$n" ;;
  esac
fi

if [ -n "$aantal" ] && [ "$aantal" -gt 0 ] 2>/dev/null; then
  printf "${ORANJE}[RMOS %s]${UIT}" "$aantal"
else
  printf "${GROEN}[RMOS]${UIT}"
fi
