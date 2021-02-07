#!/bin/bash
set -e
git --no-pager branch
echo '(use "git reset HEAD <file>..." to unstage)'
git status -s | st -- --nostrip
st - | awk '{print $2}' | st -- > /dev/null
