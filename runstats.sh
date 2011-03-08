#!/bin/sh

cd /var/www/bugs.gentoo.org/htdocs

custom_buglist="https://bugs.gentoo.org/custom_buglist.cgi"

[ ! -d "data/cached/" ] && mkdir -p data/cached/
outpath="/var/www/bugs.gentoo.org/htdocs/data/cached"

./collectstats.pl

dofile() {
  url="$1"
  outfile="$2"
  tmp="${outfile}.$$"
  #echo $url
#  wget -q "$url" -O "${tmp}" --header 'Host: bugs.gentoo.org'
  curl -sS --resolve bugs.gentoo.org:443:127.0.0.1 "${url}" -o "${tmp}"
  if [ $? -eq 0 ]; then
      gzip -9 <"${tmp}" >"${tmp}.gz"
      mv -f "${tmp}" "${outfile}"
      mv -f "${tmp}.gz" "${outfile}gz"
  else
      rm -f "${tmp}" "${tmp}.gz" "${outfile}" "${outfile}gz"
  fi
}

for status in RESOLVED VERIFIED CLOSED ; do
  for reso in FIXED INVALID WONTFIX LATER REMIND WORKSFORME CANTFIX NEEDINFO TEST-REQUEST UPSTREAM ; do
   dofile "$custom_buglist?reso=${reso}&status=${status}" ${outpath}/buglist-${status}-${reso}.html
 done
done

for status in UNCONFIRMED NEW ASSIGNED REOPENED ; do
   dofile "$custom_buglist?status=${status}" ${outpath}/buglist-${status}.html
done
