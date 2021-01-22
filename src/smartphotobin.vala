/* smartphotobin.vala
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

[CCode (cprefix = "Gst", gir_namespace = "GstSmart", gir_version = "0.1", lower_case_cprefix="gst_")]
namespace Gst.Smart {

/**
 * General errors for the PhotoBin.
 */
public errordomain PhotoBinError {
    BAD_CONFIG,
}

/**
 * Errors related to capture.
 */
public errordomain CaptureError {
    UNKNOWN,
    TOO_DARK,
    OUT_OF_FOCUS,
    QA_FAILED,
    PULL_SAMPLE,
    GET_BUFFER,
    GET_CAPS,
    PARSE_INFO,
    BUFFER_MAP,
}

/**
 * Config for PhotoBin.
 */
public class PhotoBinConfig: Object {
    /** Path to the quality assurance model */
    public string qa_model;
    /** Path to the diagnosis/whatever model */
    public string dr_model;
    /** Number of buffers to allow into the queue per capture */
    public uint num_buffers;

    construct {
        qa_model = "";
        dr_model = "";
        num_buffers = 10;
    }

    public virtual bool validate() throws PhotoBinError.BAD_CONFIG {
        // FIXME(mdegans): check qa model path len, is valid path, and exists
        // FIXME(mdegans): check dr model path len, is valid path, and exists
        // FIXME(mdegans): check num buffers is within sane range
        return true;
    }
}

/**
 * PhotoBin takes a series of buffers in when triggered, chooses the best one,
 * optionally performs in inference on that best one.
 */
public class PhotoBin: Gst.Bin {
    /** This bin's configuration */
    protected PhotoBinConfig config;
    /** Our input queue */
    protected Gst.Element queue;
    /** Prepares buffers for inferences (scales, attaches meta) */
    protected Gst.Element muxer;
    // TODO(mdegans): check brightness element (sum pixels / num pixels)
    // TODO(mdegans): check focus element (possibly from argus, or laplacian)
    /** Quality assurance inference element */
    protected Gst.Element infer_qa;
    /** Diagnosis/whatever infrence element for images that pass QA */
    protected Gst.Element infer_dr;
    /** Converts GPU to CPU buffers */
    protected Gst.Element conv;
    /** our sink as GstElement */
    protected Gst.Element sink;
    /** same as sink, just casted to GstAppSink */
    protected Gst.App.Sink appsink;

    /** An internal counter of frames to capture */
    protected uint frames_to_capture;

    static construct {
        set_static_metadata(
            "Smart Photo Bin",
            "Sink/Network",
            "Sink bin with mpegtsmux, hlssink and an Nginx subprocess.",
            "Michael de Gans <michael.john.degans@gmail.com>");

        Gst.StaticCaps sink_caps = {
            (Gst.Caps)null,
            // FIXME(mdegans): copy nvstreammux caps exactly
            "video/x-raw(memory:NVMM)",
        };

        Gst.StaticPadTemplate sink_pad_template = {
            "sink",
            Gst.PadDirection.SINK,
            Gst.PadPresence.ALWAYS,
            sink_caps,
        };
        add_static_pad_template(sink_pad_template);
    }

