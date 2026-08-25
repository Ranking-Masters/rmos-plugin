# RMOS-plugin voor Claude Code

De Claude Code-plugin van [Ranking Masters](https://rankingmasters.nl) die het bedrijfsbrein laat meedraaien zonder dat iemand erom hoeft te vragen.

```
/plugin marketplace add Ranking-Masters/rmos-plugin
/plugin install rmos@rmos
```

| Onderdeel | Wat het doet |
|---|---|
| `rmos/hooks/boot.sh` | Bij sessiestart in een rolmap: draagt de agent op om RMOS te vragen wat er veranderde, en om bij een nieuwe taak eerst te kijken wat er al bestaat. Zwijgt in een codebase. |
| `rmos/skills/rmos-nieuwe-taak` | Neemt het over zodra de bootinjectie is vervaagd: bij elke nieuwe taak eerst `rmos_start`. |

## Wat deze plugin bewust níét doet

Hij haalt geen kennis op, slaat niets op en kent geen sleutel. Er staat dus nooit een tweede, verouderde versie van bedrijfsafspraken op iemands laptop. De hook is een startschot; de inhoud komt uit de RMOS-MCP, die weet wie er belt en welke kennisversie die persoon het laatst zag.

Zonder verbonden RMOS-connector doet deze plugin niets nuttigs. Verbinden: [os.rankingmasters.nl/agents](https://os.rankingmasters.nl/agents).

## Zelftest

`./test.sh` — geen framework, één bestand. Hij controleert de dragende tak (spreekt in een rolmap, zwijgt in een git-repo en in submappen daarvan), dat de tekst de agent daadwerkelijk naar `rmos_changes` en `rmos_start` stuurt, dat een falende of ontbrekende `git` de hook niet sloopt, en dat de manifesten geldige JSON zijn die naar een bestaande `boot.sh` wijzen. Draait ook op elke push via GitHub Actions.

Waarom: beide faalmodi van de hook zijn stil. Zwijgt hij overal, dan is de feature dood en merkt niemand het; praat hij in codebases, dan zet iemand de plugin uit.

## Uitzetten

`/plugin uninstall rmos@rmos` — er blijft niets achter, want de plugin schrijft niet buiten zijn eigen map.
