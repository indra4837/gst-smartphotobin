
# main gstreamer depenency
gst_dep = dependency('gstreamer-1.0')
gst_ver = gst_dep.version().split('.')
gst_plugin_dir = get_option('gst_plugin_dir')
if gst_plugin_dir == ''
  # get it from pkg-config
  gst_plugin_dir = gst_dep.get_variable(pkgconfig: 'pluginsdir')
endif
message('plugin will be installed to: ' + gst_plugin_dir)

# add dependencies here
gst_smartphotobin_deps = [
  gst_dep,
  dependency('gstreamer-app-1.0'),
  dependency('gstreamer-video-1.0'),
  dependency('gdk-pixbuf-2.0'),
]

# this configures the plugin info
plugin_vala = configure_file(
  input: 'plugin.vala',
  output: 'plugin.vala',
  configuration: {
  'version': proj_ver_short,
  'gst_major_version': gst_ver[0].to_int(),
  'gst_minor_version': gst_ver[1].to_int(),
  'project_name': meson.project_name(),
  'project_description': proj_description,
  'license': ','.join(meson.project_license()),
  'proj_url': proj_url,
  'package_name': meson.project_name(),
  'origin': origin,
  }
)

# our source code
gst_smartphotobin_sources = [
  plugin_vala,
  'smartphotobin.vala',
  'utils.vala',
]

# changing these names will breaks stuff because gstreamer and other GNU things
# demand a very specific naming convention to enforce consistency.
gst_smartphotobin_libname = 'gst' + meson.project_name()
gst_smartphotobin_vapi = 'GstSmart-'+ proj_ver_short + '.vapi'
gst_smartphotobin_gir = 'GstSmart-'+ proj_ver_short + '.gir'
gst_smartphotobin_typelib = 'GstSmart-'+ proj_ver_short + '.typelib'
gst_smartphotobin_lib = library(gst_smartphotobin_libname.to_lower(), gst_smartphotobin_sources,
  vala_header: meson.project_name().to_lower() + '.h',
  vala_vapi: gst_smartphotobin_vapi,
  vala_gir: gst_smartphotobin_gir,
  vala_args : [
    '--vapi-comments',
    '--abi-stability',
    '--enable-experimental-non-null',
  ],
  dependencies: gst_smartphotobin_deps,
  install: true,
  install_dir: [gst_plugin_dir, true, true, true],
)

# build typelib
g_ir_compiler = find_program('g-ir-compiler', required: false)
if g_ir_compiler.found()
  custom_target('libdssd typelib',
    command: [
      g_ir_compiler,
      '--output', '@OUTPUT@',
      '--shared-library=' + get_option('libdir') / gst_smartphotobin_libname,
      meson.current_build_dir() / gst_smartphotobin_gir
    ],
    depends: gst_smartphotobin_lib,
    output: gst_smartphotobin_typelib,
    install: true,
    install_dir: get_option('libdir') / 'girepository-1.0',
  )
else
  message('not building typelib language bindings (sudo apt-get install sudo apt install gobject-introspection)')
endif