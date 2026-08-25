---
name: rmos-nieuwe-taak
description: Gebruik dit zodra er een nieuwe taak, wens, klantvraag of verzoek ontstaat bij Ranking Masters — of iemand vraagt "hoe doen we dit ook alweer", "wat is onze werkwijze", "hebben we hier iets voor". Zoekt eerst in het bedrijfsbrein of er al een proces, template, tool of skill voor bestaat, vóór je zelf iets bedenkt.
---

# Eerst kijken of het al bestaat

Bij Ranking Masters is het duurste dat je kunt doen: opnieuw bedenken wat er al ligt. Er is een vastgelegde, gereviewde manier van werken — processen, templates, tools, skills, beleid — en die staat in RMOS. Iemand die iets zelf verzint, produceert een tweede versie van een afspraak, en binnen een maand is er één verkeerd.

## Wanneer

Zodra er iets nieuws ontstaat: een klantvraag, een intern verzoek, een taak op een bord, een "kunnen we niet even…". Ook wanneer iemand naar de werkwijze vraagt in plaats van naar het werk zelf.

**Niet** bij het voortzetten van werk waarvoor je deze sessie al `rmos_start` hebt aangeroepen. Eén briefing per taak volstaat.

## Stappen

1. **Roep `rmos_start` aan** met de taak in gewone taal, zoals de persoon hem stelde. Niet samengevat, niet vertaald naar jargon — RMOS zoekt op de echte formulering.
2. **Lees wat je terugkrijgt**: wat je moet weten, welke regels gelden, welke checks er vóór oplevering horen, welke resources er al zijn en welke documenten de bron zijn.
3. **Bestaat er al iets?** Gebruik dat, en zeg tegen de persoon wat je gebruikt en waar het vandaan komt (de `rmos://`-verwijzing). Niet: een eigen variant maken die er "beter op maat" uitziet.
4. **Bestaat er niets?** Zeg dat expliciet — "RMOS kent hier niets voor" is een bruikbaar antwoord en het markeert een gat. Doe het werk, en dien aan het eind met `rmos_propose` voor wat herbruikbaar is.
5. **Vóór oplevering**: `rmos_check`. Dat is geen mening over kwaliteit maar een toets tegen wat het bureau heeft afgesproken.

## Je bent klaar wanneer

Je hebt `rmos_start` aangeroepen voor déze taak, óf je hebt expliciet vastgesteld dat de taak geen enkel RMOS-proces, beleid of oplevering raakt — en dat gezegd. Twijfel je: bellen. Een briefing kost seconden, een verkeerd heruitgevonden proces kost een klant.

## Geen rmos_-tools beschikbaar?

Dan is de RMOS-connector niet verbonden in deze omgeving. Zeg dat één keer, verwijs naar os.rankingmasters.nl/agents, en werk verder — maar meld dan wel eerlijk dat je zonder de bedrijfsafspraken werkt.
