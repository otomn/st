# Unix output management tools

## st

(No idea why I picked that name)

A tool for storing the output of any program and select lines to be used as input or argument to another programs.

e.g. Suppose the log folder looks like this: 

    > ls
    2020-01-01.log
    2020-01-03.log
    2020-01-04.log
    2020-01-05.log
    2020-01-07.log
    2020-01-10.log
    2020-01-11.log
    
and you want to combine logs 01-03 to 01-10 into one file.

With `st`, you can do the following:

    > ls | st --
    1 2020-01-01.log
    2 2020-01-03.log
    3 2020-01-04.log
    4 2020-01-05.log
    5 2020-01-07.log
    6 2020-01-10.log
    7 2020-01-11.log
    > st 2 - 6 -o cat > out.log

`st` bucket (cache) is saved in the file system, which means different terminal sessions can access it at the same time. e.g. you can run `stls` in one terminal and `st 1 vim` in another.
You can manually choose a different bucket by using `-b` option or set `stbucket` in the environment.

Use `st -h` to see the full documentation for more functionalities, more examples included.

Note: please do not use `temp` as the bucket name as some scripts below also use this bucket as temp storage

## stls

Because `ls | st --` is so frequently used, I decided to write a wrapper for it.

If additional arguments are provided: if the argument starts with `-` then it will be used as an argument for `ls`, otherwise it will be used as a filtering regex (case ignored).

e.g. `stls -aS '\.c'` is the same as `ls -aS | grep -i '\.c' | st --`

## stfind

Similar to stls, just a wrapper for `find` for searching files in subdirectories.

## stcd

A warpper for changing directory with ease.

Suppose you are at `/etc/defaults` that contains folder `randomFolder`

    > stls          # list all folders
    1 randomFolder
    > . stcd 1      # cd into randomFolder
    > . stcd        # cd into /etc/defaults where st -- was called last

If the file you selected is not a directory, `stcd` will cd into the parent directory

    > stfind common
    1 ./src/python/common.py
    > . stcd 1      # cd into ./src/python

## gst

A wrapper for `git status -s` to use `st` for caching the files

To colorize the output, set `color.status` to `always` in git config

## stps

A wrapper for `ps` that label the lines and cache the PIDs where the location of PID in each line is extracted from the header line of `ps`

If additional arguments are provided:

- If the argument starts with `-` then it will be used as an argument for ps with the first `-` removed
    - e.g. `stps -aux --r` calls `ps aux -r`
    - You can also do `stps -"aux -r"` which also calls `ps aux -r`
    - If no combined option for ps (e.g. `aux`) is specified, default to `ax`
    - If you want to call `ps` with no argument, just pass `-`
- If the argument is a digit, it will be used as the line limit
- Otherwise the argument will be used as a keyword for filtering results

Putting all together, `stps -"aux -r" zsh 5` will list top 5 zsh programs that use the most cpu among all users