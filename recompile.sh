#!/bin/sh

chmod 0600 zzz.txt
sleep 20
git pull
perl checksetup.pl
#chmod 0640 zzz.txt
