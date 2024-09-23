#!/bin/bash
set -e

die() {
  echo "$1" >&2
  exit 1
}

assert() {
  local message="$(cat)"
  local expected="$1"
  local actual="$2"

  if [ "$expected" != "$actual" ]; then
    echo "$message"
    die "Expected '$expected', but got '$actual'"
  fi
}

to_list() {
  cat | grep -oE '\w+'
}

test_to_list() {
  local list="$(echo -ne "foo\nbar\nbaz")"

  echo "Failed to convert to list" |
    assert "$list" "$(echo "foo,bar,baz" | to_list)"
}

to_pattern() {
  cat | to_list | tr '\n' '|' | sed 's/|$//'
}

test_to_pattern() {
  echo "Failed to convert to pattern" |
    assert "foo|bar|baz" "$(echo "foo bar baz" | to_pattern)"
}

omit() {
  local input="$(cat)"
  local pattern=$(echo "$@" | to_pattern)

  echo "$input" | grep -oE '\w+' | grep -Ev "$pattern" | xargs
}

test_omit() {
  echo "Failed to omit" |
    assert "foo baz" "$(echo "foo bar baz qux" | omit "bar qux")"
}

main() {
  local exit_code=1
  local should_exit=0

  if [ -z "$BACKUP_URI" ]; then
    echo "BACKUP_URI is required"
    echo "Maybe you forgot to set it in the environment, or you don't want to run a backup?"

    exit_code=0
    should_exit=1
  else
    echo "Backup URI: $BACKUP_URI"
  fi

  if [ -z "$RESTORE_URI" ]; then
    echo "RESTORE_URI is required"
    should_exit=1
  else
    echo "Restore URI: $RESTORE_URI"
  fi

  if [ $should_exit -eq 1 ]; then
    exit $exit_code
  fi

  local all_collections=""
  local arg_exclude_collections=""
  local tmp_backup="$(mktemp)"

  if [ -n "$INCLUDE_COLLECTIONS" ]; then
    echo "You're trying to include individual collections."
    echo "This is not supported by mongoimport/mongoexport."
    echo "The script will exclude all collections except the ones you've specified."
    echo
    echo "Included collections: $INCLUDE_COLLECTIONS"
    echo

    if [ -n "$EXCLUDE_COLLECTIONS" ]; then
      echo "You provided both INCLUDE_COLLECTIONS and EXCLUDE_COLLECTIONS."
      echo "EXCLUDE_COLLECTIONS will omit the collections you've specified in INCLUDE_COLLECTIONS."
      echo

      INCLUDE_COLLECTIONS="$(echo "$INCLUDE_COLLECTIONS" | omit "$EXCLUDE_COLLECTIONS")"

      echo "Included collections (modified): $INCLUDE_COLLECTIONS"
    else
      echo "Including collections: $INCLUDE_COLLECTIONS"
    fi

    echo

    local command="mongo '$BACKUP_URI' --quiet --eval 'db.getCollectionNames().join()'"
    local all_collections="$(eval "$command" | to_list)"

    echo "All collections:"
    echo "$all_collections"

    read -r arg_exclude_collections <<<"$(echo "$all_collections" | omit "$INCLUDE_COLLECTIONS")"
  elif [ -n "$EXCLUDE_COLLECTIONS" ]; then
    arg_exclude_collections="$EXCLUDE_COLLECTIONS"
  fi

  if [ -n "$arg_exclude_collections" ]; then
    echo "Excluding collections:"
    echo "$arg_exclude_collections" | xargs -d ' ' -I% echo ' - %'

    arg_exclude_collections="$(echo "$arg_exclude_collections" | xargs -d ' ' -I% echo -ne ' --excludeCollection=%')"
  fi

  if [ -n "$PARALLEL_COLLECTIONS" ]; then
    echo "Parallel collections: $PARALLEL_COLLECTIONS"
  else
    PARALLEL_COLLECTIONS="4"
  fi

  if [ -n "$INSERTION_WORKERS" ]; then
    echo "Insertion workers: $INSERTION_WORKERS"
  else
    INSERTION_WORKERS="4"
  fi

  local backup_file

  backup_file="$(find /backup -type f -name '*.gz' -mtime -3 -print0 | xargs -0 ls -lt | head -n1 | awk '{print $NF}')"

  if [ -n "$backup_file" ]; then
    echo "Found a backup file from the last 3 days: $backup_file"
    echo "Restoring from this file"
    echo
  else
    backup_file="/backup/$(date '+%Y%m%d%H%M%S').gz"
  fi

  # Perform an incremental backup
  local mongodump_cmd="
  mongodump \
    --archive="$backup_file" \
    --gzip \
    --numParallelCollections="$PARALLEL_COLLECTIONS" \
    --uri="$BACKUP_URI" \
    --verbose \
    $arg_exclude_collections"

  local mongorestore_cmd="
  mongorestore \
      --archive="$backup_file" \
      --gzip \
      --drop \
      --numInsertionWorkersPerCollection='$INSERTION_WORKERS' \
      --numParallelCollections='$PARALLEL_COLLECTIONS' \
      --stopOnError \
      --uri='$RESTORE_URI'"

  if [ -f "$backup_file" ]; then
    echo "Bakcup file already exists: $backup_file"
    echo "Skipping backup"
    echo
  else
    echo "Backing up..."
    echo "Running: $mongodump_cmd"
    echo

    time eval "$mongodump_cmd"

    echo "Backup completed"
    echo
  fi

  echo "Restoring..."
  echo "Running: $mongorestore_cmd"
  echo

  time eval "$mongorestore_cmd"

  echo "Restore completed"
  echo
}

test_to_list
test_to_pattern
test_omit

main
