# RMOS-plugin voor Claude Code

Zorgt dat het bedrijfsbrein meedraait zonder dat iemand erom hoeft te vragen.

| Onderdeel | Wat het doet |
|---|---|
| `hooks/boot.sh` | Bij sessiestart in een rolmap: draagt de agent op om RMOS te vragen wat er veranderde en om bij een nieuwe taak eerst te kijken wat er al bestaat. Zwijgt in een codebase. |
| `skills/rmos-nieuwe-taak` | Neemt het over zodra de bootinjectie is vervaagd: bij elke nieuwe taak eerst `rmos_start`. |

## Wat deze plugin bewust níét doet

Hij haalt geen kennis op, slaat niets op en kent geen sleutel. Er staat dus nooit een tweede, verouderde versie van de bedrijfsafspraken op iemands laptop. De hook is een startschot; de inhoud komt uit de MCP, die weet wie er belt en welke kennisversie die persoon het laatst zag.

Dat betekent ook: **zonder verbonden RMOS-connector doet deze plugin niets nuttigs.** Verbinden gaat via os.rankingmasters.nl/agents.

## Installeren

```
claude plugin marketplace add Ranking-Masters/rmos-plugin && claude plugin install rmos@rmos
```

Eén regel voor je terminal, dus in één keer te plakken. Doe je het binnen Claude Code met `/plugin`, geef de twee commando's dan **één voor één** — het eerste opent een venster, en een tweede regel belandt in dat invoerveld.

Daarna geldt het in elke map, ook in nieuwe. Updates komen vanzelf mee.

## Uitzetten

`/plugin uninstall rmos@rmos`. Er blijft niets achter: de plugin schrijft niet buiten zijn eigen map.
