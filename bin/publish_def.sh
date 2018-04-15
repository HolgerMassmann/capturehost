#!/bin/bash

# Sends the passed message to the configured host and topic.
function publish() {
  local msg="$1"
  log "Executing ${pubcmd} ${pubopts} -m ${msg}"
  ${pubcmd} ${pubopts} -m "${msg}"
  ret=$?
  if [[ $ret -ne 0 ]]; then
    log "Could not publish message."
    return 2
  else
    log "Published message successfully."
  fi
}

