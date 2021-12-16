// SPDX-License-Identifier: LGPL-2.1
/*
 * Copyright (C) 2020, VMware, Tzvetomir Stoyanov <tz.stoyanov@gmail.com>
 *
 * Modified from libtracefs to libtraceevent:
 *   Copyright (C) 2021, VMware, Steven Rostedt <rostedt@goodmis.org>
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <dirent.h>
#include <ftw.h>

#include <CUnit/CUnit.h>
#include <CUnit/Basic.h>

#include "event-parse.h"
#include "trace-seq.h"

#define TRACEEVENT_SUITE	"traceevent library"

#define DYN_STR_EVENT_SYSTEM		"irq"
#define DYN_STR_FIELD			"name"
#define DYN_STRING			"hello"
#define DYN_STRING_FMT			"irq=0 handler=hello"
static const char dyn_str_event[] =
	"name: irq_handler_entry\n"
	"ID: 1\n"
	"format:\n"
	"\tfield:unsigned short common_type;\toffset:0;\tsize:2;\tsigned:0;\n"
	"\tfield:unsigned char common_flags;\toffset:2;\tsize:1;\tsigned:0;\n"
	"\tfield:unsigned char common_preempt_count;\toffset:3;\tsize:1;\tsigned:0;\n"
	"\tfield:int common_pid;\toffset:4;\tsize:4;\tsigned:1;\n"
	"\n"
        "\tfield:int irq;\toffset:8;\tsize:4;\tsigned:1;\n"
        "\tfield:__data_loc char[] name;\toffset:12;\tsize:4;\tsigned:1;\n"
	"\n"
	"print fmt: \"irq=%d handler=%s\", REC->irq, __get_str(name)\n";

static char dyn_str_data[] = {
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	/* common type */		1, 0x00,
#else
	/* common type */		0x00, 1
#endif
	/* common flags */		0x00,
	/* common_preempt_count */	0x00,
	/* common_pid */		0x00, 0x00, 0x00, 0x00,
	/* irq */			0x00, 0x00, 0x00, 0x00,

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	/* name : offset */		16, 0x00,
	/* name : length */		6, 0x00,
#else
	/* name : length */		0x00, 6,
	/* name : offset */		0x00, 16,
#endif
	/* name */			'h', 'e', 'l', 'l', 'o', '\0',
	/* padding */			0x00, 0x00
};
static void *dyn_str_event_data = (void *)dyn_str_data;

static const char dyn_str_old_event[] =
	"name: irq_handler_entry\n"
	"ID: 2\n"
	"format:\n"
	"\tfield:unsigned short common_type;\toffset:0;\tsize:2;\n"
	"\tfield:unsigned char common_flags;\toffset:2;\tsize:1;\n"
	"\tfield:unsigned char common_preempt_count;\toffset:3;\tsize:1;\n"
	"\tfield:int common_pid;\toffset:4;\tsize:4;\n"
	"\n"
        "\tfield:int irq;\toffset:8;\tsize:4;\n"
        "\tfield:__data_loc name;\toffset:12;\tsize:2;\n"
	"\n"
	"print fmt: \"irq=%d handler=%s\", REC->irq, __get_str(name)\n";

static char dyn_str_old_data[] = {
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	/* common type */		2, 0x00,
#else
	/* common type */		0x00, 2
#endif
	/* common flags */		0x00,
	/* common_preempt_count */	0x00,
	/* common_pid */		0x00, 0x00, 0x00, 0x00,
	/* irq */			0x00, 0x00, 0x00, 0x00,

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	/* name : offset */		16, 0x00,
#else
	/* name : offset */		0x00, 16,
#endif
	/* padding */			0x00, 0x00,
	/* name */			'h', 'e', 'l', 'l', 'o', '\0',
	/* padding */			0x00, 0x00, 0x00
};
static void *dyn_str_old_event_data = (void *)dyn_str_old_data;

static struct tep_handle *test_tep;
static struct trace_seq *test_seq;
static struct trace_seq seq_storage;

static void parse_dyn_str(const char *dyn_str, void *data, int size)
{
	struct tep_format_field *field;
	struct tep_event *event;
	struct tep_record record;

	record.data = data;
	record.size = size;

	CU_TEST(tep_parse_format(test_tep, &event,
				 dyn_str, strlen(dyn_str),
				DYN_STR_EVENT_SYSTEM) == TEP_ERRNO__SUCCESS);

	field = tep_find_any_field(event, DYN_STR_FIELD);
	CU_TEST(field != NULL);
	trace_seq_reset(test_seq);
	tep_print_field(test_seq, data, field);
	CU_TEST(strcmp(test_seq->buffer, DYN_STRING) == 0);

	trace_seq_reset(test_seq);
	tep_print_event(test_tep, test_seq, &record, "%s", TEP_PRINT_INFO);
	trace_seq_do_printf(test_seq);
	CU_TEST(strcmp(test_seq->buffer, DYN_STRING_FMT) == 0);
}

static void test_parse_dyn_str_event(void)
{
	parse_dyn_str(dyn_str_event, dyn_str_event_data, sizeof(dyn_str_data));
}

static void test_parse_dyn_str_old_event(void)
{
	parse_dyn_str(dyn_str_old_event, dyn_str_old_event_data, sizeof(dyn_str_old_data));
}

static int test_suite_destroy(void)
{
	tep_free(test_tep);
	trace_seq_destroy(test_seq);
	return 0;
}

static int test_suite_init(void)
{
	test_seq = &seq_storage;
	trace_seq_init(test_seq);
	test_tep = tep_alloc();
	if (!test_tep)
		return 1;
	return 0;
}

void test_traceevent_lib(void)
{
	CU_pSuite suite = NULL;

	suite = CU_add_suite(TRACEEVENT_SUITE, test_suite_init, test_suite_destroy);
	if (suite == NULL) {
		fprintf(stderr, "Suite \"%s\" cannot be ceated\n", TRACEEVENT_SUITE);
		return;
	}
	CU_add_test(suite, "parse dynamic string event",
		    test_parse_dyn_str_event);
	CU_add_test(suite, "parse old dynamic string event",
		    test_parse_dyn_str_old_event);
}
