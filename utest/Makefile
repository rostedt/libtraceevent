# SPDX-License-Identifier: LGPL-2.1

include $(src)/scripts/utils.mk

TARGETS = $(bdir)/trace-utest

OBJS =
OBJS += trace-utest.o
OBJS += traceevent-utest.o

LIBS += -lcunit				\
	-ldl				\
	$(LIBTRACEEVENT_STATIC)

OBJS := $(OBJS:%.o=$(bdir)/%.o)
DEPS := $(OBJS:$(bdir)/%.o=$(bdir)/.%.d)

$(OBJS): | $(bdir)
$(DEPS): | $(bdir)

$(bdir)/trace-utest: $(OBJS) $(LIBTRACEEVENT_STATIC)
	$(Q)$(do_app_build)

$(bdir)/%.o: %.c
	$(Q)$(call do_fpic_compile)

$(DEPS): $(bdir)/.%.d: %.c
	$(Q)$(CC) -M $(CPPFLAGS) $(CFLAGS) $< > $@
	$(Q)$(CC) -M -MT $(bdir)/$*.o $(CPPFLAGS) $(CFLAGS) $< > $@

$(OBJS): $(bdir)/%.o : $(bdir)/.%.d

dep_includes := $(wildcard $(DEPS))

test: $(TARGETS)

clean:
	$(Q)$(call do_clean,$(TARGETS) $(bdir)/*.o $(bdir)/.*.d)
