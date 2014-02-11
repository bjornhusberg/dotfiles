dotfiles
========

My git-hosted dotfiles

Install:
<code>sh -c "\`curl -fsSL https://raw.github.com/bjornhusberg/dotfiles/master/bin/dotfiles`"</code>

My dotfiles script uses a sha-256 checksum seeded with a password to ensure the integrity of the central repository.
The active dotfiles are copied (not linked!) to/from a local clone of the github repository. The script
supports submodules.

Usage:
<code>dotfiles</code>
Silently check the dotfiles for local or remote changes and report to stdout.

<code>dotfiles pull</code>
Pull the latest dotfiles from the central github repository.

<code>dotfiles push</code>
Push the local dotfiles to the central github repository.

<code>dotfiles diff</code>
Show the diff between the active dotfiles and the local repository.

<code>dotfiles add &lt;filename&gt;</code>
Add the named file to the local dotfiles repository.

<code>dotfiles rm &lt;filename&gt;</code>
Remove the named file from the local dotfiles repository.

<code>dotfiles checksum</code>
Calculate a new checksum for the local dotfiles repository.
(Useful after manually modifying the local dotfiles repository)
