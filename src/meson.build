# SPDX-License-Identifier: LGPL-2.1
#
# Copyright (c) 2023 Daniel Wagner, SUSE LLC

sources= [
   'event-parse-api.c',
   'event-parse.c',
   'event-plugin.c',
   'kbuffer-parse.c',
   'parse-filter.c',
   'parse-utils.c',
   'tep_strerror.c',
   'trace-seq.c',
]

libtraceevent = library(
    'traceevent',
    sources,
    version: library_version,
    include_directories: [incdir],
    install: true)

pkg = import('pkgconfig')
pkg.generate(
    libtraceevent,
    subdirs: 'traceevent',
    filebase: meson.project_name(),
    name: meson.project_name(),
    version: meson.project_version(),
    description: 'Manage trace event',
    url: 'https://git.kernel.org/pub/scm/libs/libtrace/libtraceevent.git/')

libtraceevent_dep = declare_dependency(
    include_directories: ['.'],
    link_with: libtraceevent)
