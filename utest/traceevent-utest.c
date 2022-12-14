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

#define CPUMASK_EVENT_SYSTEM "ipi"
#define CPUMASK_EVENT_FIELD  "cpumask"
static const char cpumask_event_format[] =
	"name: ipi_send_cpumask\n"
	"ID: 3\n"
	"format:\n"
	"\tfield:unsigned short common_type;\toffset:0;\tsize:2;\n"
	"\tfield:unsigned char common_flags;\toffset:2;\tsize:1;\n"
	"\tfield:unsigned char common_preempt_count;\toffset:3;\tsize:1;\n"
	"\tfield:int common_pid;\toffset:4;\tsize:4;\n"
	"\n"
	"\tfield:__data_loc cpumask_t *[] cpumask;\toffset:8;\tsize:4;\tsigned:0;\n"
	"\n"
	"print fmt: \"cpumask=%s\", __get_cpumask(cpumask)\n";

/* Mind the endianness! */
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#define DECL_CPUMASK_EVENT_DATA(name, args...)			\
	static char cpumask_##name##_event_data[] = {		\
	/* common type */		3, 0x00,                \
	/* common flags */		0x00,                   \
	/* common_preempt_count */	0x00,                   \
	/* common_pid */		0x00, 0x00, 0x00, 0x00, \
	/* [offset, size] */            16, 0x00, 8, 0x00,      \
	/* padding */			0x00, 0x00, 0x00, 0x00, \
	/* cpumask */                   args,                   \
}
#else
#define DECL_CPUMASK_EVENT_DATA(name, args...)			\
static char cpumask_##name##_event_data[] = {                       \
	/* common type */		0x00, 3,                \
	/* common flags */		0x00,                   \
	/* common_preempt_count */	0x00,                   \
	/* common_pid */		0x00, 0x00, 0x00, 0x00, \
	/* [offset, size] */            0x00, 8, 0x00, 16,      \
	/* padding */			0x00, 0x00, 0x00, 0x00, \
	/* cpumask */                   args,                   \
}
#endif

#define SIZEOF_LONG0_FMT "[FAILED TO PARSE] s4=0 u4=0 s8=0 u8=0x0"
#define SIZEOF_LONG4_FMT "int=4 unsigned=4 unsigned int=4 long=4 unsigned long=4 long long=8 unsigned long long=8 s4=4 u4=4 s8=8 u8=8"
#define SIZEOF_LONG8_FMT "int=4 unsigned=4 unsigned int=4 long=8 unsigned long=8 long long=8 unsigned long long=8 s4=4 u4=4 s8=8 u8=8"

static const char size_of_event[] =
	"name: sizeof_event\n"
	"ID: 23\n"
	"format:\n"
	"\tfield:unsigned short common_type;\toffset:0;\tsize:2;\tsigned:0;\n"
	"\tfield:unsigned char common_flags;\toffset:2;\tsize:1;\tsigned:0;\n"
	"\tfield:unsigned char common_preempt_count;\toffset:3;\tsize:1;\tsigned:0;\n"
	"\tfield:int common_pid;\toffset:4;\tsize:4;\tsigned:1;\n"
	"\n"
        "\tfield:int s4;\toffset:8;\tsize:4;\tsigned:1;\n"
        "\tfield:unsigned int u4;\toffset:12;\tsize:4;\tsigned:0;\n"
        "\tfield:long long s8;\toffset:16;\tsize:8;\tsigned:1;\n"
        "\tfield:unsigned long long u8;\toffset:24;\tsize:8;\tsigned:0;\n"
	"\n"
	"print fmt: \"int=%d unsigned=%d unsigned int=%d long=%d unsigned long=%d long long=%d unsigned long long=%d s4=%d u4=%d s8=%d u8=%d\", "
	"sizeof(int), sizeof(unsigned), sizeof(unsigned int), sizeof(long), sizeof(unsigned long), "
	"sizeof(long long), sizeof(unsigned long long), sizeof(REC->s4), "
	"sizeof(REC->u4), sizeof(REC->s8), sizeof(REC->u8))\n";
