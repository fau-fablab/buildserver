#!/bin/bash

# quick hack: this script may be started as often as you like,
# it will launch a build process of none is running.
# use the `clean` option 

cd "$(dirname $0)"

LOCKFILE=".build_running.lock"
CLEANUP_PENDING_FILE='.cleanup_pending.lock'

if [[ "$1" == "clean" ]]; then
	touch $CLEANUP_PENDING_FILE
elif [ ! -z "$@" ]; then
	echo "usage: build_cron.sh [clean]"
	exit 1
fi

# quit if another instance is already running
flock -n $LOCKFILE -c "true" || exit 0

# run "make clean" when it is pending
cleanup=""
test -f $CLEANUP_PENDING_FILE && cleanup="clean"

# start buildserver with timeout
# map all build errors to return value 1 to separate them from a timeout
TIMEOUT_TIME=15m
timeout $TIMEOUT_TIME flock -n $LOCKFILE -c "./build.sh all-repos $cleanup || exit 1" \
 && rm -f "$CLEANUP_PENDING_FILE" 
[[ $? -ge 124 ]] && { echo "timed out" >&2; exit 1; }
exit 0