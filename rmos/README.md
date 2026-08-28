# RMOS-plugin voor Claude Code

Zorgt dat het bedrijfsbrein meedraait zonder dat iemand erom hoeft te vragen.

| Onderdeel | Wat het doet |
|---|---|
| `hooks/boot.sh` | Bij sessiestart: draagt de agent op om RMOS te vragen wat er veranderde en om bij een nieuwe taak eerst te kijken wat er al bestaat. Vuurt overal — in een codebase verschuift alleen de nadruk naar dat tweede. |
| `skills/rmos-nieuwe-taak` | Neemt het over zodra de bootinjectie is vervaagd: bij elke nieuwe taak eerst `rmos_start`. |
| `hooks/statusline.sh` | Badge voor je statusbalk: draait RMOS mee, en wacht er iets op je. |
| `hooks/post-tool.sh` | Onthoudt de teller uit het antwoord van de boot-check. Slaat geen kennis en geen sleutel op. |
| `commands/uit.md` · `aan.md` | `/rmos:uit` en `/rmos:aan`: RMOS uit of aan op deze machine, blijvend. |

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
| `[RMOS uit]` dof | je hebt RMOS zelf uitgezet — `/rmos:aan` of start zonder `--rmos-off` |
| niets | de plugin staat niet aan |

Twee dingen over dat commando. Het zoekt zijn eigen pad met een sterretje in plaats van een vast versienummer, want anders verdwijnt de badge stil bij de eerste plugin-update. En het draait daarna de ponytail-badge als die er is: Claude Code kent maar één `statusLine`, dus twee badges betekent twee commando's achter elkaar. Gebruik je ponytail niet, dan kun je dat tweede stuk weglaten.

De teller komt uit `~/.claude/.rmos-status`, dat de `PostToolUse`-hook schrijft uit het antwoord dat je agent tóch al ophaalde. Dus geen sleutel op schijf en geen netwerkcall in je statusbalk. Ouder dan twaalf uur en de teller vervalt: onbekend is geen nul.

## Uitzetten

Drie knoppen, want het zijn drie verschillende wensen.

| Wat je wilt | Hoe |
|---|---|
| even privé werken, deze sessie | `claude --rmos-off` (zie hieronder) of `RMOS_OFF=1 claude` |
| voorgoed uit op deze machine | `/rmos:uit` — en `/rmos:aan` zet hem terug |
| helemaal weg | `/plugin uninstall rmos@rmos` |

Die laatste werkt alleen als je de plugin zelf hebt geïnstalleerd. Kwam hij via de organisatie-uitrol, dan weigert Claude Code met *"This plugin is managed by your organization"* — dat is de bedoeling van die laag, en precies waarom de eerste twee knoppen bestaan.

`--rmos-off` is geen echte vlag van Claude Code; onbekende opties geven een foutmelding. Deze regel in je `~/.zshrc` maakt hem er wel een:

```zsh
claude() {
  local -a rest
  local uit=
  for a in "$@"; do
    case "$a" in
      --rmos-off) uit=1 ;;
      *) rest+=("$a") ;;
    esac
  done
  RMOS_OFF="${uit:-}" command claude "${rest[@]}"
}
```

Alle vijf de scripts kijken naar `RMOS_OFF` en naar `~/.claude/rmos-off`, dus de bootcheck, het verversen, de teller en de badge gaan in één keer mee.

**Wat uitzetten níét doet: de MCP-tools weghalen.** Die komen van de RMOS-connector, niet van deze plugin. Ze blijven in de lijst staan, en daarom zwijgt `boot.sh` niet als RMOS uit staat maar zegt hij één regel: gebruik ze niet. Zonder die regel blijven de instructies van de connector zelf de agent naar `rmos_start` duwen — dan heet het uit en is het aan. Wil je ze echt weg, zet de connector er dan met `/mcp` bij uit; dat onthoudt Claude Code per map.

Er blijft niets achter: de plugin schrijft alleen `~/.claude/.rmos-status`, `~/.claude/.rmos-nudged` en — als je `/rmos:uit` gebruikt — `~/.claude/rmos-off`.