static char sizeof_data[] = {
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	/* common type */		23, 0x00,
#else
	/* common type */		0x00, 23
#endif
	/* common flags */		0x00,
	/* common_preempt_count */	0x00,
	/* common_pid */		0x00, 0x00, 0x00, 0x00,
	/* irq */			0x00, 0x00, 0x00, 0x00,

	/* s4 */			0x00, 0x00, 0x00, 0x00,
	/* u4 */			0x00, 0x00, 0x00, 0x00,
	/* s8 */			0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	/* u8 */			0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};
static void *sizeof_event_data = (void *)sizeof_data;

DECL_CPUMASK_EVENT_DATA(full, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff);
#define CPUMASK_FULL     "ARRAY[ff, ff, ff, ff, ff, ff, ff, ff]"
#define CPUMASK_FULL_FMT "cpumask=0-63"

DECL_CPUMASK_EVENT_DATA(empty, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);
#define CPUMASK_EMPTY     "ARRAY[00, 00, 00, 00, 00, 00, 00, 00]"
#define CPUMASK_EMPTY_FMT "cpumask="

DECL_CPUMASK_EVENT_DATA(half, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55);
#define CPUMASK_HALF     "ARRAY[55, 55, 55, 55, 55, 55, 55, 55]"
#define CPUMASK_HALF_FMT "cpumask=0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62"

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
DECL_CPUMASK_EVENT_DATA(bytep1, 0x01, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);
#define CPUMASK_BYTEP1     "ARRAY[01, 80, 00, 00, 00, 00, 00, 00]"
#define CPUMASK_BYTEP1_FMT "cpumask=0,15"

DECL_CPUMASK_EVENT_DATA(bytep2, 0x01, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00);
#define CPUMASK_BYTEP2     "ARRAY[01, 00, 80, 00, 00, 00, 00, 00]"
#define CPUMASK_BYTEP2_FMT "cpumask=0,23"

DECL_CPUMASK_EVENT_DATA(bytepn, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80);
#define CPUMASK_BYTEPN     "ARRAY[01, 00, 00, 00, 00, 00, 00, 80]"
#define CPUMASK_BYTEPN_FMT "cpumask=0,63"

#else

DECL_CPUMASK_EVENT_DATA(bytep1, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x01);
#define CPUMASK_BYTEP1     "ARRAY[00, 00, 00, 00, 00, 00, 80, 01]"
#define CPUMASK_BYTEP1_FMT "cpumask=0,15"

DECL_CPUMASK_EVENT_DATA(bytep2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x01);
#define CPUMASK_BYTEP2     "ARRAY[00, 00, 00, 00, 00, 80, 00, 01]"
#define CPUMASK_BYTEP2_FMT "cpumask=0,23"

DECL_CPUMASK_EVENT_DATA(bytepn, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01);
#define CPUMASK_BYTEPN     "ARRAY[80, 00, 00, 00, 00, 00, 80, 01]"
#define CPUMASK_BYTEPN_FMT "cpumask=0,63"
#endif

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
	tep_print_field_content(test_seq, data, size, field);
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

static void parse_cpumask(const char *format, void *data, int size,
			  const char* expected_raw, const char* expected)
{
	struct tep_format_field *field;
	struct tep_event *event;
	struct tep_record record;

	record.data = data;
	record.size = size;

	CU_TEST(tep_parse_format(test_tep, &event,
				 format, strlen(format),
				 CPUMASK_EVENT_SYSTEM) == TEP_ERRNO__SUCCESS);

	field = tep_find_any_field(event, CPUMASK_EVENT_FIELD);
	CU_TEST(field != NULL);

	trace_seq_reset(test_seq);
	tep_print_field_content(test_seq, data, size, field);
	CU_TEST(strcmp(test_seq->buffer, expected_raw) == 0);

	trace_seq_reset(test_seq);
	tep_print_event(test_tep, test_seq, &record, "%s", TEP_PRINT_INFO);
	trace_seq_do_printf(test_seq);
	CU_TEST(strcmp(test_seq->buffer, expected) == 0);
}

