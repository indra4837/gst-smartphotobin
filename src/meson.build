
# main gstreamer depenency
gst_dep = dependency('gstreamer-1.0')
gst_ver = gst_dep.version().split('.')

# plugin path configuration for install
gst_install_dir = get_option('GST_PLUGIN_PATH')
if gst_install_dir == ''
  # get it from pkg-config
  gst_install_dir = gst_dep.get_variable(pkgconfig: 'pluginsdir')
endif
message('plugins will be installed to: ' + gst_install_dir)

# plugin dir logic for testing and subprojects
# TODO(mdegans):
#  we can use a single varible "pluginsdir" rather than a separate one for
#  uninstalled. Some of the logic below is unnecesssary.
gst_eyescan_dep = dependency('gst_eyescan')
gst_eyescan_plugindir = gst_eyescan_dep.get_variable(
  pkgconfig: 'pluginsdir',
  default_value: 'not_found',
)
if gst_eyescan_plugindir == 'not_found'
  gst_eyescan_plugindir = gst_eyescan_dep.get_variable(
    internal: 'pluginsdir_uninstalled')
endif
gst_smartphotobin_public_variables = [
  'pluginsdir_uninstalled=' + meson.current_build_dir() + ':' + gst_eyescan_plugindir,
  'pluginsdir=' + gst_install_dir + ':' + gst_eyescan_plugindir,
]
gst_plugin_path = meson.current_build_dir() + ':' + gst_eyescan_plugindir
message('GST_PLUGIN_PATH=' + gst_plugin_path)

# cpp_args for smartphotobin
gst_smartphotobin_cpp_args = []

# add dependencies here
gst_smartphotobin_deps = [
  gst_dep,
  dependency('gstreamer-app-1.0'),
  dependency('gstreamer-video-1.0'),
  dependency('gio-2.0'),
  dependency('gstnvmanualcamerameta'),
  dependency('gst_eyescan'),
]

# this configures the plugin info and defaults
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
  'gir_version': proj_ver_short,
  'DEFAULT_QA_MODEL': get_option('DEFAULT_QA_MODEL'),
  'DEFAULT_DR_MODEL': get_option('DEFAULT_DR_MODEL'),
  }
)

# our source code
gst_smartphotobin_sources = [
  plugin_vala,
  'smartphotobin.vala',
  'utils.vala',
  'qadrbin.vala',
  'qadr_utils.cpp',
  'smartphotobin_utils.cpp',
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
  vala_args: [
    '--vapi-comments',
    '--abi-stability',
    '--enable-experimental-non-null',
  ],
  include_directories: gst_smartphotobin_incdirs,
  dependencies: gst_smartphotobin_deps,
  install: true,
  install_dir: [gst_install_dir, true, true, true],
)

# TODO(mdegans) pkgconfig

# build typelib
g_ir_compiler = find_program('g-ir-compiler', required: false)
if g_ir_compiler.found()
  custom_target(gst_smartphotobin_typelib,
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

# where vala compiler outputs the header and  for testingg
gst_smartphotobin_output_incdir = include_directories('.')
gst_smartphotobin_vapidir = meson.current_build_dir()
gst_smartphotobin_public_variables += 'vapidir=' + gst_smartphotobin_vapidir

gst_smartphotobin_dep = declare_dependency(
  link_with: gst_smartphotobin_lib,
  dependencies: gst_smartphotobin_deps,
  include_directories: [
    gst_smartphotobin_public_incdir,
    gst_smartphotobin_output_incdir,
  ],
  variables: gst_smartphotobin_public_variables,
  version: meson.project_version(),
)

pkg = import('pkgconfig')
pkg.generate(gst_smartphotobin_lib,
  description: proj_description,
  variables: gst_smartphotobin_public_variables,
)

