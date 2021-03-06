# SPDX-License-Identifier: GPL-2.0
# libtraceevent version
EP_VERSION = 1
EP_PATCHLEVEL = 3
EP_EXTRAVERSION = 3

MAKEFLAGS += --no-print-directory


# Makefiles suck: This macro sets a default value of $(2) for the
# variable named by $(1), unless the variable has been set by
# environment or command line. This is necessary for CC and AR
# because make sets default values, so the simpler ?= approach
# won't work as expected.
define allow-override
  $(if $(or $(findstring environment,$(origin $(1))),\
            $(findstring command line,$(origin $(1)))),,\
    $(eval $(1) = $(2)))
endef

# Allow setting CC and AR, or setting CROSS_COMPILE as a prefix.
$(call allow-override,CC,$(CROSS_COMPILE)gcc)
$(call allow-override,AR,$(CROSS_COMPILE)ar)
$(call allow-override,NM,$(CROSS_COMPILE)nm)
$(call allow-override,PKG_CONFIG,pkg-config)
$(call allow-override,LD_SO_CONF_PATH,/etc/ld.so.conf.d/)
$(call allow-override,LDCONFIG,ldconfig)

EXT = -std=gnu99
INSTALL = install

# Use DESTDIR for installing into a different root directory.
# This is useful for building a package. The program will be
# installed in this directory as if it was the root directory.
# Then the build tool can move it later.
DESTDIR ?=
DESTDIR_SQ = '$(subst ','\'',$(DESTDIR))'

LP64 := $(shell echo __LP64__ | ${CC} ${CFLAGS} -E -x c - | tail -n 1)
ifeq ($(LP64), 1)
  libdir_relative_temp = lib64
else
  libdir_relative_temp = lib
endif

libdir_relative ?= $(libdir_relative_temp)
prefix ?= /usr/local
libdir = $(prefix)/$(libdir_relative)
man_dir = $(prefix)/share/man
man_dir_SQ = '$(subst ','\'',$(man_dir))'
pkgconfig_dir ?= $(word 1,$(shell $(PKG_CONFIG) 		\
			--variable pc_path pkg-config | tr ":" " "))
includedir_relative = include/traceevent
includedir = $(prefix)/$(includedir_relative)
includedir_SQ = '$(subst ','\'',$(includedir))'

export man_dir man_dir_SQ INSTALL
export DESTDIR DESTDIR_SQ
export EVENT_PARSE_VERSION

include scripts/Makefile.include

PKG_CONFIG_SOURCE_FILE = libtraceevent.pc
PKG_CONFIG_FILE := $(addprefix $(OUTPUT),$(PKG_CONFIG_SOURCE_FILE))

# copy a bit from Linux kbuild

ifeq ("$(origin V)", "command line")
  VERBOSE = $(V)
endif
ifndef VERBOSE
  VERBOSE = 0
endif

ifeq ($(srctree),)
srctree := $(CURDIR)
#$(info Determined 'srctree' to be $(srctree))
endif

export prefix libdir

# Shell quotes
libdir_SQ = $(subst ','\'',$(libdir))
libdir_relative_SQ = $(subst ','\'',$(libdir_relative))

CONFIG_INCLUDES = 
CONFIG_LIBS	=
CONFIG_FLAGS	=

VERSION		= $(EP_VERSION)
PATCHLEVEL	= $(EP_PATCHLEVEL)
EXTRAVERSION	= $(EP_EXTRAVERSION)

OBJ		= $@
N		=

EVENT_PARSE_VERSION = $(EP_VERSION).$(EP_PATCHLEVEL).$(EP_EXTRAVERSION)

bdir = lib

export bdir

LIBTRACEEVENT_STATIC = $(bdir)/libtraceevent.a
LIBTRACEEVENT_SHARED = $(bdir)/libtraceevent.so.$(EVENT_PARSE_VERSION)

LIB_TARGET  = $(LIBTRACEEVENT_STATIC) $(bdir)/libtraceevent.so $(bdir)/libtraceevent.so.$(EP_VERSION) $(LIBTRACEEVENT_SHARED)
LIB_INSTALL = $(LIBTRACEEVENT_STATIC) $(bdir)/libtraceevent.so*
LIB_INSTALL := $(addprefix $(OUTPUT),$(LIB_INSTALL))

