#!/bin/bash
trap 'echo Feierabend' SIGKILL SIGINT SIGTERM
( while true; do
	/home/buildserver/build_cron.sh check || sleep 60
	sleep 20
done ) &
wait