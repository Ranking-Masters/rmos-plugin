#!/bin/bash
# RMOS boot-check.
#
# Deze hook haalt geen kennis op, slaat niets op en kent geen sleutel. Het enige
# wat hij doet is op positie nul in de sessie vertellen wat er van de agent wordt
# verwacht. Alle inhoud komt daarna uit de MCP, die weet wie er belt en welke
# kennisversie deze persoon het laatst zag.
#
# Waarom zo saai: een hook die zelf kennis ophaalt, wordt een tweede bron van
# waarheid die stil kan afwijken van de server. Dit is een startschot, geen bron.
#
# Twee dingen die hier eerder stil fout gingen, en waarom ze nu zo staan:
#
# 1. Er stond een poort die deze hook in elke git-repo liet zwijgen — het gesprek
#    zou daar over de code gaan en niet over iemands rol. Maar collega's zitten
#    hun hele dag in repo's, dus stond de autonomie precies daar uit, en een hook
#    die niets uitvoert ziet er hetzelfde uit als een hook die niets te melden
#    heeft. Git bepaalt nu alleen nog de nadruk, niet of dit vuurt.
#
# 2. De melding "er zijn geen rmos_-tools" stond als laatste alinea onderaan, en
#    werd overgeslagen bij een kort bericht. Bij een collega bleef daardoor
#    onopgemerkt dat hij nul RMOS-tools had. Die melding staat nu vooraan.
set -uo pipefail

# Alleen deze bootcheck overslaan, en met opzet expliciet. Voor wie geen enkele
# RMOS-aanroep bij het opstarten wil maar de badge wél wil houden. De knop voor
# de hele plugin staat hieronder.
case "${RMOS_BOOT:-1}" in 0|off|false) exit 0 ;; esac

# Onze eigen versie, uit het manifest ernaast. Waarom dit meegaat naar RMOS: een
# verouderde plugin ziet er van buiten precies hetzelfde uit als een actuele, en
# geeft wél verouderde instructies. Bouke leverde op 28 augustus 2026 een audit in
# met een wijziging voor een schakelaar die al bestond, omdat bij hem 2.2.0 stond
# en niet 2.7.1 — uren werk aan iets dat er al was.
#
# Deze hook doet zelf geen netwerkaanroep (dat blijft zo: hij is een startschot,
# geen tweede bron van waarheid). Hij zegt alleen wat hij is; RMOS kijkt of dat de
# huidige versie is en meldt het.
PLUGIN_MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.claude-plugin" 2>/dev/null && pwd)/plugin.json"
PLUGIN_VERSIE="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9.]*\)".*/\1/p' "$PLUGIN_MANIFEST" 2>/dev/null | head -1)"
[ -z "$PLUGIN_VERSIE" ] && PLUGIN_VERSIE="onbekend"

