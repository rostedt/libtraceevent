# SPDX-License-Identifier: LGPL-2.1

include $(src)/scripts/utils.mk

OBJS =
OBJS += event-parse-api.o
OBJS += event-parse.o
OBJS += event-plugin.o
OBJS += kbuffer-parse.o
OBJS += parse-filter.o
OBJS += parse-utils.o
OBJS += tep_strerror.o
OBJS += trace-seq.o

OBJS := $(OBJS:%.o=$(bdir)/%.o)
DEPS := $(OBJS:$(bdir)/%.o=$(bdir)/.%.d)

$(bdir)/%.o: %.c
	$(Q)$(call do_fpic_compile)

$(LIBTRACEEVENT_STATIC): $(OBJS)
	$(Q)$(call do_build_static_lib)

$(LIBTRACEEVENT_SHARED): $(OBJS)
	$(Q)$(call do_compile_shared_library,$(notdir $(LIBTRACEEVENT_SHARED_VERSION)))

$(LIBTRACEEVENT_SHARED_VERSION): $(LIBTRACEEVENT_SHARED)
	@ln -sf $(<F) $@

$(LIBTRACEEVENT_SHARED_SO): $(LIBTRACEEVENT_SHARED_VERSION)
	@ln -sf $(<F) $@

libtraceevent.so: $(LIBTRACEEVENT_SHARED_SO)

libtraceevent: $(libtraceevent-y)
	$(Q)$(MAKE) $(build)=libtraceevent

$(DEPS): $(bdir)/.%.d: %.c
	$(Q)$(CC) -M -MT $(bdir)/$*.o $(CPPFLAGS) $(CFLAGS) $< > $@

$(OBJS): $(bdir)/%.o : $(bdir)/.%.d

$(OBJS): | $(bdir)
$(DEPS): | $(bdir)

clean:
	$(Q)$(call do_clean,$(OBJS) $(DEPS))

dep_includes := $(wildcard $(DEPS))

ifneq ($(dep_includes),)
  include $(dep_includes)
endif

.PHONY: $(LIBTRACEEVENT_SHARED_SO) $(LIBTRACEEVENT_STATIC)
