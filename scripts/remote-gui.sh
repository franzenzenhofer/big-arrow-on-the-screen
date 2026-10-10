#!/bin/bash
# Runs a command on a dedicated test Mac inside a Ghostty window, so it inherits Ghostty's
# Accessibility, PostEvent and Screen Recording permissions, waits for it, prints its output and
# exits with its code. Disruptive tests (drawing, clicks, raising apps, speech, virtual
# displays) run there, never on the Mac somebody is working on.
# BIGARROW_TEST_MAC is the SSH destination (a host alias from your ~/.ssh/config);
# BIGARROW_TEST_MAC_DIR is the checkout there (default ~/dev/big-arrow-on-the-screen).
# Usage: BIGARROW_TEST_MAC=<ssh-host> scripts/remote-gui.sh '<command>' [timeout-seconds]
set -euo pipefail
HOST="${BIGARROW_TEST_MAC:?set BIGARROW_TEST_MAC to the SSH host of your test Mac}"
DIR="${BIGARROW_TEST_MAC_DIR:-~/dev/big-arrow-on-the-screen}"
COMMAND="$1"
TIMEOUT="${2:-600}"
ID="bigarrow-$(date +%s)-$$"
ssh "$HOST" "mkdir -p /tmp/$ID && cat > /tmp/$ID/run.sh" <<SCRIPT
#!/bin/zsh -l
cd $DIR
(
$COMMAND
) > /tmp/$ID/out.log 2>&1
echo \$? > /tmp/$ID/exit
SCRIPT
ssh "$HOST" "chmod +x /tmp/$ID/run.sh && open -na Ghostty.app --args --quit-after-last-window-closed=true --command=/tmp/$ID/run.sh"
for _ in $(seq "$TIMEOUT"); do
  if ssh "$HOST" "test -f /tmp/$ID/exit"; then
    ssh "$HOST" "cat /tmp/$ID/out.log"
    exit "$(ssh "$HOST" "cat /tmp/$ID/exit")"
  fi
  sleep 1
done
echo "remote-gui: timed out after $TIMEOUT s; partial output:" >&2
ssh "$HOST" "cat /tmp/$ID/out.log" >&2
exit 124