# En de knop die de hele plugin uitzet, voor wie even privé wil werken:
# `claude --rmos-off` via de wrapper uit de README, `RMOS_OFF=1` in je shell, of
# het bestand voor wie het permanent wil. Alle vijf de scripts kijken hiernaar.
#
# Waarom dit één regel zégt in plaats van te zwijgen zoals RMOS_BOOT=0: de
# connector zet zijn eigen gebruiksinstructie in de systeemprompt, en die blijft
# de agent naar rmos_start duwen ook als deze plugin niets meer roept. Zwijgen
# zou hier dus "uit" heten en "aan" zijn. Wie ook die regel niet wil, zet de
# connector er met /mcp bij uit.
rmos_uit=0
case "${RMOS_OFF:-0}" in 1|on|true|uit) rmos_uit=1 ;; esac
[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/rmos-off" ] && rmos_uit=1
if [ "$rmos_uit" = 1 ]; then
  echo "RMOS staat uit in deze sessie. Gebruik de rmos_-tools niet en zeg hier verder niets over."
  exit 0
fi

echo "RMOS · het bedrijfsbrein van Ranking Masters draait mee in deze sessie."
echo

# Staat er een eigen RMOS-server in de persoonlijke config? Dan verbergt Claude
# Code de connector van de organisatie als duplicaat en heeft deze persoon nul
# RMOS-tools, terwijl alles ingesteld lijkt. Dat trof juist de collega's die het
# eerst meededen, want die voegden RMOS destijds zelf toe.
#
# python3 is hier geen nieuwe afhankelijkheid: op macOS komt hij uit dezelfde
# developer tools als de git die deze hook onderaan al gebruikt. Faalt hij, dan
# blijft dit blok weg — een diagnose mag nooit de rest kapotmaken.
eigen=""
if command -v python3 >/dev/null 2>&1; then
  eigen=$(python3 "$(dirname "${BASH_SOURCE[0]:-$0}")/eigen-rmos.py" 2>/dev/null || true)
fi

if [ -n "$eigen" ]; then
  naam=$(printf '%s' "$eigen" | head -1 | cut -f1)
  echo "EERST DIT. In de persoonlijke Claude Code-config van deze gebruiker staat een"
  echo "eigen RMOS-server (\"$naam\"). Claude Code verbergt de RMOS-connector van de"
  echo "organisatie dan als duplicaat — \"hidden, same URL as your server\" — en dan zijn"
  echo "er geen rmos_-tools, ook al lijkt alles goed te staan. Meld dit in je eerste"
  echo "antwoord in gewone taal en bied aan het op te lossen met:"
  echo
  echo "  claude mcp remove $naam"
  echo
  echo "Voer dat niet uit zonder te vragen; het is hun configuratie. Daarna één nieuwe"
  echo "sessie starten. Er gaat niets verloren: de connector doet hetzelfde en heeft"
  echo "geen sleutel op de laptop nodig."
  echo
fi

# De plaatshouder vullen: de heredoc is aangehaald zodat de tekst zelf ongemoeid
# blijft (er staan $-tekens en backticks in), dus vervangen doet sed erna.
sed "s/__PLUGIN_VERSIE__/$PLUGIN_VERSIE/" <<'EOF'
Heb je geen rmos_-tools tot je beschikking, dan is dat het eerste wat je meldt —
in één regel, ook als het bericht van de gebruiker maar één woord is. Zonder die
tools is dit bericht het enige signaal dat RMOS er hoort te zijn, dus zwijgen
betekent dat niemand het merkt. os.rankingmasters.nl/agents legt uit hoe je
verbindt. Wil iemand dit bewust niet zien: RMOS_OFF=1 in zijn shell.

Heb je ze wél, doe dan dit vóór je eerste antwoord, zonder het te vragen:

1. Roep rmos_changes aan (zonder ack) en geef plugin: "__PLUGIN_VERSIE__" mee.
   RMOS weet wie je bent, wat deze persoon het laatst zag, en of jouw plugin
   achterloopt.
   Staat er "niets veranderd", dan zeg je niets en werk je gewoon door. Staat er "niets veranderd", zeg dan niets en werk gewoon door.
   Is er wél iets: vertel het kort en toegespitst op de rol van deze persoon, en
   zeg erbij wat er lokaal moet worden vastgelegd. Pas nadat je het gemeld hebt
   roep je rmos_changes nog eens aan met ack: true — dan pas telt het als gezien.
   Ack je meteen, dan verdwijnt een wijziging die niemand gelezen heeft.

2. Ontstaat er een nieuwe taak, wens of een "hoe doen we dit ook alweer": roep
   rmos_start aan vóórdat je zelf iets bedenkt. Negen van de tien keer bestaat
   er al een proces, template, tool of skill voor. Zelf verzinnen wat er al ligt
   is de duurste fout die je hier kunt maken.
EOF

# In een codebase geldt hetzelfde, met een andere weegschaal. Niet zwijgen dus,
# maar de nadruk verleggen: hier wordt opnieuw gebouwd wat al bestaat.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  cat <<'EOF'

Je zit in een codebase. Dat verandert niets aan het bovenstaande, alleen de
weegschaal: punt 2 weegt hier het zwaarst. Een repo is precies de plek waar
iemand een script, skill, template of afspraak opnieuw bouwt die er al ligt.
Punt 1 houd je hier kort — meld alleen wat dít werk raakt en laat de rest staan.
EOF
fi
exit 0