INCLUDES = -I. -I $(srctree)/include $(CONFIG_INCLUDES)

# Set compile option CFLAGS
ifdef EXTRA_CFLAGS
  CFLAGS := $(EXTRA_CFLAGS)
else
  CFLAGS := -g -Wall
endif

LIBS = -ldl

set_plugin_dir := 1

# Set plugin_dir to preffered global plugin location
# If we install under $HOME directory we go under
# $(HOME)/.local/lib/traceevent/plugins
#
# We dont set PLUGIN_DIR in case we install under $HOME
# directory, because by default the code looks under:
# $(HOME)/.local/lib/traceevent/plugins by default.
#
ifeq ($(plugin_dir),)
ifeq ($(prefix),$(HOME))
override plugin_dir = $(HOME)/.local/lib/traceevent/plugins
set_plugin_dir := 0
else
override plugin_dir = $(libdir)/traceevent/plugins
endif
export plugin_dir
endif

ifeq ($(set_plugin_dir),1)
PLUGIN_DIR = -DPLUGIN_DIR="$(plugin_dir)"
PLUGIN_DIR_SQ = '$(subst ','\'',$(PLUGIN_DIR))'
export PLUGIN_DIR PLUGIN_DIR_SQ
endif

# Append required CFLAGS
override CFLAGS += -fPIC
override CFLAGS += $(CONFIG_FLAGS) $(INCLUDES) $(PLUGIN_DIR_SQ)
override CFLAGS += $(udis86-flags) -D_GNU_SOURCE

ifeq ($(VERBOSE),1)
  Q =
else
  Q = @
endif

# Disable command line variables (CFLAGS) override from top
# level Makefile (perf), otherwise build Makefile will get
# the same command line setup.
MAKEOVERRIDES=

export srctree OUTPUT CC LD CFLAGS V
build := -f $(srctree)/build/Makefile.build dir=. obj

TE_IN      := $(OUTPUT)src/libtraceevent-in.o
LIB_TARGET := $(addprefix $(OUTPUT),$(LIB_TARGET))

CMD_TARGETS = $(LIB_TARGET) $(PKG_CONFIG_FILE)

TARGETS = $(CMD_TARGETS)

all: all_cmd plugins

all_cmd: $(CMD_TARGETS)

$(TE_IN): force
	$(Q)$(call descend,src,libtraceevent)

$(OUTPUT)$(LIBTRACEEVENT_SHARED): $(TE_IN)
	$(Q)mkdir -p $(OUTPUT)$(bdir)
	$(QUIET_LINK)$(CC) --shared $(LDFLAGS) $^ -Wl,-soname,libtraceevent.so.$(EP_VERSION) -o $@  $(LIBS)

$(OUTPUT)$(bdir)/libtraceevent.so: $(OUTPUT)$(bdir)/libtraceevent.so.$(EP_VERSION)
	@ln -sf $(<F) $@

$(OUTPUT)$(bdir)/libtraceevent.so.$(EP_VERSION): $(OUTPUT)$(LIBTRACEEVENT_SHARED)
	@ln -sf $(<F) $@

$(OUTPUT)$(LIBTRACEEVENT_STATIC): $(TE_IN)
	$(Q)mkdir -p $(OUTPUT)$(bdir)
	$(QUIET_LINK)$(RM) $@; $(AR) rcs $@ $^

$(OUTPUT)$(bdir)/%.so: $(OUTPUT)%-in.o
	$(QUIET_LINK)$(CC) $(CFLAGS) -shared $(LDFLAGS) -nostartfiles -o $@ $^ $(LIBS)

define make_version.h
  (echo '/* This file is automatically generated. Do not modify. */';		\
   echo \#define VERSION_CODE $(shell						\
   expr $(VERSION) \* 256 + $(PATCHLEVEL));					\
   echo '#define EXTRAVERSION ' $(EXTRAVERSION);				\
   echo '#define VERSION_STRING "'$(VERSION).$(PATCHLEVEL).$(EXTRAVERSION)'"';	\
   echo '#define FILE_VERSION '$(FILE_VERSION);					\
  ) > $1
endef

