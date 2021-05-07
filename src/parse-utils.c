// SPDX-License-Identifier: LGPL-2.1
/*
 * Copyright (C) 2010 Red Hat Inc, Steven Rostedt <srostedt@redhat.com>
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <errno.h>

#include "event-parse.h"

#define __weak __attribute__((weak))

static int log_level = TEP_LOG_CRITICAL;

/**
 * tep_set_loglevel - set log level of the library
 * @level: desired level of the library messages
 */
void tep_set_loglevel(enum tep_loglevel level)
{
	log_level = level;
}

int __weak tep_vwarning(const char *name, const char *fmt, va_list ap)
{
	int ret = errno;

	if (errno)
		perror(name);

	fprintf(stderr, "  ");
	vfprintf(stderr, fmt, ap);
	fprintf(stderr, "\n");

	return ret;
}

void __weak tep_warning(const char *fmt, ...)
{
	va_list ap;

	if (log_level < TEP_LOG_WARNING)
		return;

	va_start(ap, fmt);
	tep_vwarning("libtraceevent", fmt, ap);
	va_end(ap);
}

void __vpr_stat(const char *fmt, va_list ap)
{
	vprintf(fmt, ap);
	printf("\n");
}

void __pr_stat(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	__vpr_stat(fmt, ap);
	va_end(ap);
}

void __weak vpr_stat(const char *fmt, va_list ap)
{
	__vpr_stat(fmt, ap);
}

void __weak pr_stat(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	__vpr_stat(fmt, ap);
	va_end(ap);
}
