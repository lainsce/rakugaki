project('com.github.lainsce.rakugaki', 'vala', 'c', version: '1.0.5')

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
)

asresources = gnome.compile_resources(
    'as-resources',
    'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

dependencies = [
    dependency('granite'),
    dependency('gobject-2.0'),
    dependency('gtk+-3.0'),
    meson.get_compiler('c').find_library('m', required: true)
]

subdir('src')

executable(
    meson.project_name(),
    sources,
    asresources,
    dependencies: dependencies,
    install : true
)

subdir('data')
subdir('po')

meson.add_install_script('meson/post_install.py')
