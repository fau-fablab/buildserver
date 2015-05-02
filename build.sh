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

# Repositories to build:
repos=("document-dummy" "fraese-einweisung" "reflow-ofen-einweisung" "buttonpresse-einweisung" "betreuer-einweisung" "werkstatt-einweisung" "fraese-imodela-einweisung" "platinenaetzer-einweisung" "drehbank-einweisung" "lasercutter-einweisung" "3d-drucker-einweisung" "schneideplotter-einweisung" "oerp-einweisung")


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
	git fetch > /dev/null
	commit_id=$(git log --pretty=format:"%h" --abbrev-commit --date=short -1)
	git reset --hard origin > /dev/null
	git submodule update --init > /dev/null
	make > /dev/null
	mkdir -p $OUTPUT_DIR
	cd output
	cp ./*.* $OUTPUT_DIR
	update-status $1 success $commit_id
	popd  > /dev/null
	commit_id=""
}

# If the exit value of the script > 0 then the current $repo build seems to be failed (set -e causes this)
function handle-exit() {
	if (( $? > 0 )) ; then
        	echo "[!] Build repository '${repo}' failed!" 1>&2
		update-status $repo failed $commit_id
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
	cp "${STATUS_DIR}build-${2}.svg" "${STATUS_OUT_DIR}status.svg"
	if [[ -z "$commit_id" || "$commit_id" == "" ]]; then
	    commit_info=""
	else
	    commit_info=", \"commit\": \"${commit_id}\""
	fi
	echo "{ \"status\": \"${2}\", \"updated\": \"$(date +%s)\", \"updated-human\": \"$(date)\"${commit_info} }" > "${STATUS_OUT_DIR}status.json"
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
