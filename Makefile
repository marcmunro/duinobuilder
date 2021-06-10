# Marc's Makefile for Arduino projects
#
# This exists due to frustration with the Arduino IDE, a general
# disatisfaction with Arduino.mk (even though it is a splendid piece
# of work), and a desire to have the makefile automate as much of
# *everything* (including unit tests and documentation builds) as
# possible while being generally as quiet as possible.  Also, I don't
# like the .ino sketch format, so this just builds real c, c++, and
# assembler files.
#
# It requires you to follow the following directory structure:
# ./libraries/lib1
#            /lib2
#            /etc
# ./tests/lib1
#        /lib2
#        /etc
# ./<board_dir1>/proj1
#               /proj2
#               /etc
# ./<board_dir2>/proj4
#               /proj5
#               /etc
#
# The libraries subdirectories are for user-provided libraries.
# The tests subdirectories are for unit tests for user-provided
# libraries.
# The <board_dir> subdirectories are for board-specific project
# directories.
#
# The principle is that make will do the appropriate thing based on
# what directory you are in.  If you are in a project directory it
# will try to build the project.  If you are in a library or unit test
# directory it will try to run unit tests for that library, etc.
#
# In your project directories you should not *need* to create a custom
# makefile or tell make about your use of libraries, etc.  Generally,
# it can figure it all out for itself.
#
# To run make in a subdirectory you can either use -f like this:
#     myproj$ make -f ../../Makefile
#
# or you can create a local makefile, like this:
#     myproj$ make -f ../../Makefile makefiles
#
# once you have a local makefile, you no longer need the -f.
#
# The "makefiles" target will create local Makefiles in the current
# directory and recursively in subdirectories.  It will not overwrite
# any user-defined Makefile, and neither will the clean target(s)
# remove any.
#
# To create a new board directory:
# - identify the board type you want:
#   use "make show_boards" to get a list
# - create a new directory with whatever name you like:
#   eg for a promini, I use the name promini
# - create a BOARD_TYPE file in that directory with a BOARD_TYPE
#   definition as given by the show_boards target eg for promini, my
#   BOARD_TYPE file contains: 
#     BOARD_TYPE = pro328
#
# To see a list of major targets and get a little more help use:
#     $ make help
#


.PHONY: all board_dir check_code_dir check_device_path \
	clean clean_board_dir clean_code_dir clean_root_dir \
	clean_test clean_unknown code_dir devices \
	distclean distclean_board_dir distclean_code_dir \
	distclean_root_dir distclean_test distclean_unknown \
	docs do_eeprom do_help do_upload eeprom help \
	makefiles makefiles_board_dir makefiles_code_dir \
	makefiles_root_dir makefiles_test makefiles_unknown \
	monitor no_screen remove_identity reset root_dir \
	show_boards size upload verify_size


# Figure out the path to this makefile, and to the makefile that we
# initially invoked.
#
MAKEFILEPATH := $(realpath $(call lastword,$(MAKEFILE_LIST)))
ROOT_MAKEFILE = $(firstword $(MAKEFILE_LIST))


###########
# Helper definitions

# For targets that don't do anything.  This gives us some feedback
# during Makefile development.
DO_NOTHING = echo "Doing nothing for $@ (deps: $^)"

# empty definition.  Needed by the succeeding definition for "space".
empty =

# An explicit space definition for use in macros.  Generally, macros
# eliminate leading spaces.  Using this definition will prevent that.
space = $(empty) $(empty)

# Helper Functions...
# is_lib: Param is considered a library if it contains a .h file with
# the same stem as the directory name.
is_lib = $(foreach lib,$(1), \
	   $(and $(wildcard $(lib)/$(notdir $(lib)).h), \
	         $(lib)))

# deplibs: Return libraries referenced from $(DEPS) that can be found
# in the directory given by our parameter.
# Note that as this depends on the value of $(DEPS), this needs to be
# used in recursively expanded variables (ie do not use :=) as the
# value of DEPS will be one of the last things that gets settled.
deplibs = $(sort $(filter-out ./, $(foreach lib, \
	$(shell grep -sh "^ *$(strip $(1))/" $(DEPS) /dev/null), \
	$(dir $(lib)))))

# remove: Remove from $(1) elements that appear in $(2).  This is like 
# filter-out, but with $(2) being a list.
remove = $(foreach entry, $(1), \
	   $(if $(filter $(entry), $(2)),,$(entry)))


###########
# Figure out where we are, what we might be able to do, and what
# inclusions we might want.

