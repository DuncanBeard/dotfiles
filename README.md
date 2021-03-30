# Dotfiles

## This repo has several directories to support multiple platforms

Directory | Purpose
--------- | -------
nix | Linux/UNIX platforms (or compatible)
windows | Windows platform

## Using this repo

First, fork this repo into a directory of your choice.

Then, add your dotfiles:

    $ git clone git@github.com:DuncanBeard/dotfiles.git .dotfiles
    $ cd .dotfiles
    $ nix/bootstrap.sh
    $ git push origin master

Finally, to install your dotfiles onto a new system:

    $ cd $HOME
    $ git clone git@github.com:DuncanBeard/dotfiles.git .dotfiles
    $ .dotfiles/nix/bootstrap.sh
