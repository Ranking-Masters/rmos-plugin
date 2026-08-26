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

Zodat je ziet dát RMOS meedraait, of er iets op je wacht, en of de connector nog antwoordt.

| Je ziet | Wat het betekent |
|---|---|
| `[RMOS]` groen | RMOS draait mee, niets dat op jou wacht |
| `[RMOS 3]` oranje | drie punten wachten op jou — je agent heeft ze bij de sessiestart gemeld |
| `[RMOS !]` rood | de laatste RMOS-call faalde: connector los of niet geautoriseerd. Verbinden: [os.rankingmasters.nl/agents](https://os.rankingmasters.nl/agents) |
| niets | de plugin staat niet aan |

De badge hoort niet in jouw persoonlijke config. Zeventien collega's die met de hand een bash-oneliner in hun `settings.json` plakken, is zeventien kansen op een typo en een badge die bij niemand hetzelfde doet. Hij hoort bij de uitrol.

### De route: organisatie (dit is de normale)

Eén blok in [**Admin Settings → Claude Code → Managed settings**](https://claude.ai/admin-settings/claude-code). Vereist de rol Owner of Primary Owner.

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash -c 'for d in \"$HOME\"/.claude/plugins/cache/*/rmos/*/hooks/statusline.sh; do [ -f \"$d\" ] && [ ! -e \"${d%/hooks/statusline.sh}/.orphaned_at\" ] && s=\"$d\"; done; [ -n \"${s:-}\" ] && bash \"$s\"'"
  }
}
```

Twee gevolgen die je vóór het opslaan moet weten, niet erna:

| | |
|---|---|
| **Het overschrijft elke persoonlijke `statusLine`** | Managed settings staan bovenaan de hiërarchie en mergen niet. Wie zelf een badge had — ponytail, een git-branch, een tokenteller — verliest die. Dat is de prijs van één uitrol voor iedereen. |
| **Iedereen krijgt één keer een goedkeuringsdialoog** | `statusLine` voert een shell-commando uit, dus Claude Code vraagt per gebruiker eenmalig toestemming. Wie weigert, bij wie sluit Claude Code af. |

### De route: persoonlijk (terugval)

Werk je buiten de organisatie, of wil je de badge naast je eigen statusbalk, dan zet je hetzelfde commando in `~/.claude/settings.json`. Claude Code kent maar één `statusLine`, dus twee badges betekent twee commando's achter elkaar:

```json
"statusLine": {
  "type": "command",
  "command": "bash -c 'for d in \"$HOME\"/.claude/plugins/cache/*/rmos/*/hooks/statusline.sh; do [ -f \"$d\" ] && [ ! -e \"${d%/hooks/statusline.sh}/.orphaned_at\" ] && s=\"$d\"; done; [ -n \"${s:-}\" ] && bash \"$s\"; for p in \"$HOME\"/.claude/plugins/cache/ponytail/ponytail/*/hooks/ponytail-statusline.sh; do [ -f \"$p\" ] && q=\"$p\"; done; [ -n \"${q:-}\" ] && { [ -n \"${s:-}\" ] && printf \" \"; bash \"$q\"; }'"
}
```

Bedenk wel dat je dan een andere balk hebt dan je collega's, en dat je de plugin dus niet meer test zoals zij hem krijgen.

### Waarom dit niet in de plugin zelf kan

Dat is de eerste vraag die iedereen hierover stelt, dus hier staat het antwoord in plaats van dat de volgende het opnieuw uitzoekt. Claude Code leest `statusLine` alleen uit een settingsbestand:

| Poging | Uitkomst |
|---|---|
| `statusLine` in `plugin.json` | `Unknown field 'statusLine'. Claude Code ignores it at load time.` |
| `StatusLine` als hook-event | `hooks.StatusLine: Invalid key in record` |
| Een `settings.json` in de plugin | alleen `agent` en `subagentStatusLine` worden gehonoreerd |

Nagekeken op Claude Code 2.1.246. Verandert dat, dan hoort de badge te verhuizen en mag dit stuk weg.

Gevolg: de settingsregel is dom en het script is slim. Het script controleert zélf of het nog bij een levende plugin hoort en zwijgt anders. Dat is nodig omdat Claude Code de cachemap na een uninstall laat staan tot geen sessie hem meer vasthoudt — de badge bleef daardoor staan bij een plugin die niet meer geladen was, en een badge die liegt is erger dan geen badge. De glob slaat verweesde mappen over en het script kijkt er nog een tweede keer naar, want laptops lopen achter met die ene regel.

De glob zoekt zijn pad met sterretjes in plaats van vaste namen — versie én marketplace — want bij de organisatie-uitrol heet de marketplace anders dan bij een handmatige installatie, en met een vast pad verdwijnt de badge stil.

De teller en de connectorstaat komen uit `~/.claude/.rmos-status`, dat de `PostToolUse`- en `PostToolUseFailure`-hooks schrijven uit een antwoord dat je agent tóch al ophaalde. Dus geen sleutel op schijf en geen netwerkcall in je statusbalk. Beide verlopen na twaalf uur, elk op hun eigen klok: een teller van gisteren is geen teller van vandaag, en een storing van gisteravond is geen storing van nu. Onbekend is geen nul.

## Landt de uitrol niet?

De organisatie-uitrol loopt via managed settings. Staat daar niets, dan komt er bij niemand een plugin binnen — ook niet als de marketplace onder **Libraries & Access → Plugins** netjes "Synced" en "Installed by default" toont. Dat zijn twee verschillende schakelaars, en dat is precies de valkuil: de ene ziet er groen uit terwijl de andere leeg is.

Zo zie je aan de clientkant wat er werkelijk binnenkomt:

```
claude -p ok --debug-file /tmp/cc.txt < /dev/null && grep -i "remote setting" /tmp/cc.txt
```

| Wat je leest | Wat het betekent |
|---|---|
| `No settings found (404)` | er staat niets in Managed settings. Niets landt, bij niemand |
| `Saved empty sentinel (404 response)` | de `{}` in `~/.claude/remote-settings.json` is een sentinel na die 404, geen leeg antwoord |
| een payload | de aflevering werkt; ontbreekt de plugin dan nog, dan missen de keys zelf |

Let bij het toevoegen van `extraKnownMarketplaces` op één ding: deze repo is privé. Verwijst de marketplace naar GitHub, dan moet elke client hem zelf klonen en heeft dus repo-toegang nodig. De org-sync spiegelt de bestanden aan de kant van claude.ai en heeft die toegang niet nodig — dat is de reden dat de repo privé staat, en die winst gooi je met een GitHub-verwijzing weg.

## Uitzetten

`/plugin uninstall rmos@rmos` — de badge verdwijnt en er blijft één bestand achter, `~/.claude/.rmos-status`, met een teller en een tijdstempel. Geen sleutel, geen inhoud; verwijderen mag altijd.
