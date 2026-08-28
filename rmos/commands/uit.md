---
description: Zet RMOS uit op deze machine — blijft uit tot /rmos:aan
allowed-tools: Bash(touch:*)
---

Maak het schakelbestand aan:

```
touch "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/rmos-off"
```

Meld daarna in één regel dat RMOS uit staat en dat dat zo blijft in elke map en
elke nieuwe sessie tot `/rmos:aan`. Gebruik vanaf nu geen `rmos_`-tools meer.

Vraagt iemand om alleen deze sessie: dat is `claude --rmos-off` of `RMOS_OFF=1`.
Noem dat niet uit jezelf — één knop tegelijk uitleggen is genoeg.

De MCP-tools blijven zichtbaar; die zet je per map uit met `/mcp`. Zeg dat er
alleen bij als iemand ernaar vraagt.
