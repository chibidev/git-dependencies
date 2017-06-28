git-dependencies
================

A git extension for managing dependencies that come from git repositories

#### Commands

* `add [url] [path] [ref]` add new git dependency
  * **url**: git repository url
  * **path**: where the dependency should be checked out
  * **ref**: which ref (branch) should be followed _(master, feature/sample)_
  ```bash
  git dependencies add https://example.com/hello.git dep/hello master
  ```


* `rm [path]` or `remove [path]` remove dependency
  * **path**: path of dependency
  ```bash
  git dependencies rm dep/hello master
  ```


* `update [path]` update dependencies
  * **path**: path of dependency. It is an optional parameter, its default value is ***** which means update every dependencies.
  ```bash
  git dependencies update
  ```


* `freeze [path]` freeze dependency to a specific commit on a specific branch (SHA1)
  * **path**: path of dependency. It is an optional parameter, its default value is ***** which means freeze every dependencies.
  ```bash
  git dependencies freeze dep/hello
  ```


* `unfreeze [path]` unfreeze dependency - follow a specific branch HEAD again
  * **path**: path of dependency. It is an optional parameter, its default value is ***** which means unfreeze every dependencies.
  ```bash
  git dependencies unfreeze dep/hello
  ```


* `dump` write current dependencies and its HEAD ref to stdout
  ```bash
  git dependencies dump
  ```


* `dump-deps` write current dependencies to stdout, in override file format. See arguments `--override` and `override-all`.
  ```bash
  # Dump the current dependency tree to an override file
  git dependencies dump-deps -r > snapshot
  # Restore the dependency tree from override file
  git dependencies update -r --overrides snapshot --override-all
  ```


* `foreach [command]` iterate over dependencies and run a specific command
  * **command**: git or shell command
  ```bash
  # it writes remote urls of dependencies to stdout
  git dependencies foreach "remote get-url origin"
  ```


* `set [path] [ref]` change followed ref (branch) of an existing dependency
  * **path**: path of dependency.
  * **ref**: which ref (branch) should be followed _(master, feature/sample)_
  ```bash
  git dependencies set dep/hello develop
  ```


* `set-command [command]` set a command for a dependency which will run after if that dependency has been updated.
  * **command**: git or shell command
  ```bash
  # run hello.py
  git dependencies set-command dep/hello "!sh python3 hello.py"
  # run git command
  git dependencies set-command dep/hello "rev-parse HEAD"
  ```

* `set-os-filter [types]` set OS filter for a dependency.
  * **types**: e.g. mac,win,ios,android
  ```bash
  git dependencies set-os-filter dep/hello mac,win
  ```

#### Other flags

* `-r` or `--recursive`: use it if you want to run command on dependencies of dependency
  * **commands** : `update`, `freeze`, `unfreeze`, `dump`, `foreach`


* `-d` or `--dump-header`: dump revision informations as preprocessor macros
  * **commands** : `dump`
  ```bash
  git dependencies dump  --dump-header
  # Output:
  # #define <sanitized path>_BRANCH "<branch>"
  # #define <sanitized path>_REMOTE "<remote branch>"
  # #define <sanitized path>_HASH "<sha1>"
  ```

* `--dump-custom [format]`: dump revision informations in a custom format
  * **command**: `dump`
  * **format**: _custom string with a following substitutions:_
    * %dependencyName% = current dependency name
    * %dependency% = current dependency path
    * %branch% = current branch
    * %remoteBranch% = current remote branch
    * %sha1% = current sha1
    * %sanitizedName% = current sanitized dependency name e.g. DEP
    * %sanitizedPath% = current sanitized dependency path e.g. DEPENDENCIES_DEP

    ```bash
    git dependencies dump  --dump-custom "%dependencyName% - %dependency% - %branch% - %remoteBranch% - %sha1% - %sanitizedName% - %sanitizedPath%"
    # Output: <dependencyName> - <dependency> - <branch> - <remoteBranch> - <sha1> - <sanitizedName> - <sanitizedPath>
    ```

* `-of` or `--os-filter`: filter dependencies by OS type. Default value is current OS type.
  * **commands** : `update`


* `-o` or `--override [filename]`: Override dependencies from the override file `filename`.
  * **commands** : `update`


* `-oa` or `--override-all`: Enforce complete override. Fail if a dependency is not overriden by the override file.
  * **commands** : `update --override`
