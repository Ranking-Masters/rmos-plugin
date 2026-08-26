"""Zoekt een persoonlijke RMOS-MCP in iemands Claude Code-config.

Waarom dit bestaat: wie RMOS destijds zelf toevoegde, heeft een server 'rmos'
in ~/.claude.json staan. Claude Code verbergt de connector van de organisatie
dan als duplicaat — "hidden — same URL as your server 'rmos'" — en dan heeft
diegene nul RMOS-tools. Precies de collega's die het eerst meededen zitten
daardoor stil zonder RMOS.

Grep op de URL kan niet: ~/.claude.json bewaart ook getypte prompts, dus wie
ooit "os.rankingmasters.nl" typte krijgt een valse melding. Daarom echt de
structuur in: alleen mcpServers, op gebruikers- en projectniveau.

Print één regel "<naam>\t<scope>" per vondst, of niets. Faalt hij, dan faalt hij
stil — dit is een diagnose, geen kernfunctie.
"""

import json, os, sys

HOST = "os.rankingmasters.nl"


def is_rmos(naam, cfg):
    if naam.lower() in ("rmos", "rmos-mcp", "bedrijfsbrein"):
        return True
    return HOST in json.dumps(cfg) if isinstance(cfg, (dict, list)) else False


def main():
    pad = os.path.join(os.path.expanduser("~"), ".claude.json")
    try:
        with open(pad, encoding="utf-8") as f:
            d = json.load(f)
    except Exception:
        return
    if not isinstance(d, dict):
        return

    gevonden = []
    for naam, cfg in (d.get("mcpServers") or {}).items():
        if is_rmos(naam, cfg):
            gevonden.append((naam, "gebruiker"))

    hier = os.getcwd()
    for pad_p, cfg_p in (d.get("projects") or {}).items():
        if not isinstance(cfg_p, dict) or pad_p != hier:
            continue
        for naam, cfg in (cfg_p.get("mcpServers") or {}).items():
            if is_rmos(naam, cfg):
                gevonden.append((naam, "dit project"))

    for naam, scope in gevonden:
        print(f"{naam}\t{scope}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        sys.exit(0)
