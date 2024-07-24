# SPDX-License-Identifier: LGPL-2.1
#
# Copyright (c) 2023 Daniel Wagner, SUSE LLC

project(
    'libtraceevent', ['c'],
    meson_version: '>= 0.58.0',
    license: 'LGPL-2.1',
    version: '1.8.3',
    default_options: [
        'c_std=gnu99',
        'buildtype=debug',
        'default_library=both',
        'prefix=/usr/local',
        'warning_level=1',
    ])

library_version = meson.project_version()

cunit_dep = dependency('cunit', required : false)

prefixdir = get_option('prefix')
mandir = join_paths(prefixdir, get_option('mandir'))
htmldir = join_paths(prefixdir, get_option('htmldir'))
libdir = join_paths(prefixdir, get_option('libdir'))
plugindir = get_option('plugindir')
if plugindir == ''
    plugindir = join_paths(libdir, 'traceevent/plugins')
endif

add_project_arguments(
    [
        '-D_GNU_SOURCE',
        '-DPLUGIN_DIR="@0@"'.format(plugindir),
    ],
    language : 'c',
)

incdir = include_directories(['include', 'include/traceevent'])

subdir('src')
subdir('include/traceevent')
subdir('plugins')
if cunit_dep.found()
    subdir('utest')
endif
subdir('samples')

if get_option('doc')
subdir('Documentation')

custom_target(
    'docs',
    output: 'docs',
    depends: [html, man],
    command: ['echo'])
endif