# This makefile can be used from anywhere in the directory tree.  The
# directory from which we are called will affect what we can
# reasonably build, so figure out where we are being called from.
#
ROOTDIR = $(realpath $(dir $(MAKEFILEPATH)))
PARENTDIR = $(realpath $(CURDIR)/..)
CODE_DIR = CODE_DIR_IS_UNDEFINED

IGNORE_DIRS = html
IGNORE_THIS = $(filter-out $(IGNORE_DIRS), $(notdir $(CURDIR)))

ifeq ($(CURDIR),$(ROOTDIR))
  BUILD_TYPE = root_dir
  DOC_SOURCES = $(shell find . -name '[a-zA-Z]*.c' -o -name '[a-zA-Z]*.h' \
		    -o -name '[a-zA-Z]*.cpp' -o -name '[A-Z]*.md')
else
  LIBDIR = $(ROOTDIR)/libraries
  ifeq ($(CURDIR),$(LIBDIR))
    BUILD_TYPE = test
  else
    ifeq ($(CURDIR),$(ROOTDIR)/tests)
      BUILD_TYPE = test
    else
      ifeq ($(ROOTDIR),$(PARENTDIR))
	ifeq ($(IGNORE_THIS),)
          BUILD_TYPE = unknown
	else
          BUILD_TYPE = board_dir
          BOARD_DIR = $(CURDIR)
	endif
      else
        GRANDPARENTDIR = $(realpath $(CURDIR)/../..)
        ifeq ($(ROOTDIR),$(GRANDPARENTDIR))
          BUILD_TYPE = code_dir
          BOARD_DIR = $(PARENTDIR)
          CODE_DIR = $(CURDIR)
        else
          BUILD_TYPE = unknown
        endif
      endif
    endif
  endif
endif


###########
# Default target.  What is built by default depends on the type of
# directory we are called from.
all: $(BUILD_TYPE)


# This is for debugging the makefile during its development.
what:
	@echo BUILD_TYPE: $(BUILD_TYPE)
	@echo ROOT_DIR: $(ROOTDIR)
	@echo BOARD_DIR: $(BOARD_DIR)
	@echo CURDIR: $(CURDIR)
	@echo DEPS: $(DEPS)
	@echo REQ: $(REQUIRED_USER_LIBDIRS)
	@echo USERLIB: $(USERLIB_OBJECTS)
	@echo CPP: $(USERLIB_CPP_SOURCES)
	@echo LIB: $(LIB_OBJECTS)
	@echo CORE: $(CORE_OBJECTS)
	@echo DOC_SOURCES: $(DOC_SOURCES)
	@echo SOURCES: $(SOURCES)
	@echo DEPS: $(DEPS)


###########
# Primary target definitions for code directories

OBJDIR = $(realpath $(CURDIR))/build
TARGET_NAME = $(subst $(space),_,$(notdir $(CURDIR)))
TARGET_HEX = $(OBJDIR)/$(TARGET_NAME).hex
TARGET_ELF = $(OBJDIR)/$(TARGET_NAME).elf
TARGET_EEP = $(OBJDIR)/$(TARGET_NAME).eep
CORE_LIB   = $(OBJDIR)/libcore.a

USER_CPP_SOURCES = $(wildcard *.cpp)
USER_C_SOURCES = $(wildcard *.c)
USER_SOURCES = $(USER_CPP_SOURCES) $(USER_C_SOURCES)
USER_OBJECTS = $(patsubst %.cpp, $(OBJDIR)/%.o, $(USER_CPP_SOURCES)) \
	       $(patsubst %.c, $(OBJDIR)/%.o, $(USER_C_SOURCES))