static void test_parse_cpumask_full(void)
{
	parse_cpumask(cpumask_event_format,
		      cpumask_full_event_data, sizeof(cpumask_full_event_data),
		      CPUMASK_FULL, CPUMASK_FULL_FMT);
}

static void test_parse_cpumask_empty(void)
{
	parse_cpumask(cpumask_event_format,
		      cpumask_empty_event_data, sizeof(cpumask_empty_event_data),
		      CPUMASK_EMPTY, CPUMASK_EMPTY_FMT);
}

static void test_parse_cpumask_half(void)
{
	parse_cpumask(cpumask_event_format,
		      cpumask_half_event_data, sizeof(cpumask_half_event_data),
		      CPUMASK_HALF, CPUMASK_HALF_FMT);
}

static void test_parse_cpumask_bytep1(void)
{
	parse_cpumask(cpumask_event_format,
		      cpumask_bytep1_event_data, sizeof(cpumask_bytep1_event_data),
		      CPUMASK_BYTEP1, CPUMASK_BYTEP1_FMT);
}

static void test_parse_cpumask_bytep2(void)
{
	parse_cpumask(cpumask_event_format,
		      cpumask_bytep2_event_data, sizeof(cpumask_bytep2_event_data),
		      CPUMASK_BYTEP2, CPUMASK_BYTEP2_FMT);
}

static void test_parse_cpumask_bytepn(void)
{
	parse_cpumask(cpumask_event_format,
		      cpumask_bytepn_event_data, sizeof(cpumask_bytepn_event_data),
		      CPUMASK_BYTEPN, CPUMASK_BYTEPN_FMT);
}

static void test_parse_sizeof(int long_size, int value, const char *system,
			      const char *test_str)
{
	struct tep_event *event;
	struct tep_record record;
	char *sizeof_event;
	char *p;

	tep_set_long_size(test_tep, long_size);

	record.data = sizeof_event_data;
	record.size = sizeof(sizeof_data);

	sizeof_event = strdup(size_of_event);
	CU_TEST(sizeof_event != NULL);

	/* Set a new id */
	p = strstr(sizeof_event, "ID: 2");
	p[5] = '0' + value;

	/* Handles endianess */
	*(unsigned short *)sizeof_data = 20 + value;

	CU_TEST(tep_parse_format(test_tep, &event, sizeof_event,
				 strlen(sizeof_event),
				 system) == TEP_ERRNO__SUCCESS);

	trace_seq_reset(test_seq);
	tep_print_event(test_tep, test_seq, &record, "%s", TEP_PRINT_INFO);
	trace_seq_do_printf(test_seq);
	CU_TEST(strcmp(test_seq->buffer, test_str) == 0);

	free(sizeof_event);
}

static void test_parse_sizeof8(void)
{
	test_parse_sizeof(8, 3, "sizeof8", SIZEOF_LONG8_FMT);
}

static void test_parse_sizeof4(void)
{
	test_parse_sizeof(4, 4, "sizeof4", SIZEOF_LONG4_FMT);
}

static void test_parse_sizeof_undef(void)
{
	test_parse_sizeof(0, 5, "sizeof_undef", SIZEOF_LONG0_FMT);
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
	CU_add_test(suite, "parse full cpumask",
		    test_parse_cpumask_full);
	CU_add_test(suite, "parse empty cpumask",
		    test_parse_cpumask_empty);
	CU_add_test(suite, "parse half-filled cpumask",
		    test_parse_cpumask_half);
	CU_add_test(suite, "parse cpumask spanning 2 bytes",
		    test_parse_cpumask_bytep1);
	CU_add_test(suite, "parse cpumask spanning 3 bytes",
		    test_parse_cpumask_bytep2);
	CU_add_test(suite, "parse cpumask spanning all bytes",
		    test_parse_cpumask_bytepn);
	CU_add_test(suite, "parse sizeof() 8byte values",
		    test_parse_sizeof8);
	CU_add_test(suite, "parse sizeof() 4byte values",
		    test_parse_sizeof4);
	CU_add_test(suite, "parse sizeof() no long size defined",
		    test_parse_sizeof_undef);
}
