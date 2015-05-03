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

 3. Add the repo direcotry to you `$PATH`. From inside this repository run:

```bash
export a="${PATH}:$(pwd)"
```
 4. Now you can `cd` inside a repository wich is registered to the buildserver and run

```bash
$> buildstatus
```

  to see information about the buildstatus in your terminal.

License
-------

Unilicense
