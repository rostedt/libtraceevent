
include ../scripts/Makefile.include

build := -f $(srctree)/build/Makefile.build dir=. obj

libtraceevent: $(libtraceevent-y)
	$(Q)$(MAKE) $(build)=libtraceevent

clean:
	$(call QUIET_CLEAN, trace_src) \
		$(RM) $(OUTPUT)*.o $(OUTPUT)*~ .*.d .*.cmd
