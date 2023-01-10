# SPDX-License-Identifier: GPL-2.0
# libtraceevent version
EP_VERSION = 1
EP_PATCHLEVEL = 7
EP_EXTRAVERSION = 1
EVENT_PARSE_VERSION = $(EP_VERSION).$(EP_PATCHLEVEL).$(EP_EXTRAVERSION)

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
libdir ?= $(prefix)/$(libdir_relative)
man_dir ?= $(prefix)/share/man
man_dir_SQ = '$(subst ','\'',$(man_dir))'
pkgconfig_dir ?= $(word 1,$(shell $(PKG_CONFIG) 		\
			--variable pc_path pkg-config | tr ":" " "))
includedir_relative = include/traceevent
includedir = $(prefix)/$(includedir_relative)
includedir_SQ = '$(subst ','\'',$(includedir))'

export man_dir man_dir_SQ INSTALL
export DESTDIR DESTDIR_SQ
export EP_VERSION EVENT_PARSE_VERSION

# copy a bit from Linux kbuild

ifeq ("$(origin V)", "command line")
  VERBOSE = $(V)
endif
ifndef VERBOSE
  VERBOSE = 0
endif

SILENT := $(if $(findstring s,$(filter-out --%,$(MAKEFLAGS))),1)

ifeq ("$(origin O)", "command line")

  saved-output := $(O)
  BUILD_OUTPUT := $(shell cd $(O) && /bin/pwd)
  $(if $(BUILD_OUTPUT),, \
    $(error output directory "$(saved-output)" does not exist))

else
  BUILD_OUTPUT = $(CURDIR)
endif

srctree		:= $(if $(BUILD_SRC),$(BUILD_SRC),$(CURDIR))
objtree		:= $(BUILD_OUTPUT)
src		:= $(srctree)
obj		:= $(objtree)
bdir		:= $(obj)/lib

export prefix src obj bdir

PKG_CONFIG_SOURCE_FILE = libtraceevent.pc
PKG_CONFIG_FILE := $(addprefix $(obj)/,$(PKG_CONFIG_SOURCE_FILE))

export Q SILENT VERBOSE EXT

# Include the utils
include scripts/utils.mk

include $(src)/scripts/features.mk

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

LIBTRACEEVENT_STATIC = $(bdir)/libtraceevent.a
LIBTRACEEVENT_SHARED = $(bdir)/libtraceevent.so.$(EVENT_PARSE_VERSION)

EP_HEADERS_DIR = $(src)/include/traceevent

INCLUDES = -I. -I $(srctree)/include -I $(EP_HEADERS_DIR) $(CONFIG_INCLUDES)

export LIBTRACEEVENT_STATIC LIBTRACEEVENT_SHARED EP_HEADERS_DIR

# Set compile option CFLAGS
ifdef EXTRA_CFLAGS
  CFLAGS := $(EXTRA_CFLAGS)
else
  CFLAGS := -g -Wall
endif

LIBS ?= -ldl
export LIBS

set_plugin_dir := 1

# Set plugin_dir to prefered global plugin location
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

# Make sure 32 bit stat() works on large file systems
override CFLAGS += -D_FILE_OFFSET_BITS=64

ifeq ($(VERBOSE),1)
  Q =
else
  Q = @
endif

# Disable command line variables (CFLAGS) override from top
# level Makefile (perf), otherwise build Makefile will get
# the same command line setup.
MAKEOVERRIDES=

export srctree CC LD CFLAGS V
build := -f $(srctree)/build/Makefile.build dir=. obj

LIB_TARGET := libtraceevent.so libtraceevent.a

CMD_TARGETS = $(LIB_TARGET) $(PKG_CONFIG_FILE)

TARGETS = $(CMD_TARGETS)

all: all_cmd plugins

$(bdir):
	$(Q)mkdir -p $(bdir)

LIB_TARGET  = libtraceevent.a libtraceevent.so
LIB_INSTALL = libtraceevent.a libtraceevent.so*
LIB_INSTALL := $(addprefix $(bdir)/,$(LIB_INSTALL))

LIBTRACEEVENT_SHARED_SO = $(bdir)/libtraceevent.so
LIBTRACEEVENT_SHARED_VERSION = $(bdir)/libtraceevent.so.$(EP_VERSION)

export LIBTRACEEVENT_SHARED_SO LIBTRACEEVENT_SHARED_VERSION

all_cmd: $(CMD_TARGETS)

libtraceevent.a: $(bdir) $(LIBTRACEEVENT_STATIC)
libtraceevent.so: $(bdir) $(LIBTRACEEVENT_SHARED)

libs: libtraceevent.a libtraceevent.so

$(LIBTRACEEVENT_STATIC): force
	$(Q)$(call descend,$(src)/src,$@)

$(LIBTRACEEVENT_SHARED): force
	$(Q)$(call descend,$(src)/src,libtraceevent.so)

$(bdir)/libtraceevent.so: $(bdir)/libtraceevent.so.$(EP_VERSION)
	@ln -sf $(<F) $@

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

VERSION_FILE = $(obj)/ep_version.h

$(VERSION_FILE): force
	$(Q)$(N)$(call update_version.h)

define update_dir
  (echo $1 > $@.tmp;				\
   if [ -r $@ ] && cmp -s $@ $@.tmp; then	\
     rm -f $@.tmp;				\
   else						\
     echo '  UPDATE                 $@';	\
     mv -f $@.tmp $@;				\
   fi);
endef

