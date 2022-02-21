# SPDX-License-Identifier: LGPL-2.1

include $(src)/scripts/utils.mk

TARGETS :=
TARGETS += test-event

sdir := $(obj)/samples

TARGETS := $(patsubst %,$(sdir)/%,$(TARGETS))

all: $(TARGETS)

$(sdir):
	@mkdir -p $(sdir)

$(TARGETS): $(sdir) $(LIBTRACEEVENT_STATIC)

$(sdir)/%: $(bdir)/%.o
	$(call do_sample_build,$@,$<)

$(bdir)/%.o: $(bdir)/%.c
	$(Q)$(CC) -o $@ -c $< $(CFLAGS) $(INCLUDES)

clean:
	$(Q)$(call do_clean,$(sdir)/*)
