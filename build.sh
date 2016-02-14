#!/bin/bash
# Buildserver main script
# UNLICENSE
# author: max@fablab.fau.de basti.endres@fablab.fau.de

# ATTENTION
# OPENERP pricelist is built by buildserver-openerp to separate permissions

# Exit on error
set -e

# default config
BUILDSERVER_DIR="$(readlink -f `dirname $0`)/"
REPOS_DIR="${BUILDSERVER_DIR}"
OUTPUT_DIR="${BUILDSERVER_DIR}/public_html/"

# Read repositories to build from config.cfg:
configfile='config.cfg'
source "$(dirname $0)/$configfile"

# count of repos to build
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
        echo "  <number>: the index of the first repo to build from the config, or 'all-repos' to build all repos"  >&2
        echo "  clean: additionally execute make clean, rebuild everything"  >&2
        echo "example: build.sh all-repos" >&2
        exit 1
    fi
    start=$1
fi

if [ ! -z $2 ] ; then
    if [ "$2" == "clean" ]; then
        clean="TRUE"
    else
        echo "[!] The second argument '${2}' should be 'clean' if you want to run a make clean before building" >&2; exit 1
    fi
fi

# usage: build-with-submodule <name>
#
# updates git repo in ~/<name>, runs make, copies ~/<name>/output/*.* to ~/public_html/<name>/
function build-with-submodule() {
    CUR_REPO=$1
    cd "${REPOS_DIR}"
    update-status "${CUR_REPO}" "pending"
    INPUT_DIR="${REPOS_DIR}${CUR_REPO}/"
    CUR_OUTPUT_DIR="${OUTPUT_DIR}${CUR_REPO}/"
    test -d $INPUT_DIR || git clone "${REPO_URL_PREFIX}${CUR_REPO}${REPO_URL_SUFFIX}"
    pushd $INPUT_DIR > /dev/null
    # git fetch + reset instead of git pull so that force-pushes are fetched correctly
    fetch_output=$(git fetch)
    git reset --hard origin > /dev/null
    git submodule update --init > /dev/null
    # collect some infos (for status)
    commit_id=$(git log --pretty=format:"%h" --abbrev-commit --date=short -1)
    commit_author=$(git log --pretty=format:"%an" --abbrev-commit --date=short -1)
    todos=0
    while IFS= read -r -d '' f; do   todos=$(($todos+$(grep -wc -i "todo" "$f" &2> /dev/null))); done < <(find . -maxdepth 1 -type f -name "*.tex" -print0)
    while IFS= read -r -d '' f; do   todos=$(($todos+$(grep -wc -i "todo" "$f" &2> /dev/null))); done < <(find . -maxdepth 1 -type f -name "*.md" -print0)
    # build
    if [[ ! -z $clean && "$clean" == "TRUE" ]] ; then make clean > /dev/null ; fi # clean, when second argument is "clean"
    make > /dev/null
    # bring it to the output dir
    mkdir -p $CUR_OUTPUT_DIR
    cd output
    rsync --delete --recursive . $CUR_OUTPUT_DIR
    touch "${CUR_OUTPUT_DIR}" # change last modified for easily check for old repo outputs
    update-status "${CUR_REPO}" "success"
    popd  > /dev/null
    commit_id=""
    todos=""
    if [ ! -z "$fetch_output" ] ; then
        echo "Author of this commit is ${commit_author}"
    fi
}

# If the exit value of the script > 0 then the current $repo build seems to be failed (set -e causes this)
function handle-exit() {
    if (( $? > 0 )) ; then
        echo "[!] Build repository '${repo}' failed! Author: ${commit_author}" 1>&2
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
    STATUS_OUT_DIR="${OUTPUT_DIR}$1/"
    mkdir -p "$STATUS_OUT_DIR"
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
    wget -q -O "${STATUS_OUT_DIR}status.svg" "https://img.shields.io/badge/build-${2}-${COLOR}.svg"
    if [[ -z "$commit_id" || "$commit_id" == "" ]]; then
        commit_info=""
    else
        commit_info=", \"commit\": \"${commit_id}\""
    fi
    if [[ -z "$commit_author" || "$commit_author" == "" ]]; then
        commit_author_info=""
    else
        commit_author_info=", \"author\": \"${commit_author}\""
    fi
    if [[ -z "$todos" || "$todos" == "" ]]; then
        todos_info=""
    else
        todos_info=", \"todos\": \"${todos}\""
        colors=("green" "yellow" "red")
        index=0
        if (( $todos > 5 )) ; then
            index=1
        elif (( $todos > 20 )) ; then
            index=2
        fi
        wget -q -O "${STATUS_OUT_DIR}status-todos.svg" "https://img.shields.io/badge/todos-${todos}-${colors[${index}]}.svg"
    fi
    echo "{ \"status\": \"${2}\", \"updated\": \"$(date +%s)\", \"updated-human\": \"$(date)\"${commit_info}${commit_author_info}${todos_info} }" > "${STATUS_OUT_DIR}status.json"
}

# usage: run <start_index>
#
# runs through each repo given in $repos
function run() {
    for (( current_repo_index=$1; current_repo_index<$count; current_repo_index++ )) ; do
        repo="${repos[${current_repo_index}]}"
        # echo "[i] building repo ${repo}"
        build-with-submodule $repo
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