UTEST_DIR = utest

test:	force $(LIBTRACEEVENT_STATIC)
	$(Q)$(call descend,$(UTEST_DIR),test)

VIM_TAGS = $(obj)/tags
EMACS_TAGS = $(obj)/TAGS

$(VIM_TAGS): force
	$(RM) $(VIM_TAGS)
	find $(src) -name '*.[ch]' | (cd $(obj) && xargs ctags --extra=+f --c-kinds=+px \
	--regex-c++='/_PE\(([^,)]*).*/TEP_ERRNO__\1/')

tags: $(VIM_TAGS)

$(EMACS_TAGS): force
	$(RM) $(EMACS_TAGS)
	find $(src) -name '*.[ch]' | (cd $(obj) && xargs etags \
	--regex='/_PE(\([^,)]*\).*/TEP_ERRNO__\1/')

TAGS: $(EMACS_TAGS)

define build_prefix
	(echo $1 > $@.tmp;	\
	if [ -r $@ ] && cmp -s $@ $@.tmp; then				\
		rm -f $@.tmp;						\
	else								\
		$(PRINT_GEN)						\
		mv -f $@.tmp $@;					\
	fi);
endef

BUILD_PREFIX := $(obj)/build_prefix

$(BUILD_PREFIX): force
	$(Q)$(call build_prefix,$(prefix))

define do_make_pkgconfig_file
	cp -f ${PKG_CONFIG_SOURCE_FILE}.template ${PKG_CONFIG_FILE};	\
	sed -i "s|INSTALL_PREFIX|${1}|g" ${PKG_CONFIG_FILE}; 		\
	sed -i "s|LIB_VERSION|${EVENT_PARSE_VERSION}|g" ${PKG_CONFIG_FILE}; \
	sed -i "s|LIB_DIR|${libdir_relative}|g" ${PKG_CONFIG_FILE}; \
	sed -i "s|HEADER_DIR|$(includedir_relative)|g" ${PKG_CONFIG_FILE};
endef

$(PKG_CONFIG_FILE) : ${PKG_CONFIG_SOURCE_FILE}.template $(BUILD_PREFIX) $(VERSION_FILE)
	$(Q)$(print_gen)$(call do_make_pkgconfig_file,$(prefix))

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
			$(CC) -o $(objtree)/test $(srctree)/test.c -I $(includedir_SQ) \
				-L $(libdir_SQ) -ltraceevent &> /dev/null; \
			if ! $(objtree)/test &> /dev/null; then \
				$(call print_install, trace.conf, $(LD_SO_CONF_PATH)) \
				echo $(libdir_SQ) >> $(LD_SO_CONF_PATH)/trace.conf; \
				$(LDCONFIG); \
			fi; \
			$(RM) $(objtree)/test; \
		fi; \
	fi
endef
else
# If installing to a location for another machine or package, do not bother
# with running ldconfig.
define install_ld_config
endef
endif # DESTDIR = ""

install: install_libs install_plugins

install_libs: libs install_headers install_pkgconfig
	$(Q)$(call do_install,$(LIBTRACEEVENT_SHARED),$(libdir_SQ)); \
		cp -fpR $(LIB_INSTALL) $(DESTDIR)$(libdir_SQ)
	$(Q)$(call install_ld_config)

install_pkgconfig: $(PKG_CONFIG_FILE)
	$(Q)$(call do_install_pkgconfig_file,$(prefix))

install_headers:
	$(Q)$(call do_install,$(EP_HEADERS_DIR)/event-parse.h,$(includedir_SQ),644);
	$(Q)$(call do_install,$(EP_HEADERS_DIR)/event-utils.h,$(includedir_SQ),644);
	$(Q)$(call do_install,$(EP_HEADERS_DIR)/trace-seq.h,$(includedir_SQ),644);
	$(Q)$(call do_install,$(EP_HEADERS_DIR)/kbuffer.h,$(includedir_SQ),644)

install: install_libs

clean: clean_plugins clean_src
	$(Q)$(call do_clean,\
	    $(VERSION_FILE) $(obj)/tags $(obj)/TAGS $(PKG_CONFIG_FILE) \
	    $(LIBTRACEEVENT_STATIC) $(LIBTRACEEVENT_SHARED) \
	    $(LIBTRACEEVENT_SHARED_SO) $(LIBTRACEEVENT_SHARED_VERSION) \
	    $(BUILD_PREFIX))

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
doc: check_doc
	$(Q)$(call descend,$(src)/Documentation,)

PHONY += doc-clean
doc-clean:
	$(MAKE) -C $(src)/Documentation clean

PHONY += doc-install
doc-install:
	$(Q)$(call descend,$(src)/Documentation,install)

check_doc: force
	$(Q)$(src)/check-manpages.sh $(src)/Documentation


PHONY += doc-uninstall
doc-uninstall:
	$(MAKE) -C $(src)/Documentation uninstall

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
	$(Q)$(call descend,plugins,)

PHONY += install_plugins
install_plugins: plugins
	$(Q)$(call descend,plugins,install)

samples: libtraceevent.a force
	$(Q)$(call descend,$(src)/samples,all)

PHONY += clean_plugins
clean_plugins:
	$(Q)$(call descend_clean,plugins)

PHONY += clean_src
clean_src:
	$(Q)$(call descend_clean,src)

force:

# Declare the contents of the .PHONY variable as phony.  We keep that
# information in a variable so we can use it in if_changed and friends.
.PHONY: $(PHONY)
