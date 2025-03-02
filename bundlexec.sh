#!/bin/sh

# This solves the baroque exception that (some?) gems installed from git cannot be loaded from bare ruby with `require`.

IFS=:
for path in $(gem env GEM_PATH);do
	for lib in "$path"/bundler/gems/*/lib;do
		if [ -z "$rubylib" ];then
			rubylib="$lib"
		else
			rubylib="$rubylib:$lib"
		fi
	done
done

exec RUBYLIB="$rubylib" "$@"
