Buildserver
===========

This repo contains a bashscript building our pdf documents and a little python "client" for querying the buildstatus. And there are also some svg batches for the buildstatus.

Usage Server
------------

 1. Copy the [`config.cfg.example`](config.cfg.example) to `config.example`.

 1. "Register" the directory name of each repo to be build in the `$repo` variable in `config.cfg`.

 1. Run [`build.sh`](build.sh) in a cronjob.

```bash
# Usage:
# build all specified repos
./build.sh
# build only the 6th and later repos
./build.sh 6
```

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

### Tip:

 * Use [clustergit](https://github.com/sedrubal/clustergit) for batch processing.
If you moved everything concerning the 'Einweisungen' into a folder, you can run:

```bash
$> clustergit --exec "buildstatus" -e "(.*)(buildserver|fablab-document)"
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
