# Copyright (c) 2020 Michael de Gans

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# this meson.build is for example code

# a list of dicts describing tests
tests = [
  {
    'description': 'test qadr',
    'filename': 'test_qadr',
    'sources': ['test_qadr.vala'],
    'suites': ['interactive'],
    'extra_deps': [],
  },
]

if gui_enabled
  tests += {
    'description': 'test gui',
    'filename': 'test_gui',
    'sources': ['test_gui.vala'],
    'suites': ['interactive'],
    'extra_deps': [],
  }
endif

# build tests (and optionally execute them)
foreach t: tests
  foreach dep: t['extra_deps']
    if not dep.found()
      warning(
        'not building ' + t['description'] + ' because '
        + dep.name() + ' not found')
    endif
  endforeach
  exe = executable(t['filename'], t['sources'],
    dependencies: [
        gst_smartphotobin_dep,
        t['extra_deps'],
    ],
    include_directories: gst_smartphotobin_output_incdir,
  )
  # skip running test if it's an interactive one
  if 'interactive' in t['suites']
    continue
  endif

  # run the rest of the tests in parallel
  test(t['description'], exe,
    protocol: 'exitcode',
    is_parallel: false,
    suite: t['suites'],
    timeout: 300,  # seconds
    env: [
      'GST_DEBUG=4',
      'GST_PLUGIN_PATH=' + gst_plugin_path,
      'GST_REGISTRY_UPDATE=yes',
    ],
  )
endforeach
