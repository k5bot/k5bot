#!/usr/bin/env bash
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

# EDICT2
pushd "${root}/IRC/plugins/EDICT2" && \
./download.sh && \
./convert.rb
popd

# ENAMDICT
pushd "${root}/IRC/plugins/ENAMDICT" && \
./download.sh && \
./convert.rb
popd

# CEDICT
pushd "${root}/IRC/plugins/CEDICT" && \
./download.sh && \
./convert.rb
popd

# YEDICT
pushd "${root}/IRC/plugins/YEDICT" && \
./download.sh && \
./convert.rb
popd

# Language
pushd "${root}/IRC/plugins/Language" && \
./download.sh
popd

# Unicode
pushd "${root}/IRC/plugins/Unicode" && \
./download.sh
popd
