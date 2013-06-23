#!/usr/bin/env sh
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

root=$(dirname "${0}")

# KANJIDIC
pushd "${root}/IRC/plugins/KANJIDIC" && \
./download.sh
popd

# KANJIDIC2
pushd "${root}/IRC/plugins/KANJIDIC2" && \
./download.sh && \
./convert.rb
popd

# EDICT
pushd "${root}/IRC/plugins/EDICT" && \
./download.sh && \
./convert.rb
popd

# CEDICT
pushd "${root}/IRC/plugins/CEDICT" && \
./download.sh && \
./convert.rb
popd

# Language
pushd "${root}/IRC/plugins/Language" && \
./download.sh
popd
