# RMOS-plugin voor Claude Code

De Claude Code-plugin van [Ranking Masters](https://rankingmasters.nl) die het bedrijfsbrein laat meedraaien zonder dat iemand erom hoeft te vragen.

```
claude plugin marketplace add Ranking-Masters/rmos-plugin && claude plugin install rmos@rmos
```

**De gewone route is dit niet.** Deze plugin wordt via **claude.ai → Organization settings → Plugins** naar de hele organisatie gesynct, dus hij staat al in je `/plugin`-lijst en je hoeft hem alleen aan te zetten. Geen marketplace toevoegen, geen commando.

Bovenstaande regel is de terugvalroute voor wie de organisatie-uitrol nog niet heeft **en** toegang tot deze repo. Die is namelijk privé, en dat moet: claude.ai laat bij *Sync from GitHub* alleen privé en interne repo's kiezen. Dat is geen probleem voor de gewone route — org-sync leest de repo via de Claude GitHub App en levert de plugin ingepakt aan je leden, dus daar zijn geen git-credentials bij betrokken. Krijg je op de terugvalroute een toegangsfout, dan is dat het antwoord: het hoort via de organisatie te komen. Doe je het binnen Claude Code met `/plugin`, geef de twee commando's dan **één voor één** — het eerste opent een venster, en een tweede regel belandt in dat invoerveld.

| Onderdeel | Wat het doet |
|---|---|
| `rmos/hooks/eigen-rmos.py` | Kijkt of er een eigen RMOS-server in `~/.claude.json` staat, want die verbergt de connector van de organisatie. |
| `rmos/hooks/boot.sh` | Bij elke sessiestart: draagt de agent op om RMOS te vragen wat er veranderde, en om bij een nieuwe taak eerst te kijken wat er al bestaat. In een git-repo komt er één alinea bij die de nadruk op dat tweede legt. |
| `rmos/skills/rmos-nieuwe-taak` | Neemt het over zodra de bootinjectie is vervaagd: bij elke nieuwe taak eerst `rmos_start`. |
| `rmos/hooks/post-tool.sh` | Onthoudt uit élk RMOS-antwoord hoeveel er op je wacht, en dat de connector antwoordde. |
| `rmos/hooks/post-tool-fail.sh` | Onthoudt dat een RMOS-call faalde, zodat een losse connector niet stil blijft. |
| `rmos/hooks/statusline.sh` | De badge in je statusbalk, klikbaar naar RMOS. |
| `rmos/hooks/refresh.sh` | Vraagt de agent de teller te verversen als die oud is. |

## Wat deze plugin bewust níét doet

Hij haalt geen kennis op en kent geen sleutel. Er staat dus nooit een tweede, verouderde versie van bedrijfsafspraken op iemands laptop. De hook is een startschot; de inhoud komt uit de RMOS-MCP, die weet wie er belt en welke kennisversie die persoon het laatst zag.

Het enige wat hij wél opslaat is `~/.claude/.rmos-status`: één regel met een teller, een staat en twee tijdstempels, voor de badge. Geen sleutel, geen inhoud, geen klantdata. Weg is weg — dan toont de badge gewoon geen teller.

Zonder verbonden RMOS-connector doet deze plugin niets nuttigs. Verbinden: [os.rankingmasters.nl/agents](https://os.rankingmasters.nl/agents).

## Zelftest

`./test.sh` — geen framework, één bestand. Hij controleert dat een eigen `rmos`-entry in `~/.claude.json` wordt opgemerkt mét het exacte herstelcommando, dat een URL in getypte historie géén valse melding geeft, dat een stukke of ontbrekende python3 de opdracht intact laat, dat de melding bij nul tools vóór de opdracht staat, dat de hook overal spreekt (rolmap, git-repo, submap van een repo, en ook wanneer `git` faalt of ontbreekt), dat de codebase-alinea alleen in een repo meekomt, dat `RMOS_BOOT=0` hem echt stil krijgt, dat de tekst de agent daadwerkelijk naar `rmos_changes` en `rmos_start` stuurt, en dat de manifesten geldige JSON zijn die naar bestaande scripts wijzen. Hij veegt eerst zijn eigen omgeving leeg, zodat een `RMOS_*` variabele in je shell geen valse uitslag kan geven. Draait ook op elke push via GitHub Actions.

Voor de badge staan de leugens erin die hij niet mag vertellen: een teller verzinnen waar niets bekend is, groen staan terwijl RMOS nog geen woord gezegd heeft, een teller van dertien uur oud tonen, een storing van gisteravond tonen, een gefaalde `Bash`-call als connectorstoring lezen, een gewone tool de teller laten overschrijven, en blijven staan in een verweesde pluginmap.

Waarom: elke faalmodus van deze plugin is stil. Dat is één keer echt misgegaan. `boot.sh` had een poort die hem in elke git-repo liet zwijgen — de gedachte was dat het gesprek daar over de code gaat en niet over iemands rol. Maar collega's zitten hun dag in repo's, dus stond de autonomie daar uit, en een hook die niets uitvoert ziet er precies zo uit als een hook die niets te melden heeft. Niemand kon het zien. De poort is weg: waar dit vuurt is niet de vraag, of de agent iets te zeggen heeft is de vraag, en dat beantwoordt `rmos_changes` zelf met één stille regel. Voor de badge gold dezelfde stilte: groen betekende ooit óók "nog nooit iets van RMOS gehoord".

## De badge in je statusbalk

Zodat je ziet dát RMOS meedraait, of er iets op je wacht, en of de connector nog antwoordt.

| Je ziet | Wat het betekent |
|---|---|
| `[RMOS ·]` dof | de plugin draait, maar er is geen actuele stand — meestal een connector die nog verbonden moet worden. Ook wat je ziet bij een teller van meer dan twaalf uur oud |
| `[RMOS]` groen | RMOS draait mee en heeft net geantwoord: niets dat op jou wacht |
| `[RMOS 3]` oranje | drie punten wachten op jou |
| `[RMOS !]` rood | de laatste RMOS-call faalde: connector los of niet geautoriseerd. Verbinden: [os.rankingmasters.nl/agents](https://os.rankingmasters.nl/agents) |
| niets | de plugin staat niet aan |

Eén regel voor de kleur: **dof betekent geen actuele stand, groen betekent actueel en stil.** Groen mag nooit "ik weet het niet" betekenen — dat was precies de leugen waar een collega met een onverbonden connector in liep.

**Cmd+klik op de badge opent RMOS** — bij een teller je inbox, bij een storing of een doffe badge de verbindpagina, en anders het bedrijfsbrein zelf. Zien dat er iets wacht en er dan zelf naar moeten zoeken kost meer aandacht dan de badge oplevert.

De badge hoort niet in jouw persoonlijke config. Zeventien collega's die met de hand een bash-oneliner in hun `settings.json` plakken, is zeventien kansen op een typo en een badge die bij niemand hetzelfde doet. Hij hoort bij de uitrol.

### De route: organisatie (dit is de normale)

Eén blok in [**Admin Settings → Claude Code → Managed settings**](https://claude.ai/admin-settings/claude-code). Vereist de rol Owner of Primary Owner.

```json
{
  "extraKnownMarketplaces": {
    "rmos": {
      "source": { "source": "github", "repo": "Ranking-Masters/rmos-plugin" }
    }
  },
  "enabledPlugins": { "rmos@rmos": true },
  "statusLine": {
    "type": "command",
    "command": "bash -c 'for d in \"$HOME\"/.claude/plugins/cache/*/rmos/*/hooks/statusline.sh; do [ -f \"$d\" ] && [ ! -e \"${d%/hooks/statusline.sh}/.orphaned_at\" ] && s=\"$d\"; done; [ -n \"${s:-}\" ] && bash \"$s\"'",
    "refreshInterval": 10
  }
}
```

`extraKnownMarketplaces` is niet optioneel: zonder die regel weet de client niet waar hij de plugin kan ophalen en zegt hij `Skipping orphaned enabledPlugins entry rmos@rmos: marketplace not registered`. De stand **Installed by default** op de Plugins-pagina regelt of de plugin *mag*, niet of de client hem kan *vinden*.

`refreshInterval` laat de balk elke tien seconden opnieuw draaien, náást de gebeurtenissen waar Claude Code zelf op ververst. Dat is nodig omdat de teller ook van buiten kan veranderen — een andere sessie die RMOS aanroept schrijft hetzelfde standbestand. Het is een bestandslees van een paar milliseconden, geen netwerkcall.

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

### Hoe live is de badge?

Zo live als het kan zonder een sleutel op zeventien laptops. Drie lagen, en het is nuttig te weten welke wat doet.

| Wat verandert | Hoe snel je het ziet |
|---|---|
| jouw agent spreekt RMOS | direct — de `PostToolUse`-hook schrijft de stand en Claude Code ververst de balk |
| een andere sessie van jou spreekt RMOS | binnen tien seconden, via `refreshInterval` — het standbestand is gedeeld |
| een collega dient iets in bij RMOS | bij je volgende bericht, zie hieronder |

Dat laatste is de eerlijke grens. De teller komt uit een RMOS-antwoord, en dat antwoord komt alleen als de agent RMOS aanroept. Dient een collega om 11:00 iets in, dan weet jouw balk dat om 15:00 nog niet.

Sinds de server onder elk antwoord één regel meestuurt — `RMOS-stand: N punten wachten op jou` — verjongt de teller bij elke RMOS-aanroep die je agent toch al doet. Vraag je tussendoor iets aan RMOS, dan loopt de balk daarmee mee zonder extra call. Blijft het langer stil, dan vraagt `refresh.sh` bij je volgende bericht één keer om een verversing zodra de teller ouder is dan tien minuten. Eén regel instructie, maximaal één keer per interval, overal waar je werkt — een teller verouderd in een repo net zo hard als daarbuiten. In de praktijk: je werkt, je typt, de teller loopt mee.

| Knop | Wat het doet |
|---|---|
| `RMOS_MAX_AGE` | seconden voordat de teller "oud" is (standaard 600) |
| `RMOS_REFRESH=0` | het verversen helemaal uit |
| `RMOS_URL` | andere basis-URL voor de links (standaard `https://os.rankingmasters.nl`) |
| `RMOS_BADGE_LINK=0` | de badge niet klikbaar maken |
| `RMOS_BOOT=0` | de bootcheck overslaan in deze shell — geen enkele RMOS-aanroep bij het opstarten |

**Waarom de balk niet zelf belt.** Dat zou echt live zijn, en het kost een sleutel. De RMOS-verbinding loopt via je claude.ai-token in de keychain; dat in een shellscript trekken zet een credential op elke laptop van het bureau, voor een getal in een balk. De agent ís de geauthenticeerde weg naar RMOS — deze hook geeft hem alleen een zetje.

**Wat een klik niet doet.** Fix je iets op os.rankingmasters.nl en kom je terug, dan wordt de badge groen bij je volgende bericht, niet terwijl je ernaar kijkt.

Echt live vraagt pushen in plaats van pollen, en daarvoor bestaat [Channels](https://code.claude.com/docs/en/channels-reference). Maar let op wat dat is: een channel is een **lokale** MCP-server die Claude Code als subprocess start over stdio. De RMOS-connector is een remote server en kan dus zelf geen channel zijn. Een channel voor RMOS zou een tweede, lokaal proces zijn dat op zijn eigen gezag bij RMOS aanklopt — en dan zijn we terug bij een credential op elke laptop, precies wat hier vermeden is. Bovendien staan eigen channels in de research preview niet op de allowlist: iedereen zou Claude Code met `--dangerously-load-development-channels` moeten starten. Zolang dat zo is, is dit geen route voor een team van zeventien.

**Klikbaar, maar niet overal.** OSC 8-hyperlinks werken in Warp, iTerm2, WezTerm, kitty, ghostty, VS Code, Windows Terminal en VTE-terminals. Terminal.app kent ze niet en zou de escape als rommel tonen, dus onbekende terminals krijgen een platte badge. `RMOS_BADGE_LINK=1` forceert, `0` zet het uit.

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
