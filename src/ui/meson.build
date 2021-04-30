gst_smartphotobin_gresourcesdir = meson.current_source_dir()

gst_smartphotobin_deps += gtk_dep
gst_smartphotobin_deps += gdk_x11_dep

gst_smartphotobin_sources += files('gui.vala')
gst_smartphotobin_sources += import('gnome').compile_resources(
    'project-resources',
    'resources/filelist.gresource.xml',
    source_dir: ['resources'],
)
