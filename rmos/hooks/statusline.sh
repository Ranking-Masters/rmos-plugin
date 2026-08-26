#!/bin/bash
# RMOS-badge voor de statusbalk.
#
# Drie dingen zichtbaar maken: dat RMOS meedraait, of er iets op je wacht, en of
# de connector nog antwoordt. En bij het tweede: er in één klik naartoe kunnen.
# Een badge die zegt "er wachten drie dingen" en je daarna zelf laat zoeken,
# kost meer aandacht dan hij oplevert.
#
# Claude Code kent maar één `statusLine` en die staat per definitie in iemands
# settingsbestand: een plugin mag dat veld niet zetten (`plugin.json` noemt het
# een onbekend veld en negeert het, en `StatusLine` is geen hook-event). Gevolg:
# de regel in settings.json roept dit script aan, en dit script moet dus zélf
# weten of het nog bij een levende plugin hoort. Anders blijft de badge staan na
# een uninstall, en een badge die liegt is erger dan geen badge.
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

# Escapes als echte tekens, niet als printf-format. Zo kan er geen URL met een
# procentteken of backslash tussendoor glippen en de balk slopen.
ESC=$'\033'
BEL=$'\a'
GROEN="${ESC}[38;5;108m"
ORANJE="${ESC}[38;5;208m"
ROOD="${ESC}[38;5;167m"
UIT="${ESC}[0m"

basis="${RMOS_URL:-https://os.rankingmasters.nl}"
basis="${basis%/}"

# Klikbaar maken met OSC 8, maar alleen waar dat aankomt. In een terminal die
# het niet kent — Terminal.app bijvoorbeeld — zou de escape als rommel in de
# balk staan, en dan is de badge slechter af dan zonder link. Onbekend telt
# daarom als "niet ondersteund"; RMOS_BADGE_LINK=1 forceert, 0 zet het uit.
link_kan=0
case "${TERM_PROGRAM:-}${KITTY_WINDOW_ID:+ kitty}${WT_SESSION:+ wt}${VTE_VERSION:+ vte}" in
  *WarpTerminal*|*iTerm*|*WezTerm*|*ghostty*|*vscode*|*Hyper*|*kitty*|*wt*|*vte*) link_kan=1 ;;
esac
case "${RMOS_BADGE_LINK:-}" in 1) link_kan=1 ;; 0) link_kan=0 ;; esac

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
# een storing tonen wekt de indruk dat hij nog ergens op gebaseerd is. De link
# gaat naar de verbindpagina, want dat is wat je op dat moment moet doen.
if [ "$staat" = "fail" ]; then
  kleur="$ROOD"; label="[RMOS !]"; doel="$basis/agents"
elif [ -n "$aantal" ] && [ "$aantal" -gt 0 ] 2>/dev/null; then
  kleur="$ORANJE"; label="[RMOS $aantal]"; doel="$basis/inbox"
else
  kleur="$GROEN"; label="[RMOS]"; doel="$basis"
fi

if [ "$link_kan" = 1 ]; then
  printf '%s' "${ESC}]8;;${doel}${BEL}${kleur}${label}${UIT}${ESC}]8;;${BEL}"
else
  printf '%s' "${kleur}${label}${UIT}"
fi
