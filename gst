#!/bin/bash
git --no-pager branch
echo '(use "git reset HEAD <file>..." to unstage)'
git status -s | st --
st - | awk '{print $2}' | st -- > /dev/null
