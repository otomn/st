#!/usr/bin/env python3
import subprocess
import sys
import os
import re

def subRunCompatible(*popenargs, **kwargs):
  ''' use this if subprocess.run is not available on older versions of python'''
  input = kwargs.pop("input", None)
  check = kwargs.pop("handle", False)

  if input is not None:
    if 'stdin' in kwargs:
      raise ValueError('stdin and input arguments may not both be used.')
    kwargs['stdin'] = subprocess.PIPE

  process = subprocess.Popen(*popenargs, **kwargs)
  try:
    stdout, stderr = process.communicate(input)
  except:
    process.kill()
    process.wait()
    raise
  retcode = process.poll()
  if check and retcode:
    raise subprocess.CalledProcessError(
      retcode, process.args, output=stdout, stderr=stderr)
  return retcode, stdout, stderr

debug = False
subRun = subprocess.run
#subRun = subRunCompatible # use this on older versions of python
stbucketsDefault = os.getenv("HOME") + "/.stbuckets"
stbucketDefault = "default"
helpText = '''Usage: st -- [options]                   Cache input
   or: st <range> [options] [<program>]  Output cached result to <program> as
                                         argument. <program> will be called
                                         once per output line

range:
   Specify the cached lines to output
   If no range is given, output all lines and number each line if -o is not
   specified
   INTEGER            Output specified line
   -                  Output all lines if this is the only range specified
   INTEGER -          Output all lines after (inclusive) the specified line
   - INTEGER          Output all lines before (inclusive) the specified line
   INTEGER - INTEGER  Output all lines between (inclusive) the specified lines
   INTEGER can be negative to count from last
   Example:
     > st             # All results and number them
     > st -           # All results
     > st 2 -         # All results after line 2
     > st 1 - -2      # All results from line 1 to 2nd last line 
     > st 1 - 1 3 -   # All results from line 1 to line 1 
                      #   and all results after line 3
     > st - 1 2 3 -   # All restuls before line 1, line 2
                      #   and all results after line 3
   INTEGER cannot be 0 and -<# of results> <= INTEGER <= <# of results>

options:
   -h  or  --help     Print Help (this message) and exit
   -c  or  --clear    Clear all buckets and exit
   -n                 Print total number of lines cached and exit
   -p  or  --path     Print path of the cache
   -o  or  --oneline  Output result in oneline
                      Example:
                        > st - echo start _@_ end
                        start _1_ end
                        start _2_ end
                        start _3_ end
                        > st - -o echo start _@_ end
                        start _1_ _2_ _3_ end
   -b BUCKET          Use the specified bucket
                      If not specified, $stbucket will be used
                      If $stbucket is not set, "default" will be used
                      BUCKET files will be stored under $stbuckets
                      if not specified, ~/.stbuckets will be used
                      Example: 
                        > echo b1 | st -b bk1 -- > /dev/null
                        > echo b2 | st -b bk2 -- > /dev/null
                        > st - -b bk1
                        b1
                        > st - -b bk2
                        b2

program:
   Can be any program with any number of specified arguments
   @ will be replaced with the result
   # will be replaced with line number
   If no program is specified, default to echo
   Example:
     > ls | st -- > /dev/null
     > st
     1 file1
     2 file2
     3 file3
     > st - -o mv @ ~/#_file
     # Moves all files to home folder and rename to 1_file 2_file 3_file'''

### parse arg

stbuckets = os.getenv("stbuckets")
if not stbuckets:
  stbuckets = stbucketsDefault
stbucket = os.getenv("stbucket")
if not stbucket:
  stbucket = stbucketDefault

clear = False
count = False
oneline = False
input = False
path = False
rawLines = []
program = []

