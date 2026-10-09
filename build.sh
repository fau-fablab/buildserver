#!/bin/bash
# Buildserver main script
# UNLICENSE
# author: max@fablab.fau.de basti.endres@fablab.fau.de

# ATTENTION
# OPENERP pricelist is built by buildserver-openerp to separate permissions

# The repos are not built here. Their output is fetched from the latest GitHub release.

# Exit on error
set -e

# default config
BUILDSERVER_DIR="$(readlink -f `dirname $0`)/"
REPOS_DIR="${BUILDSERVER_DIR}"
OUTPUT_DIR="${BUILDSERVER_DIR}/public_html/"
# older configs list some repos in repos_release, they are handled like repos
repos=()
repos_release=()
RELEASE_ASSET="output.tar.gz"

# Read repositories to build from config.cfg:
configfile='config.cfg'
source "$(dirname $0)/$configfile"

mkdir -p "${OUTPUT_DIR}"

# one index covers both lists
repos=("${repos[@]}" "${repos_release[@]}")

# count of repos to fetch
count=${#repos[@]}

# Parse the input arguments
if [[ -z "$1" || "$1" == "all-repos" ]]; then
    start=0
else
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]] ; then
        echo "[!] The first argument '${1}' is not a number." >&2
        echo "" >&2
        echo "Usage: build.sh (<number>|all-repos) [clean]" >&2
        echo "  <number>: the index of the first repo to fetch from the config, or 'all-repos' to fetch all repos"  >&2
        echo "  clean: additionally warn about output dirs which are no longer updated"  >&2
        echo "example: build.sh all-repos" >&2
        exit 1
    fi
    start=$1
fi

if [ ! -z $2 ] ; then
    if [ "$2" == "clean" ]; then
        clean="TRUE"
    else
        echo "[!] The second argument '${2}' should be 'clean' if you want to check for outdated output dirs after fetching" >&2; exit 1
    fi
fi

# usage: fetch-release <name>
#
# downloads the asset $RELEASE_ASSET of the latest release of <name> and copies its content to ~/public_html/<name>/
# The output dir is only touched after download and extraction succeeded, so a failure keeps the old files.
function fetch-release() {
    CUR_REPO=$1
    update-status "${CUR_REPO}" "pending"
    CUR_OUTPUT_DIR="${OUTPUT_DIR}/${CUR_REPO}/"
    DOWNLOAD_DIR="${REPOS_DIR}/.release-download/"
    rm -rf "${DOWNLOAD_DIR}"
    mkdir -p "${DOWNLOAD_DIR}/output"
    curl --silent --show-error --fail --location --max-time 120 \
        -o "${DOWNLOAD_DIR}/${RELEASE_ASSET}" \
        "${REPO_URL_PREFIX}${CUR_REPO}/releases/latest/download/${RELEASE_ASSET}"
    tar --extract --gzip --no-same-owner --file "${DOWNLOAD_DIR}/${RELEASE_ASSET}" --directory "${DOWNLOAD_DIR}/output"
    # bring it to the output dir
    mkdir -p "${CUR_OUTPUT_DIR}"
    rsync --delete --recursive "${DOWNLOAD_DIR}/output/" "${CUR_OUTPUT_DIR}"
    touch "${CUR_OUTPUT_DIR}" # change last modified for easily check for old repo outputs
    update-status "${CUR_REPO}" "success"
    rm -rf "${DOWNLOAD_DIR}"
}

# If the exit value of the script > 0 then the current $repo build seems to be failed (set -e causes this)
function handle-exit() {
    if (( $? > 0 )) ; then
        echo "[!] Fetching repository '${repo}' failed!" 1>&2
        update-status "${repo}" "failed"
        current_repo_index=$((current_repo_index+1))
        # run this script recursively, but start with next index
        cd "${BUILDSERVER_DIR}"
        "${BUILDSERVER_DIR}build.sh" "${current_repo_index}"
        exit 1
    else
        # no error -> exit normally
        exit 0
    fi
}

# usage: update-status <repo> <pending|success|failed|unknown>
#
# updates the status.svg and the status.json of the repo
function update-status() {
    STATUS_OUT_DIR="${OUTPUT_DIR}/$1/"
    mkdir -p "${STATUS_OUT_DIR}"
    if [[ "${2}" == "failed" ]]; then
        COLOR="red"
    elif [[ "${2}" == "pending" ]]; then
        COLOR="yellow"
    elif [[ "${2}" == "success" ]]; then
        COLOR="green"
    elif [[ "${2}" == "unknown" ]]; then
        COLOR="gray"
    else
        echo "Invalid status ${2}" 1>&2
        exit 1
    fi
    curl --silent -o "${STATUS_OUT_DIR}status.svg" "https://img.shields.io/badge/build-${2}-${COLOR}.svg"
    echo "{ \"status\": \"${2}\", \"updated\": \"$(date +%s)\", \"updated-human\": \"$(date)\" }" > "${STATUS_OUT_DIR}status.json"
}

# usage: run <start_index>
#
# fetches each repo given in $repos and $repos_release
function run() {
    for (( current_repo_index=$1; current_repo_index<$count; current_repo_index++ )) ; do
        repo="${repos[${current_repo_index}]}"
        fetch-release $repo
    done
}

# usage: clean_output
#
# looks at every directory in $OUTPUT_DIR and warns if it is older than one week
# note: the ctime of a directory does not necessarily change when updating its contents.
# therefore, we touch each output dir during build.
function clean_output() {
    cd $OUTPUT_DIR
    for d in `find * -maxdepth 0 -type d`; do
        date="$(stat -c %Y "$d")" # get dirs last data modification time as timestamp
        limit="$(date -d "-1 week" +%s)" # get limit timestamp (one week before)
        tdiff="$(( $date - $limit ))" # calculate the difference, if this is >0 everything is ok
        if (( $tdiff < 0 )); then
            echo "[i] output '${d}' was not updated for one week. Maybe you want to remove it because it is no longer in the configuration?"
	    # Do not remove it because in some cases this behaviour is not wanted (e.g. cooperation with other buildscripts writing to the same folder)
            #if [[ "$(id -u)" == "$(stat -c %u ${d})" || "$(id -g)" == "$(stat -c %g w)" ]]; then
            #    rm -rf "${d}"
            #else
            #    echo "[!] Well, I can't delete it. I'm not allowed to"
            #fi
        fi
    done
}

# execute function handle-exit on exit
trap handle-exit EXIT

# run and begin by $start repo
run $start

# clean old output dirs
if [[ ! -z $clean && "$clean" == "TRUE" ]] ; then clean_output; fi

# everything was successfull
exit 0
