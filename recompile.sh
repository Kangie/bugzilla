#!/bin/sh

#chmod 0600 zzz.txt
#sleep 20
git pull && { perl checksetup.pl && apache2ctl graceful; }
