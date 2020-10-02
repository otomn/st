#!/bin/bash
git --no-pager branch
echo '(use "git reset HEAD <file>..." to unstage)'
git status -s | st -- -b gst
st - -b gst | awk '{print $2}' | st -- > /dev/null
