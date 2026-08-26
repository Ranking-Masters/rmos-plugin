#!/bin/bash
# Onthoudt dat een RMOS-call faalde, zodat de statusbalk het kan tonen.
#
# Waarom dit een eigen hook is: zonder verbonden connector doet deze plugin
# niets nuttigs, en dat was tot nu toe onzichtbaar. De agent kreeg een foutmelding
# en werkte door "zonder RMOS"; de badge bleef vrolijk groen. Precies de stille
# faalmodus die de badge had moeten wegnemen.
#
# Claude Code vuurt PostToolUse alleen na succes; een mislukte call komt hier
# binnen. Dus hoeven we niet te raden of iets een fout was.
set -uo pipefail

payload=""
IFS= read -r -d '' -t 2 payload || true
[ -n "$payload" ] || exit 0

# Gate op de toolnaam. Een falende Bash-call die het woord RMOS in zijn output
# heeft, is geen connectorstoring. Zonder tool_name weten we het niet, en dan
# zwijgen we: een verzonnen storing in de balk is erger dan een gemiste.
naam=$(printf '%s' "$payload" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1)
[ -n "$naam" ] || exit 0
case "$naam" in *RMOS*) ;; *) exit 0 ;; esac

stand="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rmos-status"
nu=$(date +%s)

# De teller blijft staan zoals hij was: die is gemeten toen het nog werkte, en
# dat feit wordt niet onwaar doordat een latere call faalt. Alleen de staat en
# zijn klok gaan om.
gezet=""; aantal=""
[ -f "$stand" ] && read -r gezet aantal _ _ < "$stand" 2>/dev/null || true
case "${gezet}${aantal}" in *[!0-9]*|"") gezet="0"; aantal="0" ;; esac

printf '%s %s fail %s\n' "$gezet" "$aantal" "$nu" > "$stand" 2>/dev/null
exit 0
