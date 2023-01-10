# SPDX-License-Identifier: LGPL-2.1
#
# Copyright (c) 2023 Daniel Wagner, SUSE LLC

source = [
    'trace-utest.c',
    'traceevent-utest.c',
]

e = executable(
   'trace-utest',
   source,
   include_directories: [incdir],
   dependencies: [libtraceevent_dep, cunit_dep])

test('trace-utest', e)
