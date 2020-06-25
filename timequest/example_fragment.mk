# An example of how you might include these scripts in your project Makefile


# some definitions
PROJECT_NAME=MyFPGA	# needed to run Timequest
# only for the top level makefile, not needed by the scripts
QUARTUS_UTILS=./path/to/quartus_util

# put your primary rule first
all:	build_it | check_passed_timing

# include the timequest makefile /after/ your primary rule
include $(QUARTUS_UTILS)/timequest/timequest.mk

# any other rules you like
build_it:
	@echo "Compiling"
	quartus_sh --flow compile $(PROJECT_NAME)

