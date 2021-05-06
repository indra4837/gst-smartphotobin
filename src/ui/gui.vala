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
    Gtk.Label state;

    [GtkChild]
    Gtk.Label focused;

    [GtkChild]
    Gtk.Label aligned;

    [GtkChild]
    Gtk.Label zoomed;

    [GtkChild]
    Gtk.Label capture_ready;

    public StatusBar(GstSmart.PhotoBin pipe) {
        // change status label when the pipeline state changes.
        pipe.notify["state"].connect(() => {
            state.set_text(@"State: $(pipe.state.to_string())");
        });

        // these change the greyed out status of labels in the status bar
        focused.sensitive = pipe.ptzf.focused;
        pipe.focused.connect((value) => {
            focused.sensitive = value;
        });

        aligned.sensitive = pipe.ptzf.aligned;
        pipe.aligned.connect((value) => {
            aligned.sensitive = value;
        });

        zoomed.sensitive = pipe.ptzf.zoomed;
        pipe.zoomed.connect((value) => {
            zoomed.sensitive = value;
        });

        capture_ready.sensitive = pipe.ptzf.capture_ready;
        pipe.capture_ready.connect((value) => {
            capture_ready.sensitive = value;
        });
    }
}

[GtkTemplate (ui = "/components/test_gui_slider_box.ui")]
public class SliderBox : Gtk.Box {
    [GtkChild] 
    Gtk.Label label;

    [GtkChild]
    Gtk.Scale scale;

    public SliderBox(Object o,
                     string prop_name,
                     double min = 0.0,
                     double max = 1.0) {
        label.set_text(prop_name);
        scale.set_range(min, max);
        // change value when the range is adjusted
        scale.value_changed.connect((range) => {
            o.set(prop_name, range.get_value());
        });
    }
}

[GtkTemplate (ui = "/components/test_gui_capture_controls.ui")]
public class CaptureControls : Gtk.Frame {
    [GtkChild]
    Gtk.Scale exposure;

    [GtkChild]
    Gtk.Scale gain;

    [GtkChild]
    Gtk.Scale r_gain;

    [GtkChild]
    Gtk.Scale g_gain;

    [GtkChild]
    Gtk.Scale b_gain;

    [GtkChild]
    Gtk.Switch right_eye;

    [GtkChild]
    Gtk.Scale flash_delay;

    [GtkChild]
    Gtk.Scale flash_duration;

    [GtkChild]
    Gtk.Scale flash_overlap;

    [GtkChild]
    Gtk.Scale flash_brightness;

    /** Get a copy of the current CaptureConfig with an incremented id. */
    private CaptureConfig _config = CaptureConfig();
    public CaptureConfig config {
        get {
            ++_config.id;
            return _config;
        }
    }

    construct {
        // setup controls
        exposure.set_range(0.0, 1.0);
        exposure.set_value(_config.exposure);
        exposure.value_changed.connect(() => {
            _config.exposure = exposure.get_value();
        });

        gain.set_range(0.0, 1.0);
        gain.set_value(_config.gain);
        gain.value_changed.connect(() => {
            _config.gain = gain.get_value();
        });

        r_gain.set_range(0.0, 2.0);
        r_gain.set_value(_config.wb.r);
        r_gain.value_changed.connect(() => {
            _config.wb.r = r_gain.get_value();
        });

        g_gain.set_range(0.0, 2.0);
        g_gain.set_value(_config.wb.g);
        g_gain.value_changed.connect(() => {
            _config.wb.g = g_gain.get_value();
        });


        b_gain.set_range(0.0, 2.0);
        b_gain.set_value(_config.wb.b);
        b_gain.value_changed.connect(() => {
            _config.wb.b = b_gain.get_value();
        });

        right_eye.set_active(_config.eye == Eye.RIGHT);
        right_eye.activate.connect(() => {
            if (right_eye.get_active()) {
                // switch is to the right, so set right eye
                _config.eye = Eye.RIGHT;
            } else {
                _config.eye = Eye.LEFT;
            }
        });

        flash_delay.set_range(0.0, 1.0);
        flash_delay.set_value(_config.flash.delay);
        flash_delay.value_changed.connect(() => {
            _config.flash.delay = flash_delay.get_value();
        });

        flash_duration.set_range(0.0, 1.0);
        flash_duration.set_value(_config.flash.duration);
        flash_duration.value_changed.connect(() => {
            _config.flash.duration = flash_duration.get_value();
        });

        flash_overlap.set_range(0.0, 1.0);
        flash_overlap.set_value(_config.flash.overlap);
        flash_overlap.value_changed.connect(() => {
            _config.flash.overlap = flash_overlap.get_value();
        });

        flash_brightness.set_range(0.0, 1.0);
        flash_brightness.set_value(_config.flash.brightness);
        flash_brightness.value_changed.connect(() => {
            _config.flash.brightness = flash_brightness.get_value();
        });
    }
}

