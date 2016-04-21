#!/usr/bin/env sh
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.
curl http://ftp.monash.edu.au/pub/nihongo/edict2.gz | gunzip | sed "1 d" > edict2.txt
