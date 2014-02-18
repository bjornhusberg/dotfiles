dotfiles
========

My personal git-hosted dotfiles. Contains a very handy dotfiles script that simplifies github synchronization. <br>
It also support git submodules.

Install:<br>
<code>sh -c "\`curl -fsSL https://raw.github.com/bjornhusberg/dotfiles/master/bin/dotfiles`"</code>

Usage:<br>
<code>dotfiles</code>
Silently check the dotfiles for local or remote changes and report to stdout.

<code>dotfiles pull</code>
Pull the latest dotfiles from the central github repository.

<code>dotfiles push &lt;optional commit message&gt;</code>
Push the local dotfiles to the central github repository.

<code>dotfiles diff</code>
Show the diff between the active dotfiles and the local repository.

<code>dotfiles add &lt;filename&gt;</code>
Add the named file to the local dotfiles repository.

<code>dotfiles rm &lt;filename&gt;</code>
Remove the named file from the local dotfiles repository.

<code>dotfiles checksum</code>
Calculate a new checksum for the local dotfiles repository.<br>
(Useful after manually modifying the local dotfiles repository and thus making it inconsistent)
