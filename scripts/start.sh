#!/bin/bash

set -ex

main() {
  local args=""
  local hostname="$(hostname)"

  if [ -z "$REPLICA_COUNT" ]; then
    args="$args --number='$REPLICA_COUNT'"
  else
    args="$args --number=1"
  fi

  if [ "$KEEP_DATA" == "true" ]; then
    args="$args --keep"
  fi

  local run_rs_cmd="run-rs $args --quiet --host='$hostname' --dbpath /data/db --bind_ip_all --mongod mongod"

  echo "Running: $run_rs_cmd"
  eval "$run_rs_cmd"
}

main
