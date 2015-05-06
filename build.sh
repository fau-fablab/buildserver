#!/bin/bash
# Buildserver main script
# UNLICENSE
# author: max@fablab.fau.de basti.endres@fablab.fau.de

# ATTENTION
# OPENERP pricelist is built by buildserver-openerp to separate permissions

# Exit on error
set -e
# execute function handle-exit on exit
trap handle-exit EXIT

# Read repositories to build from config.cfg:
configfile='config.cfg'
source "$(dirname $0)/$configfile"

# count of repos to build
count=${#repos[@]}
# if an argument is given, then start building with this index 
if [ -z "$1" ]; then
    start=0
else
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]] ; then
        echo "[!] Argument '${1}' is not a number" >&2; exit 1
    fi
    start=$1
fi

# usage: build-with-submodule <name>
#
# updates git repo in ~/<name>, runs make, copies ~/<name>/output/*.* to ~/public_html/<name>/
function build-with-submodule() {
    cd ~
    update-status $1 pending
    INPUT_DIR="$HOME/$1/"
    OUTPUT_DIR="$HOME/public_html/$1/"
    pushd $INPUT_DIR > /dev/null
    # git fetch + reset instead of git pull so that force-pushes are fetched correctly
    fetch_output=$(git fetch)
    git reset --hard origin > /dev/null
    git submodule update --init > /dev/null
    commit_id=$(git log --pretty=format:"%h" --abbrev-commit --date=short -1)
    commit_author=$(git log --pretty=format:"%an" --abbrev-commit --date=short -1)
    todos=0
    while IFS= read -r -d '' f; do   todos=$(($todos+$(grep -wc -i "todo" "$f" &2> /dev/null))); done < <(find . -maxdepth 1 -type f -name "*.tex" -print0)
    while IFS= read -r -d '' f; do   todos=$(($todos+$(grep -wc -i "todo" "$f" &2> /dev/null))); done < <(find . -maxdepth 1 -type f -name "*.md" -print0)
    make > /dev/null
    mkdir -p $OUTPUT_DIR
    cd output
    cp ./*.* $OUTPUT_DIR
    update-status $1 success
    popd  > /dev/null
    commit_id=""
    todos=""
    if [ ! -z $fetch_output ] ; then
        echo "Author of this commit is ${commit_author}"
    fi
}

# If the exit value of the script > 0 then the current $repo build seems to be failed (set -e causes this)
function handle-exit() {
    if (( $? > 0 )) ; then
        echo "[!] Build repository '${repo}' failed! Author: ${commit_author}" 1>&2
        update-status $repo failed
        current_repo_index=$((current_repo_index+1))
        # run this script recursively, but start with next index
        $0 $current_repo_index
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
    mkdir -p "$HOME/public_html/$1"
    STATUS_OUT_DIR="$HOME/public_html/$1/"
    STATUS_DIR="$HOME/status-icons/"
    TODOS_SVG_TEMPLATE="${STATUS_DIR}todos.svg.template"
    cp "${STATUS_DIR}build-${2}.svg" "${STATUS_OUT_DIR}status.svg"
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
        fg_color=("#323232" "#323232" "#646464")
        bg_color=("#149123" "#b6ba19" "#911414")
        index=0
        if (( $todos > 5 )) ; then
            index=1
        elif (( $todos > 20 )) ; then
            index=2
        fi
        sed "s/\$todos/$todos/g" $TODOS_SVG_TEMPLATE | sed "s/\$fg_color/${fg_color[${index}]}/g" - | sed "s/\$bg_color/${bg_color[${index}]}/g" - > "${STATUS_OUT_DIR}status-todos.svg"
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


# run and begin by $start repo
run $start

exit 0
