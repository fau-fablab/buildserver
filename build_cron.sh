#!/bin/bash

# quick hack: this script may be started as often as you like,
# it will launch a build process of none is running.
# use the `clean` option 

cd "$(dirname $0)"

LOCKFILE="state/build_running.lock"
CLEANUP_PENDING_FILE='trigger/cleanup_pending'
BUILD_PENDING_FILE="trigger/build_pending"
DONE_FILE='state/cleanup_done'
# changed when a run starts which only fetches the releases
RELEASE_CHECK_FILE='state/last-release-check'
# changed when a run has finished without any failed repo
LAST_SUCCESS_FILE='state/last-successful-run'
RELEASE_CHECK_INTERVAL_MINUTES=60

# to trigger
# touch BUILD_PENDING_FILE from some external commit hook

if [[ "$1" == "clean" ]]; then
	touch $CLEANUP_PENDING_FILE $BUILD_PENDING_FILE
elif [[ "$1" == "force" ]]; then
	touch $BUILD_PENDING_FILE
elif [[ "$1" == "force_queued" ]]; then
	touch $BUILD_PENDING_FILE
	exit 0
elif [[ "$1" != "check" ]]; then
	echo 'usage: build_cron.sh (force|clean|check)'
	echo "force: trigger a build and run it if no build is currently running"
	echo "force_queued: trigger a build, but do not run it -- call this from a webhook"
	echo "clean: like force, but with an extra 'make clean'"
	echo "check: run a build if it is triggered. Otherwise, fetch the releases if that was not done for one hour."
	exit 1
fi

# if no build was scheduled, only fetch the releases from time to time
# so that a lost trigger does not leave outdated files forever
target="all-repos"
if ! test $BUILD_PENDING_FILE -nt $DONE_FILE; then
	[[ -n "$(find $RELEASE_CHECK_FILE $LAST_SUCCESS_FILE -mmin -$RELEASE_CHECK_INTERVAL_MINUTES 2>/dev/null)" ]] && exit 0
	target="releases"
fi

# quit if another instance is already running
flock -n $LOCKFILE -c "true" || exit 0

[[ "$target" == "releases" ]] && touch $RELEASE_CHECK_FILE

# run "make clean" when it is pending
cleanup=""
[[ "$target" == "all-repos" ]] && test $CLEANUP_PENDING_FILE -nt $DONE_FILE && cleanup="clean"

# start buildserver with timeout
# map all build errors to return value 1 to separate them from a timeout
TIMEOUT_TIME=15m

# store the current time in the creation time of the tempfile
TEMPFILE=`mktemp` || exit 1
if [[ "$target" == "releases" ]]; then
	echo "starting regular fetch of releases"
else
	echo "starting triggered build $cleanup"
fi
timeout $TIMEOUT_TIME flock -n $LOCKFILE -c "./build.sh $target $cleanup || exit 1"
result=$?
[[ $result -ge 124 ]] && { echo "timed out" >&2; exit 1; }
if [[ "$target" == "releases" ]]; then
	rm "$TEMPFILE"
else
	mv "$TEMPFILE" "$DONE_FILE"
fi
[[ $result -eq 0 ]] && touch $LAST_SUCCESS_FILE
echo "finished successfully"
exit 0
