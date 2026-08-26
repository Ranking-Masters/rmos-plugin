# RMOS-plugin voor Claude Code

De Claude Code-plugin van [Ranking Masters](https://rankingmasters.nl) die het bedrijfsbrein laat meedraaien zonder dat iemand erom hoeft te vragen.

```
claude plugin marketplace add Ranking-Masters/rmos-plugin && claude plugin install rmos@rmos
```

**De gewone route is dit niet.** Deze plugin wordt via **claude.ai → Organization settings → Plugins** naar de hele organisatie gesynct, dus hij staat al in je `/plugin`-lijst en je hoeft hem alleen aan te zetten. Geen marketplace toevoegen, geen commando.

Bovenstaande regel is de terugvalroute voor wie de organisatie-uitrol nog niet heeft én toegang heeft tot deze (privé) repo. Doe je het binnen Claude Code met `/plugin`, geef de twee commando's dan **één voor één** — het eerste opent een venster, en een tweede regel belandt in dat invoerveld.

| Onderdeel | Wat het doet |
|---|---|
| `rmos/hooks/boot.sh` | Bij sessiestart in een rolmap: draagt de agent op om RMOS te vragen wat er veranderde, en om bij een nieuwe taak eerst te kijken wat er al bestaat. Zwijgt in een codebase. |
| `rmos/skills/rmos-nieuwe-taak` | Neemt het over zodra de bootinjectie is vervaagd: bij elke nieuwe taak eerst `rmos_start`. |
| `rmos/hooks/post-tool.sh` | Onthoudt uit een RMOS-antwoord hoeveel er op je wacht, en dat de connector antwoordde. |
| `rmos/hooks/post-tool-fail.sh` | Onthoudt dat een RMOS-call faalde, zodat een losse connector niet stil blijft. |
| `rmos/hooks/statusline.sh` | De badge in je statusbalk. |

## Wat deze plugin bewust níét doet

Hij haalt geen kennis op en kent geen sleutel. Er staat dus nooit een tweede, verouderde versie van bedrijfsafspraken op iemands laptop. De hook is een startschot; de inhoud komt uit de RMOS-MCP, die weet wie er belt en welke kennisversie die persoon het laatst zag.

Het enige wat hij wél opslaat is `~/.claude/.rmos-status`: één regel met een teller, een staat en twee tijdstempels, voor de badge. Geen sleutel, geen inhoud, geen klantdata. Weg is weg — dan toont de badge gewoon geen teller.

Zonder verbonden RMOS-connector doet deze plugin niets nuttigs. Verbinden: [os.rankingmasters.nl/agents](https://os.rankingmasters.nl/agents).

## Zelftest

`./test.sh` — geen framework, één bestand. Hij controleert de dragende tak (spreekt in een rolmap, zwijgt in een git-repo en in submappen daarvan), dat de tekst de agent daadwerkelijk naar `rmos_changes` en `rmos_start` stuurt, dat een falende of ontbrekende `git` de hook niet sloopt, en dat de manifesten geldige JSON zijn die naar bestaande scripts wijzen. Draait ook op elke push via GitHub Actions.

Voor de badge staan de leugens erin die hij niet mag vertellen: een teller verzinnen waar niets bekend is, een teller van dertien uur oud tonen, een storing van gisteravond tonen, een gefaalde `Bash`-call als connectorstoring lezen, een gewone tool de teller laten overschrijven, en blijven staan in een verweesde pluginmap.

Waarom: beide faalmodi van de hook zijn stil. Zwijgt hij overal, dan is de feature dood en merkt niemand het; praat hij in codebases, dan zet iemand de plugin uit. Voor de badge geldt hetzelfde: een badge die staat terwijl er niets draait, kost precies het vertrouwen dat hij moest opbouwen.

## De badge in je statusbalk

Zodat je ziet dát RMOS meedraait, of er iets op je wacht, en of de connector nog antwoordt. Eén regel in `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash -c 'for d in \"$HOME\"/.claude/plugins/cache/*/rmos/*/hooks/statusline.sh; do [ -f \"$d\" ] && [ ! -e \"${d%/hooks/statusline.sh}/.orphaned_at\" ] && s=\"$d\"; done; [ -n \"${s:-}\" ] && bash \"$s\"; for p in \"$HOME\"/.claude/plugins/cache/ponytail/ponytail/*/hooks/ponytail-statusline.sh; do [ -f \"$p\" ] && q=\"$p\"; done; [ -n \"${q:-}\" ] && { printf \" \"; bash \"$q\"; }'"
}
```

| Je ziet | Wat het betekent |
|---|---|
| `[RMOS]` groen | RMOS draait mee, niets dat op jou wacht |
| `[RMOS 3]` oranje | drie punten wachten op jou — je agent heeft ze bij de sessiestart gemeld |
| `[RMOS !]` rood | de laatste RMOS-call faalde: connector los of niet geautoriseerd. Verbinden: [os.rankingmasters.nl/agents](https://os.rankingmasters.nl/agents) |
| niets | de plugin staat niet aan |

### Waarom die regel niet in de plugin zelf zit

Dat zou logischer zijn, en het kan niet. Claude Code leest `statusLine` alleen uit `settings.json`; in `plugin.json` is het een onbekend veld dat bij het laden wordt genegeerd (`claude plugin validate` zegt dat ook zo), `StatusLine` bestaat niet als hook-event, en een plugin-`settings.json` mag alleen `agent` en `subagentStatusLine` zetten. Nagekeken op Claude Code 2.1.246; verandert dat, dan hoort deze regel te verhuizen.

Gevolg: de regel in `settings.json` is dom en het script is slim. Het script controleert zelf of het nog bij een levende plugin hoort en zwijgt anders. Dat is nodig omdat Claude Code de cachemap na een uninstall laat staan tot geen sessie hem meer vasthoudt — de badge bleef daardoor staan bij een plugin die niet meer geladen was, en een badge die liegt is erger dan geen badge. De glob slaat verweesde mappen over en het script kijkt er nog een tweede keer naar, want de meeste laptops lopen achter met die ene regel.

Verder zoekt de glob zijn pad met sterretjes in plaats van vaste namen — versie én marketplace, want bij de organisatie-uitrol heet die anders dan bij een handmatige installatie, en met een vast pad verdwijnt de badge stil. En hij draait daarna de ponytail-badge als die er is: Claude Code kent maar één `statusLine`, dus twee badges betekent twee commando's achter elkaar. Gebruik je ponytail niet, dan kun je dat tweede stuk weglaten.

De teller en de connectorstaat komen uit `~/.claude/.rmos-status`, dat de `PostToolUse`- en `PostToolUseFailure`-hooks schrijven uit een antwoord dat je agent tóch al ophaalde. Dus geen sleutel op schijf en geen netwerkcall in je statusbalk. Beide verlopen na twaalf uur, elk op hun eigen klok: een teller van gisteren is geen teller van vandaag, en een storing van gisteravond is geen storing van nu. Onbekend is geen nul.

## Uitzetten

`/plugin uninstall rmos@rmos` — de badge verdwijnt en er blijft één bestand achter, `~/.claude/.rmos-status`, met een teller en een tijdstempel. Geen sleutel, geen inhoud; verwijderen mag altijd.
