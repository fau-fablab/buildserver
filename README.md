Buildserver
===========

A bashscript building our pdf documents.

Usage
-----

Run [`build.sh`](build.sh) in a cronjob.

"Register" the directory name of each repo to be build in the `$repo` variable in [`build.sh`](build.sh).

```bash
# Usage:
# build all specified repos
./build.sh
# build only the 6th and later repos
./build.sh 6
```

License
-------

Unilicense
