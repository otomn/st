#!/bin/bash
set -e
git --no-pager branch
echo '(use "git reset HEAD <file>..." to unstage)'
git status -s | st -- --nostrip
st - bash -c "echo @" | awk '{$1=""; print substr($0,2)}' | st -- > /dev/null
