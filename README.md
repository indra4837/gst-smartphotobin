# gst-smartphotobin
A sink bin using DeepStream elements to automatically choose the best photo.
Much of this code is adapted from [`gst-web`](https://github.com/mdegans/gst-web/)
and ['dssd'](https://github.com/mdegans/dssd/).

# Requirements

* apt-get build dependencies:
```
gir1.2-gstreamer-1.0
gir1.2-gst-plugins-base-1.0
```

tl;dr
```

```

## FAQ

* **why Vala?** because writing GObject in C is a hair-tearing experience and
subclassing a GObject is even more arcane in Rust than it is in C. It's also the
most mature bindings for GStreamer apart from *perhaps* Python.

