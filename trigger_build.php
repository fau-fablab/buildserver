<?php
// make the next run of `build_cron.sh check` do a build
touch("/home/buildserver/trigger/build_pending");
?>
