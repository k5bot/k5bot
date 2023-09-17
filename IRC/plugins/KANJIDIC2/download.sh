#!/usr/bin/env sh
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.
curl http://www.edrdg.org/kanjidic/kanjidic2.xml.gz | gunzip > kanjidic2.xml
curl http://ftp.edrdg.org/pub/Nihongo/kradfile.gz | gunzip | iconv -f euc-jp -t utf-8 > kradfile-u.txt
curl http://ck.kolivas.org/Japanese/sorted_freq_list.txt > gsf.txt
