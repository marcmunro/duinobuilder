# Duinobuilder

This is a make-based build system for Arduino development.

It is for developers who are comfortable with make and don't need the
training wheels of the Arduino IDE.

It runs on any system with autoconf and make, and gives you a simple
easy to use build system that follows the Unix philosophy of tools
that do things quietly and keep out of your way.

## Prerequisites

You will need the arduino core libraries installed on your system.  On
debian this is installed from the arduino-core package.

## Overview

Duinobuilder uses a simple filesystem layout:

    duinuobuilder/libraries/<lib1>
                           /<lib2>
                           /...
                 /tests/<lib1>
                       /<lib2>
                       /...
                 /<board-dir1>/<project1>
                              /<project2>
                              /...
                 /<board-dir2>/<project1>
                              /<project2>
                              /...
                 /...

You develop your code in a project directory, which lives below a
board directory.  Each board directory is for building code for a
specific type of Arduino (eg a promini).  To build your project's code
you simply run make in that project directory.  If you don't have a
makefile, yet, in that directory, you can do this:

    $ make -f ../../Makefile

This will, as well as building your project's code create a default
Makefile for you.

## Board Directories

As each board directory contains projects for a specific type of
Arduino board, we have to define our Arduino type.  We do this by a
simple assignment in a file called BOARD_TYPE in that directory.

For example in my promini directory, the BOARD_TYPE file contains
this:

    BOARD_TYPE = pro328

It can easily be created by running make in the board directory:

    $ make -f ../Makefile

This will show you a list of board types and tell you to run make
again with BOARD_TYPE defined.  Something like this:

    $ make -f ../Makefile BOARD_TYPE=pro328

This will create the BOARD_TYPE file along with a Makefile.board
definition file for make and a default Makefile so you won't have to
specify the makefile on the command line any more.

## The Build And Test Cycle

In your project directory, you wil create and edit your files.  You
will periodically build them using `make`.  When the build succeeds
you can install them using:

    $ make upload

Then you try it out, figure out what needs to change, edit your files
and go again.  If typing `make` to build and then `make upload` to
upload the program is too much for you, you can simply type `make
upload`, which will re-build anything that it needs to and then only
upload if the build succeeded.

## Libraries

Libraries live in directories under the ```libraries``` directory.
You do not have to specify which libraries your project uses - make
figures that out for itself.

## Unit Tests

You can create unit tests for libraries by creating a directory
in ```duinobuilder/tests``` with the same name as that of the
library's directory.

## Help

Type

    $ make help

to get a list of everything that make can do for you.

## When it goes wrong

Try running make clean, and then running your make command again.  If
that doesn't work, there is a bug.  Either in duinuobuilder or in your
code.  If it looks like its in duinuobuilder then report the bug with
as much detail as possible and I'll see what I can do to fix it.

## Acknowledgements

This was inspired by the Arduino.mk makefile by Sudar Muthu.

I used this happily for a while but disliked:

- having to manually specify libraries;
- how noisy it's output was;
- its lack of support for documentation and unit testing.

Looking at the code, it is a very complex and sophisticated beast, and
worthy of admiration.  I stole a good number of ideas from it and
improved my own understanding of make in the process.  It's just that
it's not the best fit for the way that I like to work.

## Bugs And Deficiencies

There will be lots - this is early days.  Please bring to my attention
any that you find and I'll try to deal with them. 