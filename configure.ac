AC_INIT([arduino_makefile], [0.01])

# Use some arg handling from postgres.
m4_pattern_forbid(^PGAC_)dnl Fail if the needed macros are not defined
m4_pattern_forbid(^MMAC_)dnl Ditto
m4_include([m4/general.m4])

# Arduino dir.  From here we are going to find boards.txt and from
# that and our architecture we should be able to determine everything
# else.
#
AC_MSG_CHECKING([Checking arduino installation dir])
PGAC_ARG_REQ(with, arduinodir, [DIR],
	     [identify arduino installation dir [/usr/share/arduino]],
             [ARDUINO_DIR=${withval}],[ARDUINO_DIR=/usr/share/arduino])
AC_SUBST(ARDUINO_DIR)
AC_MSG_RESULT([${ARDUINO_DIR}])

[mm_ac_boards="${ARDUINO_DIR}/hardware/arduino/boards.txt"]

AC_CHECK_FILE([${mm_ac_boards}],,
  AC_MSG_FAILURE([Unable to find boards.txt (use --with-arduinodir)]))

BOARDS_TXT=${mm_ac_boards}
AC_SUBST(BOARDS_TXT)

# Possible other directories to add to PATH for our tools.
AC_DEFUN([AVR_PATH],
  [${ARDUINO_DIR}/hardware/tools/${ARCHITECTURE}/bin]dnl
  [${PATH_SEPARATOR}${HOME}/Arduino/hardware/tools/${ARCHITECTURE}/bin])

# Find avr toolchain tools
AC_CHECK_PROG([CXX],[avr-g++],[avr-g++],[NOTFOUND])
if test "${CXX}" = "NOTFOUND"; then
    # avr-g++ not in PATH.  Try looking in AVR_PATH and setting vars
    # to the full path to the tools.
    AC_PATH_PROG([CXX],[avr-g++],[NOTFOUND],AVR_PATH)
    if test "${CXX}" = "NOTFOUND"; then
        AC_MSG_FAILURE([Unable to find avr-g++.])
    fi
    AC_PATH_PROG([CC],[avr-gcc],,,AVR_PATH)
    AC_PATH_PROG([AR],[avr-gcc-ar],,,AVR_PATH)
    AC_PATH_PROG([OBJCOPY],[avr-objcopy],,,AVR_PATH)
    AC_PATH_PROG([OBJDUMP],[avr-objdump],,,AVR_PATH)
    AC_PATH_PROG([SIZE],[avr-size],,,AVR_PATH)
    AC_PATH_PROG([NM],[avr-nm],,,AVR_PATH)
    AC_PATH_PROG([AVRDUDE_PATH],[avrdude],,,AVR_PATH)
    AC_PATH_PROG([ARDUINO_RESET],[ard-reset-arduino],,,AVR_PATH)
else
    # avr-g++ is found in PATH.  Assume others will be
    AC_CHECK_PROG([CC],[avr-gcc],[avr-gcc])
    AC_CHECK_PROG([AR],[avr-gcc-ar],[avr-gcc-ar])
    AC_CHECK_PROG([OBJCOPY],[avr-objcopy],[avr-objcopy])
    AC_CHECK_PROG([OBJDUMP],[avr-objdump],[avr-objdump])
    AC_CHECK_PROG([SIZE],[avr-size],[avr-size])
    AC_CHECK_PROG([NM],[avr-nm],[avr-nm])
    AC_CHECK_PROG([AVRDUDE],[avrdude],[avrdude])
    AC_CHECK_PROG([ARDUINO_RESET],[ard-reset-arduino],[ard-reset-arduino])
fi

if test -f /etc/avrdude.conf; then
  AVRDUDE_CONF=/etc/avrdude.conf
elif test -f ${ARDUINO_DIR}/hardware/tools/avrdude.conf; then
  AVRDUDE_CONF=${ARDUINO_DIR}/hardware/tools/avrdude.conf
fi
AC_SUBST(AVRDUDE_CONF)
# Possible other directories to add to PATH for our tools.
AC_DEFUN([AVR_PATH],
  [${ARDUINO_DIR}/hardware/tools/${ARCHITECTURE}/bin]dnl
  [${PATH_SEPARATOR}${HOME}/Arduino/hardware/tools/${ARCHITECTURE}/bin])

# Find avr toolchain tools
AC_CHECK_PROG([CXX],[avr-g++],[avr-g++],[NOTFOUND])
if test "${CXX}" = "NOTFOUND"; then
    # avr-g++ not in PATH.  Try looking in AVR_PATH and setting vars
    # to the full path to the tools.
    AC_PATH_PROG([CXX],[avr-g++],[NOTFOUND],AVR_PATH)
    if test "${CXX}" = "NOTFOUND"; then
        AC_MSG_FAILURE([Unable to find avr-g++.])
    fi
    AC_PATH_PROG([CC],[avr-gcc],,,AVR_PATH)
    AC_PATH_PROG([AR],[avr-gcc-ar],,,AVR_PATH)
    AC_PATH_PROG([OBJCOPY],[avr-objcopy],,,AVR_PATH)
    AC_PATH_PROG([OBJDUMP],[avr-objdump],,,AVR_PATH)
    AC_PATH_PROG([SIZE],[avr-size],,,AVR_PATH)
    AC_PATH_PROG([NM],[avr-nm],,,AVR_PATH)
    AC_PATH_PROG([AVRDUDE_PATH],[avrdude],,,AVR_PATH)
    AC_PATH_PROG([ARDUINO_RESET],[ard-reset-arduino],,,AVR_PATH)
else
    # avr-g++ is found in PATH.  Assume others will be
    AC_CHECK_PROG([CC],[avr-gcc],[avr-gcc])
    AC_CHECK_PROG([AR],[avr-gcc-ar],[avr-gcc-ar])
    AC_CHECK_PROG([OBJCOPY],[avr-objcopy],[avr-objcopy])
    AC_CHECK_PROG([OBJDUMP],[avr-objdump],[avr-objdump])
    AC_CHECK_PROG([SIZE],[avr-size],[avr-size])
    AC_CHECK_PROG([NM],[avr-nm],[avr-nm])
    AC_CHECK_PROG([AVRDUDE],[avrdude],[avrdude])
    AC_CHECK_PROG([ARDUINO_RESET],[ard-reset-arduino],[ard-reset-arduino])
fi

if test -f /etc/avrdude.conf; then
  AVRDUDE_CONF=/etc/avrdude.conf
elif test -f ${ARDUINO_DIR}/hardware/tools/avrdude.conf; then
  AVRDUDE_CONF=${ARDUINO_DIR}/hardware/tools/avrdude.conf
fi
AC_SUBST(AVRDUDE_CONF)

# Check the avr-size executable
if (${SIZE} --help | grep -sq AVR); then
  SIZE_FOR_AVR=yes
else
  SIZE_FOR_AVR=no
fi
AC_SUBST(SIZE_FOR_AVR)

AC_CONFIG_FILES([Makefile.global])
AC_OUTPUT