DEPS = $(USER_OBJECTS:.o=.d) $(wildcard build/*.d)

check_device_path:
	@if [ "x$(DEVICE_PATH)" = "x<undefined>" ]; then \
	    echo "\n  ERROR: No DEVICE_PATH provided\n" 1>&2; \
	    exit 2; fi

reset: check_device_path no_screen
	$(FEEDBACK) Resetting Arduino...
	$(AT) $(ARDUINO_RESET) $(DEVICE_PATH)

upload:	$(TARGET_HEX) verify_size reset
	$(MAKE) -f $(ROOT_MAKEFILE) do_upload

eeprom:	$(TARGET_EEP) verify_size reset
	$(MAKE) -f $(ROOT_MAKEFILE) do_eeprom

# This is used recursively from the upload target in order to separate
# any dependencies for this target from the main dependency graph.
# This allows us to effectively perform on-upload actions such as
# clearing headers for unique machine ids, etc.
do_upload: no_screen
	$(FEEDBACK) "\n  Uploading $(notdir $(TARGET_HEX)) to $(DEVICE_PATH)\n"
	$(AT) $(AVRDUDE) -q -V -p $(MCU) -C $(AVRDUDE_CONF) \
	       -D -c $(AVRDUDE_ARD_PROGRAMMER) -b $(AVR_BAUD) \
	       -P $(DEVICE_PATH) -U flash:w:$(TARGET_HEX):i

do_eeprom: no_screen
	$(FEEDBACK) "\n  writing eeprom from $(notdir $(TARGET_EEP)) using $(DEVICE_PATH)\n"
	$(AT) $(AVRDUDE) -q -V -p $(MCU) -C $(AVRDUDE_CONF) \
	       -D -c $(AVRDUDE_ARD_PROGRAMMER) -b $(AVR_BAUD) \
	       -P $(DEVICE_PATH) -U eeprom:w:$(TARGET_EEP):i

# Attempt to determine the serial device to use for uploads and
# monitoring for DEVICE_PATH.  This is a best guess.  The caller may
# provide a definitive version of DEVICE_PATH.
DEVICE_PATHS = $(wildcard \
		/dev/ttyACM? /dev/ttyUSB? /dev/tty.usbserial* \
		/dev/tty.usbmodem* /dev/tty.wchusbserial*)

ifndef DEVICE_PATH
  DEVICE_PATH = $(firstword $(DEVICE_PATHS))
endif

# Give DEVICE_PATH a displayable <undefined> value if it is still not
# defined.  This is used by the help target.
ifeq ($(DEVICE_PATH),)
  DEVICE_PATH = <undefined>
endif

devices:
	@echo DEVICES: $(DEVICE_PATHS)


###########
# Inclusions

# We need the definition of DEPS above before inclusions, as DEPS form
# part of those inclusions.
include $(ROOTDIR)/Makefile.global


###########
# Post-inclusion helpers

# Size checking definition for recipes that need to be concerned with it.
ifneq ($(strip $(HEX_MAXIMUM_SIZE)),)
    CHECK_SIZE = if [ `$(SIZE) $(TARGET_HEX) | awk 'FNR == 2 {print $$2}'` -le $(HEX_MAXIMUM_SIZE) ]; then touch $(TARGET_HEX).sizeok; else echo EXECUTABLE IS TOO LARGE 1>&2;  echo; rm $(TARGET_HEX); exit 2; fi
else
    CHECK_SIZE = echo "I do not know maximum flash memory of $(BOARD_TAG).";\
		 echo "Make sure the size of $(TARGET_HEX) is less than $(BOARD_TAG)\'s flash memory"; \
		touch $(TARGET_HEX).sizeok
endif


###########
# Verbosity control.  Define VERBOSE to show the full compilation, etc
# commands.  Note that QUIET may be defined to separately prevent the
# executable size being shown.  If VERBOSE is defined $(FEEDBACK) will
# do nothing and $(AT) will have no effect, otherwise $(FEEDBACK) will
# perform an echo and $(AT) will make the following command execute
# quietly.  For eaxmples of this in use, see the reset target.
ifdef VERBOSE
    FEEDBACK = @true
    AT = 
else
   FEEDBACK = @echo
   AT = @
endif

# QUIET is used to prevent the automatic display of object size
# information.
ifndef QUIET
  # Define avr_size to handle parameters based on capability
  ifeq ($(SIZE_FOR_AVR),yes)
    # There is a patched version of size that handles AVR with
    # prettier output.
    avr_size = echo; $(SIZE) $(SIZEFLAGS) --format=avr $(1)
  else
    # Plain-old binutils version - just give it the hex.
    avr_size = $(SIZE) $(2)
  endif
else
  # Make avr_size do nothing
  avr_size = true
endif


###########
# Target definitions for code directories

# Default build target for root directory
root_dir: $(ROOTDIR)/Makefile.global

$(ROOTDIR)/Makefile.global: $(ROOTDIR)/configure \
			    $(ROOTDIR)/Makefile.global.in
	@$(FEEDBACK) "\n  Creating $(notdir $@)...\n"
	$(AT)cd $(ROOTDIR); ./configure; 
	$(AT)cd $(BOARD_DIR); rm -rf $(CONFIG_FILES)

$(ROOTDIR)/configure: $(ROOTDIR)/configure.ac
	@$(FEEDBACK) "\n  Creating $(notdir $@) for Makefile.global..."
	$(AT)cd $(ROOTDIR); autoconf


###########
# Target for dealing with unknown directory types.
unknown:
	@echo "UNKNOWN DIRECTORY TYPE: I DO NOT KNOW WHAT TO BUILD" 1>&2
	@exit 2


###########
# Target definitions for board directories
# These just ensure that we have a local Makfile, and an inclusion
# file that specifies the parameters for the board type.

board_dir: $(BOARD_DIR)/Makefile.board $(BOARD_DIR)/Makefile
	@$(DO_NOTHING)

# TODO: Comments
SHOWBOARDS = $(MAKE) -f $(MAKEFILEPATH) show_boards IGNORE_BOARD=y

CHECK_BOARDTYPE = if [ "x" = "x$(BOARDS_TXT)" ]; then \
    echo "\n  ERROR: Cannot (yet) find the boards.txt file.  Try running again.\n" 1>&2; \
    exit 2; \
  fi; if [ "x" = "x${BOARD_TYPE}" ]; then \
    $(SHOWBOARDS); \
    echo "\n  ERROR: Board type not provided.  Run again with BOARD_TYPE=<whatever>\n" 1>&2; \
  exit 2; \
  fi; if grep -shq "^$(BOARD_TYPE)\." $(BOARDS_TXT) /dev/null; then \
    true; \
  else \
    $(SHOWBOARDS); \
    echo "\n  ERROR: $(BOARD_TYPE) is not a supported board type.\n" 1>&2; \
  fi

CREATE_BOARDTYPE = echo "\nCreating $(notdir $(BOARD_DIR))/$(notdir $@)...\n"; \
    echo "BOARD_TYPE = $(BOARD_TYPE)" >$@

# Try to build the make inclusion file for a board directory.  This
# file identifies the board_type from which verious parameters can be
# determined.  The parameters are defined in the Makefile.board
# inclusion file.
$(BOARD_DIR)/BOARD_TYPE: 
	@$(FEEDBACK) Recording board type in $(notdir $@)
	$(AT)$(CHECK_BOARDTYPE)
	$(AT)$(CREATE_BOARDTYPE)

# Create Makefile.board which contains definitions specific for the
# type of board that this subdirectory handles.  The values for the
# parameters 
$(BOARD_DIR)/Makefile.board: $(ROOTDIR)/Makefile.global \
			     $(ROOTDIR)/Makefile.board.in \
			     $(ROOTDIR)/configure_board
	@$(FEEDBACK) "\n  Creating $(notdir $(BOARD_DIR))/$(notdir $@)...\n"
	$(AT)$(CHECK_BOARDTYPE)
	@# The following generates a warning which I have not been able
	@# to figure out a solution for.
	$(AT)cd $(ROOTDIR); ./configure_board --host=linux --target=avr \
	    --with-board=$(BOARD_TYPE)
	$(AT)mv $(ROOTDIR)/Makefile.board $(BOARD_DIR)/Makefile.board
	$(AT)cd $(BOARD_DIR); rm -rf $(CONFIG_FILES) \
		config.status

$(ROOTDIR)/configure_board: $(ROOTDIR)/configure_board.ac
	@$(FEEDBACK) "\n  Creating $(notdir $@) for Makefile.board..."
	$(AT)cd $(ROOTDIR)/; autoconf -o configure_board configure_board.ac


###########
# Libraries

# User libraries
# MY_LIB_DIRS may be provided by the caller
LOCAL_LIB_DIRS = $(sort $(ROOTDIR)/libraries $(MY_LIB_DIRS))
USER_LIB_PATHS = $(foreach dir, $(LOCAL_LIB_DIRS), $(realpath $(dir)))
USER_LIB_DIRS  = $(foreach dir, $(USER_LIB_PATHS), \
                     $(call is_lib, $(wildcard $(dir)/*)))
REQUIRED_USER_LIBDIRS = $(foreach dir, $(USER_LIB_DIRS), \
		           $(call deplibs, $(dir)))

USERLIB_CPP_SOURCES = $(foreach dir, $(REQUIRED_USER_LIBDIRS), \
		        $(wildcard $(dir)/*.cpp))
USERLIB_C_SOURCES = $(foreach dir, $(REQUIRED_USER_LIBDIRS), \
		      $(wildcard $(dir)/*.c))
USERLIB_OBJECTS = $(foreach obj, $(patsubst %.cpp, %.o, \
			           $(notdir $(USERLIB_CPP_SOURCES))) \
			         $(patsubst %.c, %.o, \
				   $(notdir $(USERLIB_C_SOURCES))), \
		            $(OBJDIR)/$(obj))


# Arduino (system) libraries...
ARDUINO_LIB_PATH = $(ARDUINO_DIR)/libraries
ARDUINO_LIB_DIRS = $(call is_lib, \
			$(wildcard $(realpath $(ARDUINO_LIB_PATH))/*))
REQUIRED_LIBDIRS = $(call deplibs, $(ARDUINO_LIB_PATH))
LIB_CPP_SOURCES = $(foreach dir, $(REQUIRED_LIBDIRS), $(wildcard $(dir)/*.cpp))
LIB_C_SOURCES = $(foreach dir, $(REQUIRED_LIBDIRS), $(wildcard $(dir)/*.c))
LIB_OBJECTS = $(foreach obj, $(patsubst %.cpp, %.o, \
			        $(notdir $(LIB_CPP_SOURCES))) \
			     $(patsubst %.c, %.o, \
				$(notdir $(LIB_C_SOURCES))), \
		  $(OBJDIR)/$(obj))

# Core library...
ARDUINO_CORE_PATH = $(ARDUINO_DIR)/hardware/$(VENDOR)/cores/$(ARDUINO_CORE)

# Identify the source files that comprise the core library.  Some of
# these files may be ignored, if:
#  - the user provides a list of the files to ignore in
#    IGNORE_CORE_FILES
#  - there are user-provided libraries that match the stem of the
#    source file and IGNORE_CORE_FILES has not been provided.
#  - the source file is main.cpp, which we do not want since we are
#    quite capable of writing that for ourselves.
#
ifndef IGNORE_CORE_FILES
  matching_corefiles = $(wildcard $(ARDUINO_CORE_PATH)/$(1)*.cpp) \
		       $(wildcard $(ARDUINO_CORE_PATH)/$(1)*.c) \
		       $(wildcard $(ARDUINO_CORE_PATH)/$(1)*.S) 
  REQUIRED_USER_LIBS = $(notdir $(patsubst %/, %, $(REQUIRED_USER_LIBDIRS))) 
  IGNORE_CORE_FILES  = $(foreach lib, $(REQUIRED_USER_LIBS), \
		         $(call matching_corefiles,$(lib)))
endif

CORE_C_SRCS   = $(call remove, \
		         $(wildcard $(ARDUINO_CORE_PATH)/*.c) \
		         $(wildcard $(ARDUINO_CORE_PATH)/avr-libc/*.c), \
			 $(IGNORE_CORE_FILES))
BASE_CPP_SRCS = $(call remove, \
			 $(wildcard $(ARDUINO_CORE_PATH)/*.cpp), \
			 $(IGNORE_CORE_FILES))
CORE_AS_SRCS  = $(wildcard $(ARDUINO_CORE_PATH)/*.S)


CORE_CPP_SRCS     = $(filter-out %main.cpp, $(BASE_CPP_SRCS))
CORE_OBJ_FILES    = $(CORE_C_SRCS:.c=.o) $(CORE_CPP_SRCS:.cpp=.o) \
		      $(CORE_AS_SRCS:.S=.o)
CORE_OBJECTS      = $(patsubst $(ARDUINO_CORE_PATH)/%,  \
                      $(OBJDIR)/core/%,$(CORE_OBJ_FILES))
CORE_LIB          = $(OBJDIR)/libcore.a


###########
# code_dir targets

# Default target for a code directory.
code_dir: $(BOARD_DIR)/Makefile.board $(CURDIR)/Makefile $(TARGET_HEX)

# Dependency for code targets to ensure that we are in an appropriate
# directory for that target.
check_code_dir:
	@if [ "x$(BUILD_TYPE)" != "xcode_dir" ]; then \
	    echo "\n  ERROR: Not in a code directory\n" 1>&2; \
	    exit 2; fi

# The following uses recursive make for check_code_dir rather than as
# a dependency, as making it a dependency will make it necessary to
# always rebuild the target.
$(CORE_LIB): $(CORE_OBJECTS) $(LIB_OBJECTS) $(USERLIB_OBJECTS)
	$(MAKE) -f $(ROOT_MAKEFILE) --no-print-directory check_code_dir
	$(FEEDBACK) AR $(notdir $(USERLIB_OBJECTS) \
		$(CORE_OBJECTS) $(LIB_OBJECTS))
	$(AT) $(AR) rcs $@ $(USERLIB_OBJECTS) $(CORE_OBJECTS) $(LIB_OBJECTS) 	

$(TARGET_ELF): $(USER_OBJECTS) $(CORE_LIB)
	$(MAKE) -f $(ROOT_MAKEFILE) --no-print-directory check_code_dir
	$(FEEDBACK)  LD $(notdir $(USER_OBJECTS) $(CORE_LIB))
	$(AT) $(CC) $(LDFLAGS) -o $@ $(USER_OBJECTS) $(CORE_LIB) \
	    -lc -lm $(LINKER_SCRIPTS)

$(TARGET_HEX): $(TARGET_ELF)
	$(FEEDBACK) OBJCOPY "(hex)" $(notdir $<)
	$(AT) $(OBJCOPY) -O ihex -R .eeprom $< $@
	$(AT)$(call avr_size,$<,$@)
	@$(CHECK_SIZE)

$(TARGET_EEP): $(TARGET_ELF)
	$(FEEDBACK) OBJCOPY "(eep)" $(notdir $<)
	-$(AT) $(OBJCOPY) -j .eeprom --set-section-flags=.eeprom='alloc,load' \
		--no-change-warnings --change-section-lma .eeprom=0 \
		-O ihex $< $@

size:   $(TARGET_HEX) $(TARGET_ELF)
	$(call avr_size, $(TARGET_HEX), $(TARGET_ELF))

verify_size: $(TARGET_HEX) $(TARGET_ELF)
	$(AT) $(CHECK_SIZE)


###########
# Compilation, etc, flags

OPTIMIZATION_LEVEL = s
ifdef DEBUG
  OPTIMIZATION_FLAGS = $(DEBUG_FLAGS)
else
  OPTIMIZATION_FLAGS = -O$(OPTIMIZATION_LEVEL)
endif

# Flags based on our system configuration and our selected board,
# which will already have been determined and defined in files
# included above.
# The -I flags for the preprocessors
ARDUINO_LIB_FLAGS = $(patsubst %, -I%, $(ARDUINO_LIB_DIRS))
USER_LIB_FLAGS = $(patsubst %, -I%, $(USER_LIB_DIRS))
INCLUSION_FLAGS =  $(ARDUINO_HEADER_DIR_FLAGS) $(USER_LIB_FLAGS) \
	$(ARDUINO_LIB_FLAGS)

CFLAGS   += $(INCLUSION_FLAGS) $(OPTIMIZATION_FLAGS)
CXXFLAGS += $(INCLUSION_FLAGS) $(OPTIMIZATION_FLAGS)
LDFLAGS  += -Wl,--gc-sections -Wl,--fatal-warnings -Werror \
              -O$(OPTIMIZATION_LEVEL) -flto -fuse-linker-plugin

# VPATH provides the path to our library sources.  This allows fewer
# explicit rules to be required.
VPATH = $(REQUIRED_LIBDIRS) $(REQUIRED_USER_LIBDIRS)


###########
# Pattern-based rules

# Helpers for feedback:
LOCAL_LIB = `(echo $< | grep -q $(LIBDIR)) && echo "<user libs>/"`
SYSTEM_LIB = `(echo $< | grep -q $(ARDUINO_LIB_PATH)) && echo "<system libs>/"`
LIBPATH = $(LOCAL_LIB)$(SYSTEM_LIB)

# Objects (and deps) from local source C++ files.
$(OBJDIR)/%.o $(OBJDIR)/%.d: %.cpp
	@mkdir -p $(dir $@)
	$(FEEDBACK)  C++ $(LIBPATH)$(notdir $<)
	$(AT) $(CXX) -c -MMD $(CXXFLAGS) $< -o $(basename $@).o

# Objects (and deps) from local source C files.
$(OBJDIR)/%.o $(OBJDIR)/%.d: %.c
	@mkdir -p $(dir $@)
	$(FEEDBACK) CC $(LIBPATH)$(notdir $<)
	$(AT) $(CC) -c -MMD $(CXXFLAGS) $< -o $(basename $@).o

# Core objects from C++ files.
$(OBJDIR)/core/%.o: $(ARDUINO_CORE_PATH)/%.cpp
	@mkdir -p $(dir $@)
	$(FEEDBACK) C++ "<core lib>"/$(notdir $<)
	$(AT) $(CXX) -c -MMD $(CXXFLAGS) $< -o $@

# Core objects from C files
$(OBJDIR)/core/%.o: $(ARDUINO_CORE_PATH)/%.c
	@mkdir -p $(dir $@)
	$(FEEDBACK) CC "<core lib>"/$(notdir $<)
	$(AT) $(CC) -c -MMD $(CFLAGS) $< -o $@


###########
# Serial monitor stuff

# List of possible baud rates.  We look in our code for instances of
# these strings in order to try to find a suitable default.
ifndef MONITOR_BAUD
   SPEEDS = 300 1200 2400 4800 9600 14400 19200 28800 38400 57600 115200
endif

# Figure out the baud rate for our monitor.  If manually provided, we
# use that, otherwise we try to find a string in the code that looks
# promising, otherwise we default to 9600.  This automatic
# determination of speed seems pretty fragile but is suprisingly
# effective.  If we get it wrong, the user can supply it manually.
.baud:
	$(AT)if [ "x$(MONITOR_BAUD)" = "x" ]; then \
	  speed=`grep "\($(subst $(space),\|,$(SPEEDS))\)" $(USER_SOURCES) | \
	    head -1 | sed -e 's/[^0-9]*\([0-9][0-9]*\).*/\1/'`; \
	  if [ "x$${speed}" = "x" ]; then \
	    echo 9600; \
	  else \
	    echo $${speed}; \
	  fi; \
	else \
	    echo $(MONITOR_BAUD); \
	fi >$@

# Run a serial monitor in screen.
monitor: check_device_path .baud
	@$(FEEDBACK) "Running screen: C-a k to exit"
	$(AT)screen $(DEVICE_PATH) `cat .baud`

# Ensure there is no screen connected to the DEVICE.  Kill the screen
# if KILLSCREEN has been provided.
no_screen:
	@procs=`screen -ls | grep Attached | \
		sed -e 's/^[ \t]*\([0-9]*\).*/\1/'`; \
	screenproc=`for p in $${procs}; do \
	  ps -fp $$p | grep $(DEVICE_PATH); done | awk '{print $$2}'`;	\
	if [ "x$${screenproc}" != "x" ]; then \
	  if [ "x$(KILLSCREEN)" = "x" ]; then \
	    echo "\n  ERROR: monitor is attached to $(DEVICE_PATH)" 1>&2; \
	    echo "    (Try KILLSCREEN=y)" 1>&2; \
	    exit 3; \
	  else \
	    echo "Killing attached screen..."; \
	    scr=`screen -ls | grep "$${screenproc}\." | awk '{print $$1}'`; \
	    screen -S $${scr} -p 0 -X quit; sleep 1; \
	  fi; \
	fi


###########
# Makefile targets
# These are used to help maintain the build system.
# This is quite recursive so will be slowish.

makefiles: makefiles_$(BUILD_TYPE)
	@true

makefiles_root_dir makefiles_board_dir: $(CURDIR)/Makefile
	@echo Checking makefiles in `pwd`
	$(AT) for i in $(EACHDIR); do \
            ( cd $$i && \
	    $(MAKE) --no-print-directory -k -f $(MAKEFILEPATH) \
	      makefiles NODEPS=y) ; \
	done

makefiles_code_dir: $(CURDIR)/Makefile
	@echo Checking makefiles in `pwd`

makefiles_test:
	@echo Checking makefiles in `pwd`
	$(AT) $(MAKE) --no-print-directory -k -f $(ROOTDIR)/Makefile.test \
	  makefiles NODEPS=y

makefiles_unknown:
	@true # Quietly do nothing

# Create a Makefile for a board or code directory.  This allows make
# to be run in this directory without needing to specify the makefile
# with -f.
$(CODE_DIR)/Makefile $(BOARD_DIR)/Makefile $(ROOTDIR)/docs/Makefile:
	$(FEEDBACK) Creating $@...
	@echo "include $(ROOTDIR)/Makefile" >$@


###########
# Documentation targets

# doxy.tag, the tagfile generated by Doxygen is used as a proxy for
# the Doxgen output.
doxy.tag: $(DOC_SOURCES)
	@mkdir -p html 2>/dev/null
	@rm -rf html/*
	@$(FEEDBACK) "DOXYGEN <all source files>"
	$(AT)doxygen Doxyfile || \
	  (echo "Doxygen fails: is it installed?"; exit 2)

docs:
	cd $(ROOTDIR); make --no-print-directory doxy.tag


###########
# clean targets
# for cleaning up after ourselves.

# autom4te.cache 
EACHDIR = `find . -maxdepth 1 -type d | grep -v '^\.$$' | \
	      grep -v '/\.' | grep -v '^./\(autom4\|m4\)'`
CONFIG_FILES = autom4te.cache config.log config.status
# True if a file called Makefile exists and appears to have been
# automatically generated by this makefile.
AUTOGENERATED_MAKEFILE = test -f Makefile && \
	grep -sqh "^include" Makefile && \
	test "1" = "`wc -l <Makefile`"

garbage += \\\#*  .\\\#*  *~  *.orig  *.rej  core 

clean: clean_$(BUILD_TYPE)

clean_code_dir:
	@echo Cleaning `pwd`...
	@rm -rf $(OBJDIR) $(garbage)

clean_board_dir:
	@echo Cleaning `pwd`...
	@rm -rf $(garbage) 
	@for i in $(EACHDIR); do \
	    ( cd $$i && \
	    $(MAKE) --no-print-directory -f $(MAKEFILEPATH) clean NODEPS=y) ; \
	done

clean_root_dir:
	@echo Cleaning `pwd`...
	@rm -rf $(garbage) html doxy.tag
	@for i in $(EACHDIR); do \
	    (cd $$i && \
	    $(MAKE) --no-print-directory -f $(MAKEFILEPATH) clean NODEPS=y) ; \
	done

distclean_test:
	@$(MAKE) --no-print-directory -f $(ROOTDIR)/Makefile.test distclean

clean_test:
	@$(MAKE) --no-print-directory -f $(ROOTDIR)/Makefile.test clean

clean_unknown:
	@echo Cleaning `pwd`...
	@rm -rf $(garbage)
	@for i in $(EACHDIR); do \
	    (cd $$i && \
	    $(MAKE) --no-print-directory -f $(MAKEFILEPATH) clean NODEPS=y) ; \
	done

distclean: distclean_$(BUILD_TYPE)

distclean_root_dir:
	@echo Steam-cleaning `pwd`...
	@rm -rf $(garbage) $(CONFIG_FILES) configure configure_board \
		Makefile.global
	@for i in $(EACHDIR); do \
	    (cd $$i && \
	    $(MAKE) --no-print-directory -f $(MAKEFILEPATH) distclean NODEPS=y) ; \
	done

distclean_board_dir:
	@echo Steam-cleaning `pwd`...
	@rm -rf $(garbage) Makefile.board
	@($(AUTOGENERATED_MAKEFILE) && rm -f Makefile) || true
	@for i in $(EACHDIR); do \
	    (cd $$i && \
	    $(MAKE) --no-print-directory -f $(MAKEFILEPATH) distclean NODEPS=y) ; \
	done

distclean_code_dir:
	@echo Steam-cleaning `pwd`...
	@rm -rf $(garbage) $(OBJDIR)
	@($(AUTOGENERATED_MAKEFILE) && rm -f Makefile) || true

distclean_unknown:
	@echo Steam-cleaning `pwd`...
	@rm -rf $(garbage)
	@for i in $(EACHDIR); do \
	    (cd $$i && \
	    $(MAKE) --no-print-directory -f $(MAKEFILEPATH) distclean NODEPS=y) ; \
	done


###########
# Miscelaneous

# Show the list of supported boards.
show_boards:
	@echo "\n        Supported Arduino Board Types"
	@echo =================================================================
	@cat $(BOARDS_TXT) /dev/null | grep -E '^[a-zA-Z0-9_\-]+.name' | \
	    sort -uf | sed 's/.name=/:/' | column -s: -t


###########
# Help

# Provide a list of the most important targets buildable by this
# makefile.  Makefiles in subdirs can add to the help.
# TODO: Describe how to do this.
do_help: $(SUBDIRS:%=%_help)
	@echo "help        - list major makefile targets"
	@echo "clean       - remove all intermediate, backup and target files"
	@echo "distclean   - as clean plus all auto-generated build files"
	@echo "reset       - reset a connected Arduino"
	@echo "upload      - upload project code to connected Arduino"
	@echo "show_boards - list of all supported boards"
	@echo "size        - give the size of the current executable"
	@echo "all         - build everything appropriate to the current dir"
	@echo "makefiles   - create helper makefiles in appropriate dirs"
	@echo "monitor     - use screen as a serial monitor."
	@echo "devices     - list possible devices."
	@echo "list        - list of all explicit targets."

# Target that describes what this makefile can build for you.
help:
	@echo "Major targets of this makefile:"
	@$(MAKE) --no-print-directory do_help | sort | sed -e 's/^/ /'
	@echo
	@echo "Useful variables that may be defined on the command line:"
	@echo "  VERBOSE      - show full compilation, etc commands"
	@echo "  QUIET        - do not show size of executable"
	@echo "  BOARD_TYPE   - define type of Arduino device"
	@echo "                 (eg BOARD_TYPE=pro328)"
	@echo "  MONITOR_BAUD - baud rate for serial monitor"
	@echo "  DEVICE_PATH  - the serial device for upload and monitor"
	@echo "                 (currently $(DEVICE_PATH))"
	@echo
	@echo "Eg: make <target> VERBOSE=y"

# List of all explicit targets.
# I should be giving credit to someone for this.  I found it on the
# internet, can't remember where.
list:
	@$(MAKE) -pRrq -f $(ROOT_MAKEFILE) : 2>/dev/null | \
	    awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

