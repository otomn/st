# Unix output management tools

## st

(No idea why I picked that name)

A tool for storing the output of any program and select lines to be used as input or argument to another programs

e.g. Suppose the log folder looks like this: 

    2020-01-01.log
    2020-01-03.log
    2020-01-04.log
    2020-01-05.log
    2020-01-07.log
    2020-01-10.log
    2020-01-11.log
    
and you want to combine logs 01-03 to 01-10 into one file

With st, you can do the following:

    > ls | st --
    1 2020-01-01.log
    2 2020-01-03.log
    3 2020-01-04.log
    4 2020-01-05.log
    5 2020-01-07.log
    6 2020-01-10.log
    7 2020-01-11.log
    > st 2 - 6 -o cat > out.log

Use `st -h` to see the full documentation, more examples included

## stls

Because `ls | st --` is so frequently used, I decided to write a wrapper for it

If additional arguments are provided: if the argument starts with "-" then it will be used as an argument for ls, else it will be used as filtering regex (case ignored)

e.g. `stls -aS '\.c'` is the same as `ls -aS | grep '\.c' | st --`

## stfind

Similar to stls, just a wrapper for `find` for searching files in subdirectories

## stcd

A warpper for changing directory with ease

Suppose you are at `/etc/defaults` that contains folder `randomFolder`

    > stls          # list all folders
    1 randomFolder
    > . stcd 1      # cd into randomFolder
    > . stcd        # cd into /etc/defaults where st -- was called last

## gst

A wrapper for git status to use st to process the output
