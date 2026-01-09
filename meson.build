project(
    'stamina',
    'vala', 'c',
    version: '1.0.0',
    license: 'GPL-3.0-or-later',
    default_options: [
        'warning_level=2',
        'werror=false',
        'buildtype=debugoptimized',
        'b_ndebug=if-release',
    ]
)

# Минимальные версии
gtk_min_version = '4.12'
adw_min_version = '1.4'

# Имя приложения
app_id = 'org.intsoftware.stamina'
app_name = 'Stamina'

# Зависимости
deps = [
    dependency('glib-2.0', version: '>=2.72'),
    dependency('gio-2.0', version: '>=2.72'),
    dependency('gtk4', version: '>=' + gtk_min_version),
    dependency('libadwaita-1', version: '>=' + adw_min_version),
    dependency('json-glib-1.0'),
]

# Компиляция ресурсов
gnome = import('gnome')

gresources = gnome.compile_resources(
    app_id + '.gresource',
    'data/' + app_id + '.gresource.xml',
    source_dir: 'data',
    c_name: 'resources'
)

# Исходные файлы
sources = files(
    'src/Main.vala',
    'src/Window.vala',
    'src/Timer.vala',
    'src/Preferences.vala',
    'src/Utils.vala',
)

# Исполняемый файл
executable(
    app_name,
    sources + gresources,
    dependencies: deps,
    install: true,
    vala_args: [
        '--target-glib=2.72',
        '--gresources=data/' + app_id + '.gresource.xml',
        '--vapidir=' + meson.current_source_dir() + '/vapi',
    ],
    c_args: [
        '-DG_LOG_DOMAIN="@0@"'.format(app_name),
        '-DGETTEXT_PACKAGE="@0@"'.format(app_id),
    ],
)

# Установка схемы GSettings
install_data(
    'data/' + app_id + '.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)

# Установка метаинформации
install_data(
    'data/' + app_id + '.metainfo.xml',
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Установка иконок
icon_sizes = ['16x16', '32x32', '48x48', '64x64', '128x128', '256x256', 'scalable']

foreach size : icon_sizes
    install_data(
        'data/icons/' + size + '/apps/' + app_id + '.svg',
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', size, 'apps')
    )
endforeach

# Установка .desktop файла
install_data(
    'data/' + app_id + '.desktop',
    install_dir: join_paths(get_option('datadir'), 'applications')
)

# Компиляция схем GSettings
gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)

# Поддержка переводов
if get_option('buildtype') != 'plain'
    if (intl.found())
        subdir('po')
    endif
endif