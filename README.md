dotfiles
========

My personal git-hosted dotfiles. Contains a very handy dotfiles script that simplifies github synchronization. <br>
It also support git submodules.

Install:<br>
<code>bash -c "$(curl -fsSL https://raw.github.com/bjornhusberg/dotfiles/main/bin/dotfiles init)"</code>

Usage:<br>

<code>dotfiles status</code>
Check the dotfiles status and report to stdout.

<code>dotfiles pull</code>
Pull the latest dotfiles from the dotfiles repository.

<code>dotfiles push &lt;optional commit message&gt;</code>
Push the local dotfiles to the dotfiles repository.

<code>dotfiles diff</code>
Show the diff between the dotfiles repository and the local version.

<code>dotfiles add &lt;filename&gt;</code>
Add the named file to the dotfiles repository.

<code>dotfiles rm &lt;filename&gt;</code>
Remove the named file from the dotfiles repository.

