/* gui.vala
 *
 * Copyright 2020 Michael de Gans <47511965+mdegans@users.noreply.github.com>
 * based off Vala boilerplate by Fabian Deutsch
 *
 * 66E67F6ADF56899B2AA37EF8BF1F2B9DFBB1D82E66BD48C05D8A73074A7D2B75
 * EB8AA44E3ACF111885E4F84D27DC01BB3BD8B322A9E8D7287AD20A6F6CD5CB1F
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 3 of the
 * License, or (at your option) any later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

namespace GstSmart {

[GtkTemplate (ui = "/components/test_gui_status_bar.ui")]
public class StatusBar : Gtk.Statusbar {
    [GtkChild]
    public Gtk.ToggleButton fullscreen;

    [GtkChild]
    public Gtk.ToggleButton controls;

    [GtkChild]
    public Gtk.ToggleButton gallery;

    [GtkChild]
    public Gtk.Label status;

    [GtkChild]
    public Gtk.Label focused;

    [GtkChild]
    public Gtk.Label aligned;

    [GtkChild]
    public Gtk.Label zoomed;

    [GtkChild]
    public Gtk.Label capture_ready;
}

[GtkTemplate (ui = "/components/test_gui_slider_box.ui")]
public class SliderBox : Gtk.Box {
    [GtkChild] 
    Gtk.Label label;

    [GtkChild]
    Gtk.Scale scale;

    public SliderBox(Gst.Element e,
                     string prop_name,
                     double min = 0.0,
                     double max = 1.0) {
        label.set_text(prop_name);
        scale.set_range(min, max);
        // change value when the range is adjusted
        scale.value_changed.connect((range) => {
            e.set(prop_name, range.get_value());
        });
    }
}

[GtkTemplate (ui = "/components/test_gui_controls.ui")]
public class Controls : Gtk.Box {
    [GtkChild]
    public Gtk.Button stop;
    [GtkChild]
    public Gtk.Button play;
    [GtkChild]
    public Gtk.Button capture;

    [GtkChild]
    public Gtk.ToggleButton imshow_grey;

    [GtkChild]
    public Gtk.ToggleButton imshow_thresh;

    [GtkChild]
    public Gtk.ToggleButton imshow_sharp;

    public CaptureConfig config { public get; private set; }

    construct {
        config = CaptureConfig();
    }
}

[GtkTemplate (ui = "/components/test_gui_gallery_item.ui")]
public class GalleryItem : Gtk.Box {
    static uint counter;

    [GtkChild]
    Gtk.Label label;
    [GtkChild]
    Gtk.Image thumbnail;
    public GalleryItem(Gst.Buffer buf, Gst.Caps caps) {
        (void)buf;
        (void)caps;
        label.set_text(@"Capture $(counter++)");
        (void)thumbnail;
    }
}

[GtkTemplate (ui = "/components/test_gui_gallery.ui")]
public class Gallery : Gtk.ScrolledWindow {
    [GtkChild]
    Gtk.ListBox list;

    public void add_thumbnail(Gst.Buffer buf, Gst.Caps caps) {
        debug("Adding thumbnail.");
        list.add(new GalleryItem(buf, caps));
    }
}

[GtkTemplate (ui = "/layouts/test_gui.ui")]
public class TestAppWindow : Gtk.ApplicationWindow {
    [GtkChild]
    private Gtk.Revealer left_revealer;
    [GtkChild]
    private Gtk.DrawingArea overlay_area;
    [GtkChild]
    private Gtk.Revealer right_revealer;
    [GtkChild]
    private Gtk.Box main_box;

    private PhotoBin pipe;
    private Gallery gallery;
    private Controls controls;
    private StatusBar statusbar;

    private bool is_fullscreen;

    construct {
        pipe = new GstSmart.PhotoBin();
        gallery = new Gallery();
        controls = new Controls();
        statusbar = new StatusBar();

        // add the ui elements to the left and right panels
        left_revealer.add(gallery);
        right_revealer.add(controls);

        // add the statusbar on the bottom and connect it's buttons
        main_box.add(statusbar);
        this.window_state_event.connect((state) => {
            // cache the fullscreen state
            is_fullscreen = (bool)(state.new_window_state & Gdk.WindowState.FULLSCREEN);
        });
        statusbar.fullscreen.toggled.connect((btn) => {
            // toggle the fullscreen state
            if (is_fullscreen) {
                unfullscreen();
            } else {
                fullscreen();
            }
        });
        statusbar.controls.toggled.connect((btn) => {
            // toggles right revealer
            right_revealer.reveal_child = btn.active;
        });
        statusbar.gallery.toggled.connect((btn) => {
            // toggles gallery
            left_revealer.reveal_child = btn.active;
        });


        // connect pipeline callbacks
        pipe.capture_ready.connect(controls.capture.set_sensitive);
        pipe.capture_success.connect(gallery.add_thumbnail);
        pipe.capture_failure.connect(on_error);
        pipe.notify["status"].connect(() => {
            statusbar.status.set_text(@"State: $(pipe.status.to_string())");
        });
        // @indra4837 if you ever need to connect to a property, here's how to
        // do it. You can check the generated C to see the  boilerplate it
        // creates (the "useless" variables are to avoid undefined behavior).
        pipe.ptzf.notify["focused"].connect(() => {
            statusbar.focused.sensitive = pipe.ptzf.focused;
        });
        pipe.ptzf.notify["aligned"].connect(() => {
            statusbar.aligned.sensitive = pipe.ptzf.aligned;
        });
        pipe.ptzf.notify["zoomed"].connect(() => {
            statusbar.zoomed.sensitive = pipe.ptzf.zoomed;
        });
        pipe.ptzf.notify["capture-ready"].connect(() => {
            statusbar.capture_ready = pipe.ptzf.capture_ready;
        });


        overlay_area.realize.connect(() => {
            // connect video overlay
            var maybe_area_win = overlay_area.get_window() as Gdk.X11.Window;
            if (maybe_area_win != null) {
                var area_win = (!)maybe_area_win;
                pipe.overlay.set_window_handle((uint*)area_win.get_xid());
            } else {
                error("could not get DrawingArea window as Gdk.X11.Window");
            }
        });
        overlay_area.draw.connect((ctx) => {
            // If the pipeline is less than the paused state, we need to draw
            // a black box over the drawing area using the Cairo.Context, or it
            // doesn't redraw and we get trails and junk.
            if (pipe.state < Gst.State.PAUSED) {
                Gtk.Allocation allocation;
                overlay_area.get_allocation(out allocation);
                ctx.set_source_rgb(0,0,0);
                ctx.rectangle(0,0,allocation.width, allocation.height);
                ctx.fill();
            }
        });
        // connect pipline state control buttons
        controls.play.clicked.connect(() => {
            var ret =  pipe.set_state(Gst.State.PLAYING);
            if (ret == Gst.StateChangeReturn.FAILURE) {
                on_error("Could not set pipeline to PLAYING state");
            }
        });
        controls.stop.clicked.connect(() => {
            var ret = pipe.set_state(Gst.State.READY);
            if (ret == Gst.StateChangeReturn.FAILURE) {
                on_error("Could not set pipeline to READY state");
            }
        });
        controls.capture.clicked.connect(() => {
            pipe.capture(controls.config);
        });

        // set initial state of toggle buttons to ptzf defaults
        controls.imshow_grey.set_active(pipe.ptzf.imshow_grey);
        controls.imshow_thresh.set_active(pipe.ptzf.imshow_thresh);
        controls.imshow_sharp.set_active(pipe.ptzf.imshow_sharp);
        // and add callbacks to change the ptzf state in turn
        controls.imshow_grey.toggled.connect((btn) => {
            pipe.ptzf.imshow_grey = btn.get_active();
        });
        controls.imshow_thresh.toggled.connect((btn) => {
            pipe.ptzf.imshow_thresh = btn.get_active();
        });
        controls.imshow_sharp.toggled.connect((btn) => {
            pipe.ptzf.imshow_sharp = btn.get_active();
        });

        // connect sliders
        var maybe_p_elem = pipe as Gst.Element;
        assert (maybe_p_elem != null);
        var p_elem = (!)maybe_p_elem;
        controls.add(new SliderBox(p_elem, "brightness"));
        controls.add(new SliderBox(p_elem, "zoom"));
        // @indra4597 if you ever need to add more sliders to ptzf, you can do
        // so like:
        // controls.add(new SliderBox(pipe.ptzf, "foo", 0.0, 100.0));

        // cleanup pipeline when widget is destroyed
        this.destroy.connect(() => {
            pipe.set_state(Gst.State.NULL);
        });
    }

    public TestAppWindow(Gtk.Application app) {
        Object(application: app);
    }

    private void on_error(string errmsg) {
        var dialog = new Gtk.MessageDialog(
            this,
            Gtk.DialogFlags.MODAL,
            Gtk.MessageType.ERROR,
            Gtk.ButtonsType.CLOSE,
            errmsg);
        dialog.show();
    }
}

} // namespace GstSmart