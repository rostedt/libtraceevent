# SPDX-License-Identifier: LGPL-2.1
#
# Copyright (c) 2023 Daniel Wagner, SUSE LLC

plugins = [
    'plugin_cfg80211.c',
    'plugin_function.c',
    'plugin_futex.c',
    'plugin_hrtimer.c',
    'plugin_jbd2.c',
    'plugin_kmem.c',
    'plugin_kvm.c',
    'plugin_mac80211.c',
    'plugin_sched_switch.c',
    'plugin_scsi.c',
    'plugin_tlb.c',
    'plugin_xen.c',
]

pdeps = []
foreach plugin : plugins
    pdeps += shared_module(
        plugin.replace('.c', ''),
        plugin,
        name_prefix: '',
        dependencies: [libtraceevent_dep],
        include_directories: [incdir],
        install: true,
        install_dir: plugindir)
endforeach

# perf needs the exported symbol list
dynamic_list_file = find_program('dynamic_list.sh')
custom_target(
    'dynamic_list',
    depends: pdeps,
    input: pdeps,
    output: 'libtraceevent-dynamic-list',
    command: [dynamic_list_file, '@INPUT@'],
    capture: true,
    build_by_default: true,
    install: true,
    install_dir: plugindir)