    construct {
        // Here the element creation is slightly convoluted since we're using
        // the experimental nullability checking features. Given the way our
        // elements are declared above (as Gst.Element and not nullable
        // Gst.Element?), we need to ensure every element is non-null.
        // we're using g_assert here to crash if anything in the constructor
        // fails. We cannot throw from here.

        // create a blank new config
        this.config = new PhotoBinConfig();

        // create our in queue
        var maybe_queue = Gst.ElementFactory.make("queue", "queue");
        assert(maybe_queue != null);
        // the exclamation mark tells the compiler "this is for sure non-null"
        this.queue = (!) maybe_queue;

        // create our muxer.
        var maybe_muxer = Gst.ElementFactory.make(MUXER_ELEMENT, "muxer");
        assert(maybe_muxer != null);
        this.muxer = (!) maybe_muxer;

        // create our quality assurance inference element
        var maybe_infer_qa = Gst.ElementFactory.make(
            INFERENCE_ELEMENT, "infer_qa");
        assert(maybe_infer_qa != null);
        this.infer_qa = (!) maybe_infer_qa;

        // create our diagnosis/whatever inference element
        var maybe_infer_dr = Gst.ElementFactory.make(
            INFERENCE_ELEMENT, "infer_dr");
        assert(maybe_infer_dr != null);
        this.infer_dr = (!) maybe_infer_dr;

        // create our converter
        var maybe_conv = Gst.ElementFactory.make(
            CONVERSION_ELEMENT, "conv");
        assert(maybe_conv != null);
        this.conv = (!) maybe_conv;

        // create our appsink to get images out of this pipeline
        var maybe_appsink = Gst.ElementFactory.make("appsink", "appsink");
        assert(maybe_appsink != null);
        if (maybe_appsink is Gst.App.Sink) {
            this.sink = (Gst.Element) maybe_appsink;
            this.appsink = (Gst.App.Sink) maybe_appsink;
        } else {
            // this should never happen unless the GStreamer install is borked
            error("appsink was somehow not a GstAppSink");
        }

        // a handy temorary array of all our elements
        Gst.Element[] elements = {
            this.queue,
            this.muxer,
            this.infer_qa,
            this.infer_dr,
            this.conv,
            this.sink,
        };

        // add them all to self
        foreach (var e in elements) {
            assert(this.add(e));
        }

        // link all elements
        assert(this.queue.link_many(this.muxer, this.infer_qa, this.infer_dr,
            this.conv, this.sink));
        
        // Get a sink pad from the muxer and ghost it to this bin
        var muxer_sink = muxer.get_request_pad("sink_0");
        if (muxer_sink is Gst.Pad) {
            var ghost_sink = new Gst.GhostPad("sink", (!)muxer_sink);
            assert(this.add_pad(ghost_sink));
        } else {
            error(@"could not get sink pad from $(muxer.name)");
        }
    }

    /**
     * Create a PhotoBin with an optional name.
     */
    public PhotoBin(PhotoBinConfig? config = null, string? name = null)
    throws PhotoBinError.BAD_CONFIG {
        if (config != null) {
            this.config = (!) config;
            this.config.validate();
        }
        if (name != null) {
            this.name = (!) name;
        }
    }

    /** CALLBACKS */

    /**
     * A {@link Gst.PadProbeCallback} that drops buffers while frames_to_capture
     * is zero. Decrements frames_to_capture while holding it's lock.
     */
    public virtual Gst.PadProbeReturn
    on_queue_sink_buffer(Gst.Pad _, Gst.PadProbeInfo __) {
        lock (this.frames_to_capture) {
            if (this.frames_to_capture != 0) {
                // check something didn't go very wrong and we wrapped around
                assert(this.frames_to_capture < 100000000);
                // decrement and let the buffer through
                this.frames_to_capture -= 1;
                return Gst.PadProbeReturn.OK;
            }
            return Gst.PadProbeReturn.DROP;
        }
    }


    /** END CALLBACKS */

    public virtual Gdk.Pixbuf?
    capture() throws CaptureError {
        // reset frames_to_capture which will let num_buffers through, though
        // not all of them will reach the appsink.
        lock(this.frames_to_capture) {
            this.frames_to_capture = this.config.num_buffers;
        }

        // la la la, we wait for stuff

        // some bindings here are actually wrong. The docs say, that this
        // return is nullable, so we cast to that and check for null.
        var sample = (Gst.Sample?)this.appsink.pull_sample();
        if (sample == null) {
            throw new CaptureError.PULL_SAMPLE(
                @"Failed to pull sample from $(this.appsink.name)");
        }


        return null;
    }

    //TODO(mdegans): async capture method
    public virtual async Gdk.Pixbuf?
    capture_async() throws CaptureError {
        this.appsink.set_emit_signals(true);

        lock(this.frames_to_capture) {
            this.frames_to_capture= this.config.num_buffers;
        }

        // some bindings here are actually wrong. The docs say, that this
        // return is nullable, so we cast to that and check for null.
        var sample = (Gst.Sample?) yield this.appsink.pull_sample();
        if (sample == null) {
            throw new CaptureError.PULL_SAMPLE(
                @"Failed to pull sample from $(this.appsink.name)");
        }

        return null;
    }
}

} // namespace Gst.Smart