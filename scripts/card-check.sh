#!/bin/bash
# Behaviour checks for cue cards: real clicks, typing, clipboard, lifetimes, arrows. Run only on a
# disposable machine (the CI runner or the test Mac), never on a Mac somebody is working on.
# Usage: scripts/card-check.sh <bigarrow-binary> <out-dir>; exits non-zero when any check fails.
set -uo pipefail
BIN="$1"
OUT="$2"
mkdir -p "$OUT"
FAILED=0
limit() { perl -e 'alarm shift; exec @ARGV' "$@"; }
check() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; FAILED=1; fi; }
json() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); v=eval('d' + sys.argv[2]); print(json.dumps(v) if isinstance(v,(list,dict)) else v)" "$1" "$2"; }
# Centre of the control whose name contains $2, from a card's JSON output $1.
control() {
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); c=[c for c in d['controls'] if sys.argv[2] in c['name']][0]['rect']; print(int(c[0]+c[2]/2), int(c[1]+c[3]/2))" "$1" "$2"
}
press() { read -r X Y < <(control "$1" "$2"); "$KIT" click "$X" "$Y"; }
reply() { limit 40 "$BIN" wait "$1" > "$2"; echo $?; }
header() { python3 -c "import json,sys; c=json.load(open(sys.argv[1]))['card']; print(int(c[0]+c[2]/2), int(c[1]+8))" "$1"; }
windows() { "$KIT" windows "$1" | grep -c 'IsOnscreen=1'; }

swiftc -O scripts/testkit.swift -o "$OUT/testkit" || exit 1
KIT="$OUT/testkit"
trap '"$BIN" stop --all >/dev/null 2>&1' EXIT
FRONT=$("$KIT" frontmost)

# Showing a card and clicking its buttons never takes the focus; a copy keeps the card up.
printf 'before' | pbcopy
"$BIN" card --title "Franz, check this card" --field "User=franz" --button "later=Later" --button "ok=OK" > "$OUT/basic.json"
PID=$(json "$OUT/basic.json" "['pid']")
sleep 1
check "the card does not take the focus" "[ \"\$(\"$KIT\" frontmost)\" = \"$FRONT\" ]"
screencapture -x "$OUT/basic.png"
read -r X Y < <(header "$OUT/basic.json")
PIXEL=$("$KIT" pixel "$X" "$Y")
check "a card without secrets shows in screenshots (header $PIXEL)" "echo $PIXEL | awk '{exit !(\$1>200 && \$2<120)}'"
press "$OUT/basic.json" "Copy User"; sleep 0.5
check "copy puts the value on the clipboard ($(pbpaste))" "[ \"\$(pbpaste)\" = franz ]"
check "copy keeps the card" "kill -0 $PID 2>/dev/null"
press "$OUT/basic.json" "OK"
CODE=$(reply "$PID" "$OUT/basic-reply.json")
check "a button answers: exit 0, value ok, copied User ($(cat "$OUT/basic-reply.json"))" \
  "[ $CODE = 0 ] && [ \"\$(json $OUT/basic-reply.json \"['value']\")\" = ok ] && grep -q '\"User\"' $OUT/basic-reply.json"
check "clicking the card keeps the focus" "[ \"\$(\"$KIT\" frontmost)\" = \"$FRONT\" ]"

# The X closes without an answer.
"$BIN" card --title "Franz, close me" --note "Nothing to do" > "$OUT/close.json"
PID=$(json "$OUT/close.json" "['pid']"); sleep 1
press "$OUT/close.json" "Close"
CODE=$(reply "$PID" "$OUT/close-reply.json")
check "the X closes: exit 1, result closed" "[ $CODE = 1 ] && grep -q '\"closed\"' $OUT/close-reply.json"

# A question: click the field, type, Return; the human's app stays frontmost.
"$BIN" card --title "Franz, one question" --ask "Your name?" > "$OUT/ask.json"
PID=$(json "$OUT/ask.json" "['pid']"); sleep 1
press "$OUT/ask.json" "Your name?"; sleep 0.3
"$KIT" type "Arthur Ficial" --return
CODE=$(reply "$PID" "$OUT/ask-reply.json")
check "typing answers: input 'Arthur Ficial' ($(cat "$OUT/ask-reply.json"))" \
  "[ $CODE = 0 ] && [ \"\$(json $OUT/ask-reply.json \"['value']\")\" = 'Arthur Ficial' ]"
check "typing into the card keeps the human's app frontmost" "[ \"\$(\"$KIT\" frontmost)\" = \"$FRONT\" ]"

# A choice.
"$BIN" card --title "Franz, pick one" --choice "a=Alpha" --choice "b=Beta" > "$OUT/choice.json"
PID=$(json "$OUT/choice.json" "['pid']"); sleep 1
press "$OUT/choice.json" "Beta"
CODE=$(reply "$PID" "$OUT/choice-reply.json")
check "a choice answers with its id" "[ $CODE = 0 ] && [ \"\$(json $OUT/choice-reply.json \"['value']\")\" = b ]"

