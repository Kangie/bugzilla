#!/bin/sh

chmod 0600 zzz.txt
sleep 20
git pull
perl checksetup.pl

# Needed for mod_perl
apache2ctl reload
