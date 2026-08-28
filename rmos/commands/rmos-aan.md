---
description: Zet RMOS weer aan op deze machine
allowed-tools: Bash(rm -f:*)
---

Haal het schakelbestand weg:

```
rm -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/rmos-off"
```

Meld daarna in één regel dat RMOS weer aan staat vanaf de volgende sessie — deze
sessie heeft de bootcheck al gehad, dus daar verandert niets meer.

Staat `RMOS_OFF=1` nog in de shell of is er met `--rmos-off` gestart, dan blijft
RMOS in díé sessie uit, ook zonder het bestand. Controleer dat en zeg het erbij.
