#!/usr/bin/env sh
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

cd "$(dirname "$0")"

[ -d download-tmp ] || mkdir download-tmp || exit 1

# Incremental download/update
rsync --backup -vv -t --info=progress2 --compress-level=6 'ftp.edrdg.org::nihongo/edict2.gz' download-tmp/ || exit 1
echo 'Updated download-tmp/edict2.gz'

# Decompress and drop line 1 (title)
gunzip < download-tmp/edict2.gz | sed 1d > edict2.txt || exit 1
echo 'Updated edict2.txt'


echo
echo 'The following is optional, failure is not fatal.'

freqfile=edict-freq-20081002

wget -c "http://ftp.edrdg.org/pub/Nihongo/${freqfile}.tar.gz" -O "download-tmp/${freqfile}.tar.gz" || exit 1

tar -O -xf "download-tmp/${freqfile}.tar.gz" "$freqfile/$freqfile" | sed 1d | awk '
{
	freq = $(NF)
	sub(".*###", "", freq)
	sub("/$", "", freq)
	printf("%s\t%s\t_\n", freq, $1)
}
' > word_freq_report.txt || exit 1

echo 'Created word_freq_report.txt'
