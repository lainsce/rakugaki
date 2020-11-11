project('com.github.lainsce.rakugaki', ['vala', 'c'], version: '2.0.0')
gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
)

sources = files(
    'src/Application.vala',
    'src/MainWindow.vala',
    'src/Constants/AppSettings.vala',
    'src/Widgets/UI.vala',
    'src/Widgets/EditableLabel.vala'
)

asresources = gnome.compile_resources(
    'as-resources',
    'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

dependencies = [
    dependency('gtk+-3.0'),
    dependency('gobject-2.0'),
    dependency('libhandy-1', version: '>=0.80.0'),
    dependency('granite'),
    meson.get_compiler('c').find_library('m', required: true)
]

executable(
    meson.project_name(),
    sources,
    asresources,
    dependencies: dependencies,
    install : true
)

subdir('data')
subdir('po')

# Add in a post install script
meson.add_install_script('meson/post_install.py',  join_paths(get_option('prefix'), get_option('datadir')))
