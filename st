#!/usr/bin/env python3
import subprocess
import sys
import os
import re
import shutil
import unicodedata
import signal
from signal import signal, SIGPIPE, SIG_DFL, SIGINT, default_int_handler
signal(SIGPIPE,SIG_DFL) # ignore broken pipe
signal(SIGINT, default_int_handler) # catch KeyboardInterrupt

debug = False
helpText = '''Usage: st -- [options]                   Cache input
   or: st <range> [<options>] [<program>]  Output cached result to <program> as
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
   -h  or  --help     Print Help (this message) and then exit
   -e                 Exit immediate if a program returns none zero exit code
                      The exit code will be the same as that program
   -c  COLOUR         Set the colour control sequence of line number
                      The format of this field is ANSI/VT100
                      If not specified, $STCOLOR will be used
                      If $STCOLOR is not set, "\\033[34m" will be used
                      Pass -c "" can disable colouring
                      Example:
                        > export STCOLOR='\\e[5m'
                        > st
                        1 file1
                        2 file2
                        # line numbers will blink
   -C  or  --clear    Clear all buckets and exit
                      If -b is specified, clear the given basket
                      If -b is specified as the last argument, clear default
   -n                 Print total number of lines cached and then exit
   -p  or  --path     Print path of the cache and then exit
   --oneperline       Force output to be one entry per line when listing
                      Otherwise, st will render multiple columns to use the
                      full width of the screen
                      This is the default when <range>, <program> or -s
                      is specified
   -s  or  --stream   In input mode, number and print lines immediately
   -l  or  --logging  Print the command before executing
   -o  or  --oneline  Output results on oneline
                      Example:
                        > st - echo start _@_ end
                        start _1_ end
                        start _2_ end
                        start _3_ end
                        > st - -o echo start _@_ end
                        start _1_ _2_ _3_ end
   -b BUCKET          Use the specified bucket
                      If not specified, $STBUCKET will be used
                      If $STBUCKET is not set, "default" will be used
                      BUCKET files will be stored under $STBUCKETS
                      if not specified, ~/.stbuckets will be used
                      Example: 
                        > echo b1 | st -b bk1 -- > /dev/null
                        > echo b2 | st -b bk2 -- > /dev/null
                        > st - -b bk1
                        b1
                        > st - -b bk2
                        b2
   --nostrip          Do not strip the input lines when printing
   --shell            Use shell to run the program
                      Example:
                        > export TEST='echo hi'
                        > echo '$TEST' | st -- > /dev/null
                        > st - echo           # print as is
                        $TEST
                        > st - --shell echo   # print with expansion
                        echo hi
                        > st - --shell        # expand and run input as program
                        hi

program:
   Can be any program with any number of specified arguments
   @ will be replaced with the result
   # will be replaced with line number
   Escape sequences: %@ -> @ ; %# -> # ; %% -> %
   If no program is specified, default to echo
   If no replacement string is used, @ will be added to the end of the program
   Example:
     > ls | st -- > /dev/null
     > st
     1 file1
     2 file2
     3 file3
     > st - -o mv @ ~      # Moves all files to home folder
     > st -                # same as st - echo @
     file1
     file2
     file3
     > st - "%@ # %#"      # same as st - echo "%@ # %#"
     @ 1 #
     @ 2 #
     @ 3 #
'''

### parse arg

stbuckets = os.getenv("STBUCKETS")
if not stbuckets:
  stbuckets = os.getenv("HOME") + "/.stbuckets"

stbucket = os.getenv("STBUCKET")
if not stbucket:
  stbucket = "default"
stbucket = stbucket.replace("/", "-")

stcolor = os.getenv("STCOLOR")
if not stcolor:
  stcolor = "\033[34m"

exitOnError = False
clear = False
clearAll = True
count = False
onePerLine = False
streaming = False
oneline = False
input = False
path = False
logging = False
rawLines = []
program = []
nostrip = False
shell = False

i = 1
while i < len(sys.argv):
  arg = sys.argv[i]
  if arg == "-h" or arg == "--help":
    print(helpText, end='')
    exit()
  elif arg == "-e":
    exitOnError = True
  elif arg == "-c":
    i += 1
    if i < len(sys.argv):
      stcolor = sys.argv[i]
  elif arg == "-C" or arg == "--clear":
    clear = True
  elif arg == "-n":
    count = True
  elif arg == "--oneperline":
    onePerLine = True
  elif arg == "-s" or arg == "--stream":
    streaming = True
  elif arg == "-o" or arg == "--oneline":
    oneline = True
  elif arg == "-l" or arg == "--logging":
    logging = True
  elif arg == "-b":
    clearAll = False
    i += 1
    if i < len(sys.argv):
      stbucket = sys.argv[i]
  elif arg == "-p" or arg == "--path":
    path = True
  elif arg == "--":
    input = True
  elif arg == "--nostrip":
    nostrip = True
  elif arg == "--shell":
    shell = True
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

