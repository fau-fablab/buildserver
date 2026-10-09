Buildserver
===========

This repo contains a bashscript fetching our pdf documents from GitHub releases and a little python "client" for querying the buildstatus. And there are also some svg batches for the buildstatus.

Usage Server
------------

 1. Copy the [`config.cfg.example`](config.cfg.example) to `config.example`.

 1. "Register" the name of each repo to be fetched in the `$repos` variable in `config.cfg`.

 1. Run [`build_cron.sh check`](build_cron.sh) in a cronjob as often as you like - it will return if the last build is still running. It runs a build if one was triggered or if the last one is older than one hour, so that a lost trigger does not leave outdated files forever.
 
 1. from time to time, run `build_cron.sh clean` to trigger a complete fetch and a warning for output dirs which are no longer updated. `build_cron.sh force` does the same without the warning.
 
 1. setup a webhook to `trigger_build.php`. Enable it for the event "release": the output of a repo changes when its GitHub Action has finished and created the release.

 1. for monitoring, check the modification time of `state/last-successful-run`. It is touched after each run which did not time out. Failures of single repos are only visible in their `status.json`.

Fetching releases
-----------------

The buildserver does not build anything. For each repo in `$repos`, the file `output.tar.gz` is downloaded from the latest GitHub release of the repo (`<REPO_URL_PREFIX><repo>/releases/latest/download/output.tar.gz`) and its content is published like the `output/` directory of a built repo. If the download fails, the previously published files are kept.

The release is created by a GitHub Action in the repo itself (see `pdf.yml` in [document-dummy](https://github.com/fau-fablab/document-dummy)). `$repos_release` is still accepted and handled like `$repos`.

```bash
# Usage:
# fetch all specified repos
./build.sh
# fetch only the 6th and later repos
./build.sh 6
```

Repository setup
----------------

Create your repositories this way:

* Makefile in the top directory, which copies all public output to the output/ subdirectory
* a GitHub Action which runs it on each push and attaches the output/ directory as `output.tar.gz` to a release

Add the repository to the configuration. The output can then be found under `http://my-buildserver/repository/`

examples:

* https://github.com/fau-fablab/document-dummy is a working repository
* https://github.com/fau-fablab/fablab-document/blob/master/README_deployment.md explains setting up the FAU FabLab LaTeX template

Usage Client:
-------------

 1. Copy the [`config.cfg.example`](config.cfg.example) to `config.example`.

 2. Adapt the buildserver url in `config.cfg`

 3. Add the repo direcotry to you `$PATH`
    For example symlink the script (and the config) into `$HOME/bin` and add this to your `.bashrc`:

```bash
if [ -d $HOME/bin ] ; then
    export PATH="${PATH}:$HOME/bin"
fi
```
 4. Now you can `cd` inside a repository wich is registered to the buildserver and run

```bash
$> buildstatus
```

  to see information about the buildstatus in your terminal.

 5. Add option `-c` to run checks for the current repo.

### Tip:

 * Use [clustergit](https://github.com/sedrubal/clustergit) for batch processing.
If you moved everything concerning the 'Einweisungen' into a folder, you can run:

```bash
$> clustergit --exec "buildstatus -c" -e "(.*)(buildserver|fablab-document)"
```

 * You can also use the `ssh-agent` for keeping you ssh key unlocked for $time.
Run:

```bash
$> ssh-add -t 600s
```

  To keep your ssh key unlocked for 600s. To temporary lock and unlock the `ssh-agent` run:

```bash
# lock:
$> ssh-add -x
Enter lock password:
Again:
Agent locked.
# unlock:
$> ssh-add -X
Enter lock password:
Agent unlocked.
```

License
-------

Unilicense
