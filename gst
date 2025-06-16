#!/bin/bash
set -e
git --no-pager branch
echo '(use "git reset HEAD <file>..." to unstage)'
git status -s | st -- --nostrip
# get the last argument
# known issue, doesn't work if the filename contains '->'
st - | sed 's/^ *[^ ]*//' | sed 's/.* -> //' | st -- > /dev/null
# unquote filename if filename contains space
st - --shell echo | st -- > /dev/null
