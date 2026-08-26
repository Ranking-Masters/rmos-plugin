# RMOS-plugin voor Claude Code

Zorgt dat het bedrijfsbrein meedraait zonder dat iemand erom hoeft te vragen.

| Onderdeel | Wat het doet |
|---|---|
| `hooks/boot.sh` | Bij sessiestart in een rolmap: draagt de agent op om RMOS te vragen wat er veranderde en om bij een nieuwe taak eerst te kijken wat er al bestaat. Zwijgt in een codebase. |
| `skills/rmos-nieuwe-taak` | Neemt het over zodra de bootinjectie is vervaagd: bij elke nieuwe taak eerst `rmos_start`. |
| `hooks/statusline.sh` | Badge voor je statusbalk: draait RMOS mee, en wacht er iets op je. |
| `hooks/post-tool.sh` | Onthoudt de teller uit het antwoord van de boot-check. Slaat geen kennis en geen sleutel op. |

## Wat deze plugin bewust níét doet

Hij haalt geen kennis op, slaat niets op en kent geen sleutel. Er staat dus nooit een tweede, verouderde versie van de bedrijfsafspraken op iemands laptop. De hook is een startschot; de inhoud komt uit de MCP, die weet wie er belt en welke kennisversie die persoon het laatst zag.

Dat betekent ook: **zonder verbonden RMOS-connector doet deze plugin niets nuttigs.** Verbinden gaat via os.rankingmasters.nl/agents.

## Installeren

```
claude plugin marketplace add Ranking-Masters/rmos-plugin && claude plugin install rmos@rmos
```

**De gewone route is dit niet.** Deze plugin wordt via **claude.ai → Organization settings → Plugins** naar de hele organisatie gesynct, dus hij staat al in je `/plugin`-lijst en je hoeft hem alleen aan te zetten. Geen marketplace toevoegen, geen commando.

Bovenstaande regel is de terugvalroute voor wie de organisatie-uitrol nog niet heeft én toegang heeft tot deze (privé) repo. Doe je het binnen Claude Code met `/plugin`, geef de twee commando's dan **één voor één** — het eerste opent een venster, en een tweede regel belandt in dat invoerveld.

Daarna geldt het in elke map, ook in nieuwe. Updates komen vanzelf mee.

## De badge in je statusbalk

Zodat je ziet dát RMOS meedraait — en of er iets op je wacht. Eén regel in `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash -c 'for d in \"$HOME\"/.claude/plugins/cache/rmos/rmos/*/hooks/statusline.sh; do [ -f \"$d\" ] && s=\"$d\"; done; [ -n \"${s:-}\" ] && bash \"$s\"; for p in \"$HOME\"/.claude/plugins/cache/ponytail/ponytail/*/hooks/ponytail-statusline.sh; do [ -f \"$p\" ] && q=\"$p\"; done; [ -n \"${q:-}\" ] && { printf \" \"; bash \"$q\"; }'"
}
```

| Je ziet | Wat het betekent |
|---|---|
| `[RMOS]` groen | RMOS draait mee, niets dat op jou wacht |
| `[RMOS 3]` oranje | drie punten wachten op jou — je agent heeft ze bij de sessiestart gemeld |
| niets | de plugin staat niet aan |

Twee dingen over dat commando. Het zoekt zijn eigen pad met een sterretje in plaats van een vast versienummer, want anders verdwijnt de badge stil bij de eerste plugin-update. En het draait daarna de ponytail-badge als die er is: Claude Code kent maar één `statusLine`, dus twee badges betekent twee commando's achter elkaar. Gebruik je ponytail niet, dan kun je dat tweede stuk weglaten.

De teller komt uit `~/.claude/.rmos-status`, dat de `PostToolUse`-hook schrijft uit het antwoord dat je agent tóch al ophaalde. Dus geen sleutel op schijf en geen netwerkcall in je statusbalk. Ouder dan twaalf uur en de teller vervalt: onbekend is geen nul.

## Uitzetten

`/plugin uninstall rmos@rmos`. Er blijft niets achter: de plugin schrijft niet buiten zijn eigen map.
