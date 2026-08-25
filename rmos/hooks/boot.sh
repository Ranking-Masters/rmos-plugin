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
set -uo pipefail

# In een codebase gaat het gesprek over die code, niet over iemands rol in het
# bedrijf. Daar zwijgen we — anders vuurt dit in elke klantrepo en gaat het
# binnen een week uit. Rolmappen (~/Projects/{Voornaam - Rol}, de AIOS-map)
# zijn geen git-repo; dat is precies het onderscheid dat we nodig hebben.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

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
exit 0