[GtkTemplate (ui = "/components/test_gui_controls.ui")]
public class Controls : Gtk.Box {
    [GtkChild]
    Gtk.Button stop;
    [GtkChild]
    Gtk.Button play;
    [GtkChild]
    Gtk.Button capture;

    [GtkChild]
    Gtk.ToggleButton imshow_grey;

    [GtkChild]
    Gtk.ToggleButton imshow_thresh;

    [GtkChild]
    Gtk.ToggleButton imshow_sharp;

    CaptureControls capture_controls = new CaptureControls();

    public Controls(GstSmart.PhotoBin pipe) {
        // @indra4597 if you ever need to add more sliders to ptzf, you can do
        // so like:
        // controls.add(new SliderBox(pipe.ptzf, "foo", 0.0, 100.0));
        // set the capture button to only be enabled when ptzf is updated
        // to the capture_ready state
        capture.set_sensitive(pipe.ptzf.capture_ready);
        pipe.capture_ready.connect(capture.set_sensitive);

        // connect pipline state control buttons
        play.clicked.connect(() => {
            var ret =  pipe.set_state(Gst.State.PLAYING);
            if (ret == Gst.StateChangeReturn.FAILURE) {
                on_error("Could not set pipeline to PLAYING state");
            }
        });
        stop.clicked.connect(() => {
            var ret = pipe.set_state(Gst.State.READY);
            if (ret == Gst.StateChangeReturn.FAILURE) {
                on_error("Could not set pipeline to READY state");
            }
        });
        capture.clicked.connect(() => {
            pipe.capture(capture_controls.config);
        });

        // set initial state of toggle buttons to ptzf defaults
        imshow_grey.set_active(pipe.ptzf.imshow_grey);
        imshow_thresh.set_active(pipe.ptzf.imshow_thresh);
        imshow_sharp.set_active(pipe.ptzf.imshow_sharp);
        // and add callbacks to change the ptzf state in turn
        imshow_grey.toggled.connect((btn) => {
            pipe.ptzf.imshow_grey = btn.get_active();
        });
        imshow_thresh.toggled.connect((btn) => {
            pipe.ptzf.imshow_thresh = btn.get_active();
        });
        imshow_sharp.toggled.connect((btn) => {
            pipe.ptzf.imshow_sharp = btn.get_active();
        });

        // add sliders for brightness and zoom
        add(new SliderBox(pipe.camera, "brightness"));
        add(new SliderBox(pipe.ptzf, "zoom"));
        add(capture_controls);
    }

    private void on_error(string errmsg) {
        var maybe_window = this.get_toplevel() as Gtk.Window;
        if (maybe_window == null) {
            warning("Could not get top level window as GtkWindow.");
            warning(errmsg);
            return;
        }
        var dialog = new Gtk.MessageDialog(
            (!)maybe_window,
            Gtk.DialogFlags.MODAL,
            Gtk.MessageType.ERROR,
            Gtk.ButtonsType.CLOSE,
            errmsg);
        dialog.show();
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
        controls = new Controls(pipe);
        statusbar = new StatusBar(pipe);

        // add the statusbar
        main_box.add(statusbar);

        // add the ui elements to the left and right panels and connect them
        left_revealer.add(gallery);
        statusbar.gallery.toggled.connect((btn) => {
            // toggles gallery
            left_revealer.reveal_child = btn.active;
        });
        right_revealer.add(controls);
        statusbar.controls.toggled.connect((btn) => {
            // toggles right revealer
            right_revealer.reveal_child = btn.active;
        });

        // setup fullscreen button
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

        // connect capture callbacks
        pipe.capture_success.connect(gallery.add_thumbnail);
        pipe.capture_failure.connect(on_error);

        // set video overlay window id when overlay area is realized
        overlay_area.realize.connect(() => {
            var maybe_area_win = overlay_area.get_window() as Gdk.X11.Window;
            if (maybe_area_win != null) {
                var area_win = (!)maybe_area_win;
                pipe.overlay.set_window_handle((uint*)area_win.get_xid());
            } else {
                error("could not get DrawingArea window as Gdk.X11.Window");
            }
        });
        // If the pipeline is less than the paused state, we need to draw
        // a black box over the drawing area using the Cairo.Context, or it
        // doesn't redraw and we get trails and junk.
        overlay_area.draw.connect((ctx) => {
            if (pipe.state < Gst.State.PAUSED) {
                Gtk.Allocation allocation;
                overlay_area.get_allocation(out allocation);
                ctx.set_source_rgb(0,0,0);
                ctx.rectangle(0,0,allocation.width, allocation.height);
                ctx.fill();
            }
        });
        pipe.notify["state"].connect(() => {
            // If the pipeline state changes, We should redraw the overlay_area.
            // Otherwise on stop, for example, it'll continue to display the
            // previous frame until the window is resized.
            overlay_area.queue_draw();
        });

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