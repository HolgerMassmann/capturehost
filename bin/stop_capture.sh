#!/bin/bash

capture_pid=$(pgrep raspistill)
if [[ $? -ne 0 ]]; then
  echo "No capture process running."
  exit 0
fi

kill ${capture_pid}
if [[ $? -eq 0 ]]; then
  echo "Terminated capture process."
else
  echo "Could not terminate process with pid=${capture_pid}"
fi