define update_version.h
  ($(call make_version.h, $@.tmp);		\
    if [ -r $@ ] && cmp -s $@ $@.tmp; then	\
      rm -f $@.tmp;				\
    else					\
      echo '  UPDATE                 $@';	\
      mv -f $@.tmp $@;				\
    fi);
endef

ep_version.h: force
	$(Q)$(N)$(call update_version.h)

VERSION_FILES = ep_version.h

define update_dir
  (echo $1 > $@.tmp;				\
   if [ -r $@ ] && cmp -s $@ $@.tmp; then	\
     rm -f $@.tmp;				\
   else						\
     echo '  UPDATE                 $@';	\
     mv -f $@.tmp $@;				\
   fi);
endef

tags:	force
	$(RM) tags
	find . -name '*.[ch]' | xargs ctags --extra=+f --c-kinds=+px \
	--regex-c++='/_PE\(([^,)]*).*/TEP_ERRNO__\1/'

TAGS:	force
	$(RM) TAGS
	find . -name '*.[ch]' | xargs etags \
	--regex='/_PE(\([^,)]*\).*/TEP_ERRNO__\1/'

define build_prefix
	(echo $1 > $@.tmp;	\
	if [ -r $@ ] && cmp -s $@ $@.tmp; then				\
		rm -f $@.tmp;						\
	else								\
		$(PRINT_GEN)						\
		mv -f $@.tmp $@;					\
	fi);
endef

BUILD_PREFIX := $(OUTPUT)build_prefix

$(BUILD_PREFIX): force
	$(Q)$(call build_prefix,$(prefix))

define do_install_mkdir
	if [ ! -d '$(DESTDIR_SQ)$1' ]; then		\
		$(INSTALL) -d -m 755 '$(DESTDIR_SQ)$1';	\
	fi
endef

define do_install
	$(call do_install_mkdir,$2);			\
	$(INSTALL) $(if $3,-m $3,) $1 '$(DESTDIR_SQ)$2'
endef

define do_make_pkgconfig_file
	cp -f ${PKG_CONFIG_SOURCE_FILE}.template ${PKG_CONFIG_FILE};	\
	sed -i "s|INSTALL_PREFIX|${1}|g" ${PKG_CONFIG_FILE}; 		\
	sed -i "s|LIB_VERSION|${EVENT_PARSE_VERSION}|g" ${PKG_CONFIG_FILE}; \
	sed -i "s|LIB_DIR|${libdir_relative}|g" ${PKG_CONFIG_FILE}; \
	sed -i "s|HEADER_DIR|$(includedir_relative)|g" ${PKG_CONFIG_FILE};
endef

$(PKG_CONFIG_FILE) : ${PKG_CONFIG_SOURCE_FILE}.template $(BUILD_PREFIX) $(VERSION_FILES)
	$(QUIET_GEN) $(call do_make_pkgconfig_file,$(prefix))

define do_install_pkgconfig_file
	if [ -n "${pkgconfig_dir}" ]; then 					\
		$(call do_install,$(PKG_CONFIG_FILE),$(pkgconfig_dir),644); 	\
	else 									\
		(echo Failed to locate pkg-config directory) 1>&2;		\
	fi
endef


