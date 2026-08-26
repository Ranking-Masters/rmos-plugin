#!/bin/bash
# RMOS boot-check.
#
# Deze hook haalt niets op, slaat niets op en kent geen sleutel. Het enige wat
# hij doet is op positie nul in de sessie vertellen wat er van de agent wordt
# verwacht. Alle inhoud komt daarna uit de MCP, die weet wie er belt en welke
# kennisversie deze persoon het laatst zag.
#
# Waarom zo saai: een hook die zelf kennis ophaalt, wordt een tweede bron van
# waarheid die stil kan afwijken van de server. Dit is een startschot, geen bron.
#
# Hier stond eerst een poort: in een git-repo zweeg deze hook, omdat het gesprek
# daar over de code zou gaan en niet over iemands rol. Dat was fout, en het was
# stil fout. Collega's zitten hun hele dag in repo's — die poort zette RMOS uit
# op precies de plek waar hij het meest oplevert, en niemand kon zien waarom.
# De vraag is niet wáár dit vuurt maar of de agent iets te zeggen heeft, en dat
# beantwoordt rmos_changes zelf: geen nieuws is één stille regel.
set -uo pipefail

# De enige uitweg, en met opzet expliciet. Wie geen enkele RMOS-aanroep wil,
# zet dit in zijn shell; wie hem helemaal weg wil, zet de plugin uit.
case "${RMOS_BOOT:-1}" in 0|off|false) exit 0 ;; esac

cat <<'EOF'
RMOS · het bedrijfsbrein van Ranking Masters draait mee in deze sessie.

Doe dit vóór je eerste antwoord, zonder het te vragen:

1. Roep rmos_changes aan (zonder ack). RMOS weet wie je bent en wat deze persoon
   het laatst zag. Staat er "niets veranderd", zeg dan niets en werk gewoon door.
   Is er wél iets: vertel het kort en toegespitst op de rol van deze persoon, en
   zeg erbij wat er lokaal moet worden vastgelegd. Pas nadat je het gemeld hebt
   roep je rmos_changes nog eens aan met ack: true — dan pas telt het als gezien.
   Ack je meteen, dan verdwijnt een wijziging die niemand gelezen heeft.

2. Ontstaat er een nieuwe taak, wens of een "hoe doen we dit ook alweer": roep
   rmos_start aan vóórdat je zelf iets bedenkt. Negen van de tien keer bestaat
   er al een proces, template, tool of skill voor. Zelf verzinnen wat er al ligt
   is de duurste fout die je hier kunt maken.

Zijn er geen rmos_-tools? Dan is de connector niet verbonden. Zeg dat één keer
(os.rankingmasters.nl/agents legt uit hoe) en werk verder zonder.
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
