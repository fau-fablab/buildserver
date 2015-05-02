#!/bin/bash
set -e
# Buildserver main script
# UNLICENSE
# author: max@fablab.fau.de

# TODO put this into git



# usage: build-with-submodule <name>
#
# updates git repo in ~/<name>, runs make, copies ~/<name>/output/*.* to ~/public_html/<name>/
function build-with-submodule() {
	cd ~
	INPUT_DIR="$HOME/$1/"
	OUTPUT_DIR="$HOME/public_html/$1/"
	pushd $INPUT_DIR > /dev/null
	# git fetch + reset instead of git pull so that force-pushes are fetched correctly
	git fetch > /dev/null
	git reset --hard origin > /dev/null
	git submodule update --init > /dev/null
	make > /dev/null
	mkdir -p $OUTPUT_DIR
	cd output
	cp ./*.* $OUTPUT_DIR
	popd  > /dev/null
}

# ATTENTION
# OPENERP pricelist is built by buildserver-openerp to separate permissions

# dummy doc
build-with-submodule document-dummy

# Drehbankeinweisung
build-with-submodule ./drehbank-einweisung/ ~/public_html/drehbank-einweisung