i = 1
while i < len(sys.argv):
  arg = sys.argv[i]
  if arg == "-h" or arg == "--help":
    print(helpText)
    exit()
  elif arg == "-c" or arg == "--clear":
    clear = True
  elif arg == "-n":
    count = True
  elif arg == "-o" or arg == "--oneline":
    oneline = True
  elif arg == "-b":
    i += 1
    stbucket = sys.argv[i]
  elif arg == "-p" or arg == "--path":
    path = True
  elif arg == "--":
    input = True
  else:
    if arg == "-":
      rawLines.append(arg)
    else:
      try:
        int(arg)
        rawLines.append(arg)
      except ValueError:
        program = sys.argv[i:]
        break
  i += 1

stfile = stbuckets + "/" + stbucket + "_file"
stpath = stbuckets + "/" + stbucket + "_path"
if not os.path.isdir(stbuckets):
  os.mkdir(stbuckets)
if not os.path.isfile(stfile):
  open(stfile, "w").close()
if not os.path.isfile(stpath):
  open(stpath, "w").close()

### parse range

stfiler = open(stfile, "r")
stcontent = [ l[:-1] for l in stfiler.readlines() ]
maxLine = len(stcontent)
stfiler.close()

lines = []
lastNum = None
ranging = False
number = False
for s in rawLines:
  if s == "-":
    if ranging:
      lines += list(range(lastNum if lastNum else 1, maxLine + 1))
      lastNum = None
    ranging = True
  else:
    n = int(s)
    if n < 0:
      n += maxLine + 1
    if n <= 0 or n > maxLine:
      print(s + " exceeded maximum number lines", file=sys.stderr)
      exit(1)
    if ranging:
      lines += list(range(lastNum if lastNum else 1, n + 1))
      ranging = False
      lastNum = None
    else:
      if lastNum:
        lines.append(lastNum)
      lastNum = n

if ranging:
  lines += list(range(lastNum if lastNum else 1, maxLine + 1))
  lastNum = None
if lastNum:
  lines.append(lastNum)

if not lines:
  number = True
  lines = list(range(1, maxLine + 1))

### debug

if debug:
  print(
  "raw:      ", sys.argv, "\n",
  "rawLines: ", rawLines, "\n",
  "lines:    ", lines,    "\n",
  "program:  ", program,  "\n",
  "stfile:   ", stfile,   "\n",
  "stpath:   ", stpath,   "\n",
  "oneline:  ", oneline,  "\n",
  "clear:    ", clear,    "\n",
  "path:     ", path,     "\n",
  "count:    ", count, file=sys.stderr)
  exit()

### run

if program and not "@" in str(program):
  program.append("@")

if clear:
  subprocess.run(["rm", "-r", stbuckets])
  exit()

if count:
  print(maxLine)
  exit()

if path:
  stpathr = open(stpath, "r")
  print(stpathr.readline().strip())
  stpathr.close()
  exit()

if input:
  stpathw = open(stpath, "w")
  stpathw.write(os.getcwd())
  stpathw.close()
  stfilew = open(stfile, "w")
  count = 0
  for line in sys.stdin:
    if not line.strip():
      continue
    count += 1
    stfilew.write(line)
    sys.stdout.write(str(count) + " " + line)
  stfilew.close()
  exit()

def run(args, c):
  stpathr = open(stpath, "r")
  wd = stpathr.readline().strip()
  stpathr.close()
  if not os.path.isdir(wd):
      print("st: directory deleted:", wd, file=sys.stderr)
      exit(1)
  os.chdir(wd)
  cmd = []
  for a in program:
    a = a.replace("#", str(c))
    if "@" in a:
      cmd += [ a.replace("@", l) for l in args ]
    else:
      cmd.append(a)
  if cmd:
    try:
      subRun(cmd)
    except FileNotFoundError:
      print("st: command not found:", cmd[0], file=sys.stderr)
      exit(1)
  else:
    print(" ".join(args))

if oneline:
  run([ stcontent[l - 1] for l in lines], 1)
else:
  c = 0
  for l in lines:
    c += 1
    if number:
      print(str(c) + " ", end="")
    run([stcontent[l - 1]], c)