stfile = stbuckets + "/" + stbucket + "_file" # contains cache
stpath = stbuckets + "/" + stbucket + "_path" # contains working directory
if not os.path.isdir(stbuckets):
  os.mkdir(stbuckets)
if not os.path.isfile(stfile):
  open(stfile, "w").close()
if not os.path.isfile(stpath):
  open(stpath, "w").close()

stpathr = open(stpath, "r")
stwd = stpathr.readline().strip("\n")
stpathr.close()

stfiler = open(stfile, "r")
stcontent = [ l[:-1] for l in stfiler.readlines() ]
maxLine = len(stcontent)
stfiler.close()

### parse range

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
  result = type('', (), {})
  result.returncode = retcode
  return result

subRun = subprocess.run if sys.version_info.minor >= 5 else subRunCompatible

VT100Patern = re.compile("\x1b\\[[0-9;]*[mGKH]")

def displayLen(s):
  s = VT100Patern.sub("", s)
  return sum([ unicodedata.east_asian_width(c) in "FW" for c in s]) + len(s)

def printCache(stcontent, b): # b is shift in line number
  if not stcontent:
    return
  stlen = len(stcontent)
  numlen = len(str(stlen))

  resetColor = "\033[0m" if stcolor else ""
  entryFormat = "%s%%-%dd %s%%s" % (stcolor, numlen, resetColor)
  lines = [entryFormat % (i + b, stcontent[i]) for i in range(len(stcontent))]

  displayLens = [ displayLen(l) for l in lines ]

  terminalSize = shutil.get_terminal_size(fallback=(1, 1))[0]
  cols = terminalSize // (max(displayLens) + 1)
  if onePerLine or cols < 1:
    cols = 1
  rows = stlen // cols + (stlen % cols > 0)

  for i in range(rows):
    for j in range(cols):
      idx = j * rows + i
      if idx < stlen:
        diffLen = len(lines[idx]) - displayLens[idx]
        lineFormat = "%%-%ds" % (terminalSize // cols + diffLen)
        print(lineFormat % lines[idx], end="")
    print()

def prepRun(base, t, c):
  # do replacement on arguments
  replaced = False
  result = []
  for p in base.split("%%"):
    replaced = replaced or "#" in p.replace("%#", "")
    p = "#".join([ s.replace("#", str(c)) for s in p.split("%#") ])

    replaced = replaced or "@" in p.replace("%@", "")
    p = "@".join([ s.replace("@", t) for s in p.split("%@") ])

    result.append(p)
  return ("%".join(result), replaced)

def run(cmd):
  try:
    if shell:
      retcode = subRun(' '.join(cmd), shell=True).returncode
    else:
      retcode = subRun(cmd).returncode
    if retcode and exitOnError:
        exit(retcode)
  except FileNotFoundError:
    print("st: command not found:", cmd[0], file=sys.stderr)
    exit(1)
  except KeyboardInterrupt:
    exit()

if clear:
  if clearAll:
    subRun(["rm", "-r", stbuckets])
  else:
    subRun(["rm", stpath, stfile])
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
  lines = []
  stfilew = None
  for line in sys.stdin:
    if not stfilew:
      # modify st files after the fist line arrive
      # this is to prevent conflict when two st commands are connected using pipe
      stpathw = open(stpath, "w")
      stpathw.write(os.getcwd())
      stpathw.close()
      stfilew = open(stfile, "w")
    if not line.strip():
      continue
    stfilew.write(line)
    lines.append(line.strip(os.linesep) if nostrip else line.strip())
    if streaming:
      printCache(lines[-1:], len(lines))
  if not stfilew:
    stpathw = open(stpath, "w")
    stpathw.write(os.getcwd())
    stpathw.close()
    stfilew = open(stfile, "w")
  stfilew.close()
  if not streaming:
    printCache(lines, 1)
  exit()

if number:
  printCache(stcontent, 1)
  exit()

if not os.path.isdir(stwd):
  print("st: directory deleted:", stwd, file=sys.stderr)
  exit(1)
os.chdir(stwd)

hasProgram = shell
hasSt = False

cmds = [[]] if oneline else []
for b in range(len(program) + 1):
  if b < len(program):
    base = program[b]
  else:
    if hasSt:
      break
    else:
      base = "@" # do one more iteration with @ if no replacement is specified
  c = 0
  for l in lines:
    c += 1
    arg, replaced = prepRun(base, stcontent[l - 1], c)
    if not replaced:
      if b == 0:
        hasProgram = True
    else:
      hasSt = True
    if oneline:
      cmds[0].append(arg)
      if not replaced:
        break; # oneline mode keep only one arg if no replacement
    else:
      if len(cmds) < c:
        cmds.append([])
      cmds[c - 1].append(arg)
for cmd in cmds:
  if hasProgram:
    if logging:
      print("st:", " ".join(cmd), file=sys.stderr)
    run(cmd)
  else:
    print(" ".join(cmd))