ifeq ("$(DESTDIR)", "")
# If DESTDIR is not defined, then test if after installing the library
# and running ldconfig, if the library is visible by ld.so.
# If not, add the path to /etc/ld.so.conf.d/trace.conf and run ldconfig again.
define install_ld_config
	if $(LDCONFIG); then \
		if ! grep -q "^$(libdir)$$" $(LD_SO_CONF_PATH)/* ; then \
			$(CC) -o $(OUTPUT)test $(srctree)/test.c -I $(includedir_SQ) \
				-L $(libdir_SQ) -ltraceevent &>/dev/null; \
			if ! $(OUTPUT)test &> /dev/null; then \
				$(call PRINT_INSTALL, trace.conf) \
				echo $(libdir_SQ) >> $(LD_SO_CONF_PATH)/trace.conf; \
				$(LDCONFIG); \
			fi; \
			$(RM) $(OUTPUT)test; \
		fi; \
	fi
endef
else
# If installing to a location for another machine or package, do not bother
# with running ldconfig.
define install_ld_config
endef
endif # DESTDIR = ""

install_lib: all_cmd install_plugins install_headers install_pkgconfig
	$(call QUIET_INSTALL, $(LIB_TARGET)) \
		$(call do_install_mkdir,$(libdir_SQ)); \
		cp -fpR $(LIB_INSTALL) $(DESTDIR)$(libdir_SQ); \
		$(call install_ld_config)

install_pkgconfig: $(PKG_CONFIG_FILE)
	$(call QUIET_INSTALL, $(PKG_CONFIG_FILE)) \
		$(call do_install_pkgconfig_file,$(prefix))

install_headers:
	$(call QUIET_INSTALL, headers) \
		$(call do_install,src/event-parse.h,$(includedir_SQ),644); \
		$(call do_install,src/event-utils.h,$(includedir_SQ),644); \
		$(call do_install,src/trace-seq.h,$(includedir_SQ),644); \
		$(call do_install,src/kbuffer.h,$(includedir_SQ),644)

install: install_lib

clean: clean_plugins clean_src
	$(call QUIET_CLEAN, libtraceevent) \
		$(RM) $(OUTPUT)*.o $(OUTPUT)*~ $(TARGETS) $(OUTPUT)*.a $(OUTPUT)*.so $(VERSION_FILES) $(OUTPUT).*.d $(OUTPUT).*.cmd; \
		$(RM) TRACEEVENT-CFLAGS $(OUTPUT)tags $(OUTPUT)TAGS; \
		$(RM) $(PKG_CONFIG_FILE)
ifneq ($(OUTPUT),)
else
BUILD_OUTPUT := $(shell pwd)
endif

define build_uninstall_script
	$(Q)mkdir $(BUILD_OUTPUT)/tmp_build
	$(Q)$(MAKE) -C $(srctree) DESTDIR=$(BUILD_OUTPUT)/tmp_build/ O=$(BUILD_OUTPUT) $1 > /dev/null
	$(Q)find $(BUILD_OUTPUT)/tmp_build ! -type d -printf "%P\n" > $(BUILD_OUTPUT)/build_$2
	$(Q)$(RM) -rf $(BUILD_OUTPUT)/tmp_build
endef

build_uninstall: $(BUILD_PREFIX)
	$(call build_uninstall_script,install,uninstall)

$(BUILD_OUTPUT)/build_uninstall: build_uninstall

define uninstall_file
	if [ -f $(DESTDIR)/$1 -o -h $(DESTDIR)/$1 ]; then \
		$(call PRINT_UNINST,$(DESTDIR)$1)$(RM) $(DESTDIR)/$1; \
	fi;
endef

uninstall: $(BUILD_OUTPUT)/build_uninstall
	@$(foreach file,$(shell cat $(BUILD_OUTPUT)/build_uninstall),$(call uninstall_file,$(file)))

PHONY += doc
doc:
	$(call descend,Documentation)

PHONY += doc-clean
doc-clean:
	$(call descend,Documentation,clean)

PHONY += doc-install
doc-install:
	$(call descend,Documentation,install)

PHONY += doc-uninstall
doc-uninstall:
	$(call descend,Documentation,uninstall)

PHONY += help
help:
	@echo 'Possible targets:'
	@echo''
	@echo '  all                 - default, compile the library and the'\
				      'plugins'
	@echo '  plugins             - compile the plugins'
	@echo '  install             - install the library, the plugins,'\
					'the header and pkgconfig files'
	@echo '  clean               - clean the library and the plugins object files'
	@echo '  doc                 - compile the documentation files - man'\
					'and html pages, in the Documentation directory'
	@echo '  doc-clean           - clean the documentation files'
	@echo '  doc-install         - install the man pages'
	@echo '  doc-uninstall       - uninstall the man pages'
	@echo''

PHONY += plugins
plugins:
	$(call descend,plugins)

PHONY += install_plugins
install_plugins:
	$(call descend,plugins,install)

PHONY += clean_plugins
clean_plugins:
	$(call descend,plugins,clean)

PHONY += clean_src
clean_src:
	$(call descend,src,clean)

force:

# Declare the contents of the .PHONY variable as phony.  We keep that
# information in a variable so we can use it in if_changed and friends.
.PHONY: $(PHONY)
