/* SPDX-License-Identifier: LGPL-2.1 */
/*
 * Copyright (C) 2010 Red Hat Inc, Steven Rostedt <srostedt@redhat.com>
 *
 */
#ifndef __UTIL_H
#define __UTIL_H

#include <ctype.h>
#include <stdarg.h>
#include <stdbool.h>

void tep_warning(const char *fmt, ...);
void tep_info(const char *fmt, ...);
/* Can be overridden */
int tep_vprint(const char *name, enum tep_loglevel level,
	       bool print_err, const char *fmt, va_list ap);

#define min(x, y) ({				\
	typeof(x) _min1 = (x);			\
	typeof(y) _min2 = (y);			\
	(void) (&_min1 == &_min2);		\
	_min1 < _min2 ? _min1 : _min2; })

static inline char *strim(char *string)
{
	char *ret;

	if (!string)
		return NULL;
	while (*string) {
		if (!isspace(*string))
			break;
		string++;
	}
	ret = string;

	string = ret + strlen(ret) - 1;
	while (string > ret) {
		if (!isspace(*string))
			break;
		string--;
	}
	string[1] = 0;

	return ret;
}

static inline int has_text(const char *text)
{
	if (!text)
		return 0;

	while (*text) {
		if (!isspace(*text))
			return 1;
		text++;
	}

	return 0;
}

#endif