# A secret: never on the command line, hidden from screenshots, concealed on the clipboard,
# never in the reply, gone from the clipboard after 30 s.
export CARD_CHECK_SECRET="s3cret-$RANDOM-value"
"$BIN" card --title "Franz, the password" --secret "Password=env:CARD_CHECK_SECRET" --button "done=Done" > "$OUT/secret.json"
PID=$(json "$OUT/secret.json" "['pid']"); sleep 1
# The pattern's [s] keeps grep from finding itself.
check "the secret is not in any process's arguments" "! ps -axww -o args | grep -q \"[s]\${CARD_CHECK_SECRET#s}\""
check "the secret is not in the registry" "! grep -rq \"\$CARD_CHECK_SECRET\" \"\${TMPDIR:-/tmp}/bigarrow\""
read -r X Y < <(header "$OUT/secret.json")
screencapture -x "$OUT/secret.png"
PIXEL=$("$KIT" pixel "$X" "$Y")
check "a card with a secret stays out of screenshots ($PIXEL)" "echo $PIXEL | awk '{exit (\$1>200 && \$2<120)}'"
press "$OUT/secret.json" "Copy Password"; sleep 0.5
"$KIT" pasteboard > "$OUT/pasteboard.txt"
check "the copied secret is on the clipboard" "[ \"\$(pbpaste)\" = \"\$CARD_CHECK_SECRET\" ]"
check "it is marked concealed and transient" \
  "grep -q org.nspasteboard.ConcealedType $OUT/pasteboard.txt && grep -q org.nspasteboard.TransientType $OUT/pasteboard.txt"
press "$OUT/secret.json" "Done"
reply "$PID" "$OUT/secret-reply.json" > /dev/null
check "the reply holds no secret ($(cat "$OUT/secret-reply.json"))" "grep -q Password $OUT/secret-reply.json && ! grep -q \"\$CARD_CHECK_SECRET\" $OUT/secret-reply.json"
sleep 31
check "the clipboard forgets the secret after 30 s" "[ \"\$(pbpaste)\" != \"\$CARD_CHECK_SECRET\" ]"

# Lifetimes: time limit, stop --hook for the session, the owner process exiting.
"$BIN" card --title "Franz, short" --note "x" --duration 2 > "$OUT/timeout.json"
CODE=$(reply "$(json "$OUT/timeout.json" "['pid']")" "$OUT/timeout-reply.json")
check "a card ends by its time limit" "[ $CODE = 1 ] && grep -q '\"timeout\"' $OUT/timeout-reply.json"
BIGARROW_SESSION=card-check "$BIN" card --title "Franz, hook" --note "x" > "$OUT/hook.json"
echo '{"session_id":"card-check"}' | "$BIN" stop --hook
reply "$(json "$OUT/hook.json" "['pid']")" "$OUT/hook-reply.json" > /dev/null
check "stop --hook ends the session's card" "grep -q '\"stopped\"' $OUT/hook-reply.json"
sleep 3 & OWNER=$!
BIGARROW_OWNER_PID=$OWNER "$BIN" card --title "Franz, owner" --note "x" > "$OUT/owner.json"
reply "$(json "$OUT/owner.json" "['pid']")" "$OUT/owner-reply.json" > /dev/null
check "the card ends with its owner" "grep -q '\"ownerGone\"' $OUT/owner-reply.json"

# Arrow and card together: start --card is one process with two windows; a row's point shows
# an arrow from the card's process; card --update replaces the rows.
echo '{"title":"Franz, click the box","rows":[{"type":"actions","items":[{"id":"ok","label":"OK"}]}]}' > "$OUT/with-arrow.json"
"$BIN" start --at 500,500 --text "Here" --card "$OUT/with-arrow.json" --json > "$OUT/start.json"
PID=$(json "$OUT/start.json" "['pid']"); sleep 1
screencapture -x "$OUT/start-card.png"
check "start --card shows arrow and card from one process ($(windows "$PID"))" "[ \$(windows $PID) -ge 2 ]"
"$BIN" stop --pid "$PID" > /dev/null
reply "$PID" "$OUT/start-reply.json" > /dev/null
check "start --card leaves a reply for wait" "grep -q '\"stopped\"' $OUT/start-reply.json"
echo '{"title":"Franz, paste here","rows":[{"type":"field","label":"Code","value":"123","point":{"rect":"400,400,200,40"}}]}' > "$OUT/row.json"
"$BIN" card "$OUT/row.json" > "$OUT/row-out.json"
PID=$(json "$OUT/row-out.json" "['pid']"); sleep 1
screencapture -x "$OUT/row-arrow.png"
check "a row with a point shows its arrow ($(windows "$PID"))" "[ \$(windows $PID) -ge 2 ]"
echo '{"title":"Franz, updated","rows":[{"type":"progress","value":"Step 2 of 3","progress":0.66}]}' | "$BIN" card - --update "$PID" > /dev/null
sleep 1; screencapture -x "$OUT/updated.png"
check "update keeps the card alive" "kill -0 $PID 2>/dev/null"
check "a card updated to rows without a point drops the arrow ($(windows "$PID"))" "[ \$(windows $PID) -eq 1 ]"
"$BIN" stop --all > /dev/null

[ "$FAILED" = 0 ] && echo "ALL CARD CHECKS PASSED"
exit "$FAILED"
