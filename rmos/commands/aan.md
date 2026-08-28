---
description: Zet RMOS weer aan op deze machine
allowed-tools: Bash(rm:*)
---

Haal het schakelbestand weg:

```
rm -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/rmos-off"
```

Meld daarna in één regel dat RMOS weer aan staat vanaf de volgende sessie — deze
sessie heeft de bootcheck al gehad, dus daar verandert niets meer.

Ga niet controleren of `RMOS_OFF` nog in de shell staat: die check wordt
geblokkeerd en kost alleen tijd. Noem hooguit dat wie met `--rmos-off` of
`RMOS_OFF=1` is gestart in díé sessie uit blijft.
