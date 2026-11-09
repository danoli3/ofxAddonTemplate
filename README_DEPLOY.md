MyAddon (rename to your addon's name)
=====================================

*This is a template of a README file for your addon. Fill in the relevant sections, and it should already give users a pretty good overview over your awesome addon!*
We chose the [Markdown format](http://daringfireball.net/projects/markdown/syntax) since it can present good formatting where available (e.g. on Github) while still staying human-readable with a plain text editor.
Don't forget, before announcing your addon to the world, you should replace `README.md` with this file and remove `README_AUTHOR.md`.

Introduction
------------
Describe what your addon is about

License
-------
State which license you offer your addon under. openFrameworks is distributed under the [MIT License](https://en.wikipedia.org/wiki/MIT_License), and you might consider using this for your repository. By default, `license.md` contains a copy of the MIT license to which you can add your name and the year.

Installation
------------
Drop the folder into `openFrameworks/addons/`. The template builds from its
bundled sources. If the addon author publishes prebuilt libraries, configure
`scripts/libs_common.sh` and fetch binaries for your platform:

    ./scripts/download_libs.sh            # auto-detects: osx, linux64, msys2, ...
    ./scripts/download_libs.sh ios        # a specific platform, or `all`

(On Windows run it from git-bash, or use `scripts\download_libs.cmd`.)
Download failures are reported as errors. For a source-only addon, skip the
download step. See `libs/README.md` for building and publishing binaries.

Dependencies
------------
What other addons are needed to properly work with this one?

Compatibility
------------
Which versions of OF does this addon work with?

Known issues
------------
Any specific (and long-living) issues/limitations you want to mention? For bugs, etc. you should use the issue tracker of your addon's repository

Version history
------------
It make sense to include a version history here (newest releases first), describing new features and changes to the addon. Use [git tags](http://learn.github.com/p/tagging.html) to mark release points in your repo, too!

### Version 0.1 (Date):
Describe relevant changes etc.


