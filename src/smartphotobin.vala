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

namespace GstSmart {

/**
 * Config for PhotoBin.
 */
public class PhotoBinConfig: Object {
	public int sensor_id { get; set; default = 0; }
	public int sensor_mode { get; set; default = -1; }
	public QaDrBinConfig qadr { get; set; default = new QaDrBinConfig(); }
	public virtual void validate() throws ElementError.CONFIG {
		this.qadr.validate();
	}
}

public enum Eye {
	RIGHT,
	LEFT,
}

public struct BayerGains {
	float r;
	float g_even;
	float g_odd;
	float b;
	public BayerGains() {
		r = DEFAULT_BAYER_GAINS.r;
		g_even = DEFAULT_BAYER_GAINS.g_even;
		g_odd = DEFAULT_BAYER_GAINS.g_odd;
		b = DEFAULT_BAYER_GAINS.b;
	}
}

public struct FlashConfig {
	float delay;
	uint offset;
	float duration;
	float overlap;
	float brightness;
	public FlashConfig() {
		delay = 0.0f;
		offset = 0;
		duration = 1.0f;
		overlap = 0.25f;
		brightness = 1.0f;
	}
}

static uint CaptureConfig_id_counter;
static Mutex CaptureConfig_id_counter_mx;
public struct CaptureConfig {
	FlashConfig flash;
	float exposure;
	float gain;
	BayerGains wb;
	Eye eye;
	uint id;
	public CaptureConfig() {
		flash = FlashConfig();
		exposure = 1.0f;
		gain = 1.0f;
		wb = BayerGains();
		eye = Eye.LEFT;
		CaptureConfig_id_counter_mx.lock();
		id = CaptureConfig_id_counter++;
		CaptureConfig_id_counter_mx.unlock();
	}
}

/**
 * PhotoBin takes a series of buffers in when triggered, chooses the best one,
 * optionally performs in inference on that best one.
 */
public class PhotoBin: Gst.Pipeline {
	/** BEGIN CONSTS */
	private const uint MAX_REQUESTS = 10;
	/** END CONSTS */

	/** BEGIN PRIVATE CLASSES/STRUCTS */

	/** Class for capture requests */
	private struct Request {
		public CaptureConfig config;
		public Request(CaptureConfig config) {
			this.config = config;
		}
	}

	/** END PRIVATE CLASSES/STRUCTS */

	/** BEGIN ENUMS */

	public enum CaptureStatus {
		NOT_READY,
		REQUESTED,
		FOCUSED,
		ALIGNED,
		ZOOMED,
		READY,
		QADR,
	}

	/** END ENUMS */

	/** BEGIN MEMBER VARIABLES */

	/** Our camera source */
	private dynamic Gst.Element camera;
	/** Our control element */
	private dynamic Gst.Element ptzf;
	/** Cached state of ptzf.focused */
	private bool cached_ptzf_focused = false;
	/** Cached state of ptzf.aligned */
	private bool cached_ptzf_aligned = false;
	/** Cached state of ptzf.zoomed */
	private bool cached_ptzf_zoomed = false;
	/** Cached state of ptzf.capture_ready */
	private bool cached_ptzf_capture_ready = false;
	//  private dynamic Gst.Element flash;

	/** A tee to split the pipeline */
	private Gst.Element tee;
	/** A Queue for the display branch */
	private Gst.Element display_q;
	/** Nvidia EGL transform element */
	private Gst.Element egl_tx;
	/** Nvidia EGL display element, provides GstVideoOverlay interface */
	private Gst.Element egl_display;
	/** The GstVideoOverlay interface to use for GUI stuff */
	public Gst.Video.Overlay overlay;

	/** A Queue for the inference brahch */
	private Gst.Element infer_q;
	/** Our Quality Assurace and Diagnostics bin */
	private QaDrBin? qadr;
	/** Converter to CPU buffer */
	private Gst.Element sink_conv;
	/** Appsink as Gst.Element */
	private Gst.Element sink;

	/** Capture ID of the next capture */
	private uint capture_id = 0;
	/** Allow this many buffers through to the QADR queue */
	private int allow_buffers = 0;
	/** Whether we're prerolling */
	private bool prerolling = true;
	/** If flash firing is needed. This is it's config. */
	private FlashConfig? flash_config = null;


	/** END MEMBER VARIABLES */

	/** BEGIN GOBJECT PROPERTIES */

	/** Our sink as GstAppSink, NULL is checked for. */
	[Description(
		nick = "appsink",
		blurb = "GstAppSink for buffers that pass QA.")]
	public Gst.App.Sink appsink {
		get {
			var ret = this.sink as Gst.App.Sink;
			assert(ret != null);
			return (!)ret;
		}
	}

	/** Our configuration */
	private PhotoBinConfig _config;
	[Description(
		nick = "Config",
		blurb = "Configuration. Validate before or this element will panic.")]
	public PhotoBinConfig config {
		get {
			return this._config;
		}
		set {
			try {
				value.validate();
			} catch (ElementError.CONFIG e) {
				// We panic here because it's probably a programmer error.
				// Programmer should validate the config before setting, parse
				// any GError and have the end user fix it.
				error(
					@"Could not set config on $(this.name) because: $(e.message)");
			}
			this._config = value;
			if (this.qadr is QaDrBin) {
				((!)this.qadr).config = value.qadr;
			}
			this.camera.sensor_id = value.sensor_id;
			this.camera.sensor_mode = value.sensor_mode;
		}
	}

	/** Element status. */
	[Description(
		nick = "Status",
		blurb = "The capture status of this elmeent.")]
	public CaptureStatus status {
		get; private set; default = CaptureStatus.NOT_READY; }

	/** Whether we're capturing or not. */
	[Description(
		nick = "Capturing",
		blurb = "Whether we're capturing or not.")]
	public bool capturing { get; private set; default = false; }

	/** Whether deepstream was enabled at compile time */
	[Description(
		nick = "DeepStream Enabled",
		blurb = "Whether we're compiled with DeepStream support.")]
	public bool has_deepstream { get { return HAS_DEEPSTREAM; } }

	/** Brightness in 0.0-1.0 range */
	[Description(
		nick = "Brightness",
		blurb = "Camera gain in 0.0-1.0 range.")]
	public float brightness {
		get {
			float gain = this.camera.gain;
			return (gain - MIN_GAIN) / (MAX_GAIN - MIN_GAIN);
		}
		set {
			assert(value >= 0.0 && value <= 1.0);
			this.camera.gain = value * (MAX_GAIN - MIN_GAIN) + MIN_GAIN;
		}
	}
	[Description(
		nick = "Zoom",
		blurb = "Camera zoom in 0.0-1.0 range.")]
	public float zoom {
		get {
			return this.ptzf.zoom;
		}
		set {
			this.ptzf.zoom = value;
		}
	}

	/** Current state of this element. */
	[Description(
		nick = "State",
		blurb = "Current GstState of this element. Useful for UI.")]
	public Gst.State state { get; private set; }

	static construct {
		set_static_metadata(
			"Smart Photo Bin",
			"Sink/Network",
			"Top level pipeline for libazabache.",
			"Michael de Gans <michael.john.degans@gmail.com>");

		// This element is a top-level pipeline and has no pads, which would
		// otherwise go here.
	}

	/** END GOBJECT PROPERTIES */

	construct {
		try {
			// create our elements (or panic)
			this.camera = create_element("nvmanualcamerasrc", "camera");
			this.ptzf = create_element("ptzf", "ptzf");
			this.tee = create_element("tee", "tee");

			this.display_q = create_element("queue", "display_q");
			this.egl_tx = create_element("nvegltransform", "egl_tx");
			this.egl_display = create_element("nveglglessink", "egl_display");
			var maybe_overlay = this.egl_display as Gst.Video.Overlay;
			if (maybe_overlay == null) {
				error("`nveglglessink` has broken GstVideoOverlay interface.");
			}
			this.overlay = (!)maybe_overlay;

			this.infer_q = create_element("queue", "infer_q");
			if (HAS_DEEPSTREAM) {
				this.qadr = new QaDrBin(null, "qa");
			} else {
				this.qadr = null;
			}
			this.sink_conv = create_element("nvvidconv", "sink_conv");
			this.sink = create_element("appsink", "sink");
		} catch (ElementError.CREATE e) {
			error(e.message);
		}

		// a handy temorary array of all our elements
		Gst.Element?[] elements = {
			this.camera,
			this.ptzf,
			this.tee,

			this.display_q,
			this.egl_tx,
			this.egl_display,

			this.infer_q,
			this.qadr,
			this.sink_conv,
			this.sink,
		};

		// add them all to self
		foreach (var e in elements) {
			if (e == null) {
				continue;
			}
			if (!this.add((!)e)) {
				error(@"could not add $(((!)e).name) to $(this.name)");
			}
		}

		// Turn camera metadata on.
		this.camera.bayer_sharpness_map = true;
		this.camera.metadata = true;
		// Configure ptzf
		// FIXME(mdegans): configure ptzf here, provide getters/setters
		// Set RGBA caps on appsink (built in capsfilter)
		// make sure appsink emites signals

		this.config = new PhotoBinConfig();

		// setup appsink
		try {
			this.appsink.set_caps(caps_with_format("RGBA"));
		} catch (ElementError.CAPS e) {
			error(e.message);
		}
		this.appsink.emit_signals = true;
		this.appsink.new_sample.connect(this.on_new_sample);

		// link all elements
		try {
			// link the beginning of the pipeline
			link_elements({this.camera, this.ptzf, this.tee});

			// link the tee to the queues
			link_elements({this.tee, this.display_q});
			link_elements({this.tee, this.infer_q});

			// link the display branch
			link_elements({this.display_q, this.egl_tx, this.egl_display});

			// link the inference / appsink branch
			if (this.qadr is QaDrBin) {
				link_elements({this.infer_q, (!)this.qadr, this.sink_conv, this.sink});
			} else {
				link_elements({this.infer_q, this.sink_conv, this.sink});
			}
		} catch (ElementError.LINK e) {
			error(e.message);
		}

		// Connect any callbacks. 
		// TODO(mdegans): these 4 below can probably be refactored into a single
		//  closure. 
		// These forward ptzf property changes to signals on this element.
		this.ptzf.notify["focused"].connect((_, pspec) => {
			debug(@"$(pspec.name) emitted from $(this.ptzf.name)");
			// get focused as boolean
			bool current_focused = this.ptzf.focused;
			// if it's not the same as our cached value, update it and emit
			// the `focused` signal.
			if (current_focused != this.cached_ptzf_focused) {
				this.cached_ptzf_focused = current_focused;
				focused(current_focused);
			}
		});
		this.ptzf.notify["aligned"].connect((_, pspec) => {
			debug(@"$(pspec.name) emitted from $(this.ptzf.name)");
			// get focused as boolean
			bool current_aligned = this.ptzf.aligned;
			// if it's not the same as our cached value, update it and emit
			// the `focused` signal.
			if (current_aligned != this.cached_ptzf_aligned) {
				this.cached_ptzf_aligned = current_aligned;
				aligned(current_aligned);
			}
		});
		this.ptzf.notify["zoomed"].connect((_, pspec) => {
			debug(@"$(pspec.name) emitted from $(this.ptzf.name)");
			// get focused as boolean
			bool current_zoomed = this.ptzf.zoomed;
			// if it's not the same as our cached value, update it and emit
			// the `focused` signal.
			if (current_zoomed != this.cached_ptzf_focused) {
				this.cached_ptzf_zoomed = current_zoomed;
				zoomed(current_zoomed);
			}
		});
		this.ptzf.notify["capture-ready"].connect((_, pspec) => {
			debug(@"$(pspec.name) emitted from $(this.ptzf.name)");
			// get focused as boolean
			bool current_capture_ready = this.ptzf.capture_ready;
			// if it's not the same as our cached value, update it and emit
			// the `focused` signal.
			if (current_capture_ready != this.cached_ptzf_capture_ready) {
				this.cached_ptzf_capture_ready = current_capture_ready;
				capture_ready(current_capture_ready);
			}
		});
		// connect pad probe callback to drop buffers if not ready
		var maybe_infer_q_sink = this.infer_q.get_static_pad("sink");
		assert(maybe_infer_q_sink is Gst.Pad);
		var infer_q_sink = (!)maybe_infer_q_sink;
		infer_q_sink.add_probe(Gst.PadProbeType.BUFFER, this.on_infer_q_buf);
		// connect pad probe to fire the flash. This needs to happen at the
		// source so it can be on the border of a frame. Syncronization cannot
		// be guaranteed because of how the argus *source* works (the lib has
		// better support, but we can get close enough here)
		var maybe_camera_src = this.camera.get_static_pad("src");
		assert(maybe_camera_src is Gst.Pad);
		var camera_src = (!)maybe_camera_src;
		camera_src.add_probe(Gst.PadProbeType.BUFFER, on_camera_buf);
	}

	/**
	 * Create a PhotoBin with an optional config and name.
	 */
	public PhotoBin(PhotoBinConfig? config = null,
					string? name = null) {
		if (config != null) {
			this.config = (!)config;
		}
		if (name != null) {
			this.name = (!)name;
		}
	}

	/** BEGIN CALLBACKS */

	/** A pad callback for the camera elment to fire the flash. */
	private Gst.PadProbeReturn
	on_camera_buf(Gst.Pad pad, Gst.PadProbeInfo info) {
		lock(this.capturing) {
			if (this.flash_config != null) {
				var conf = (!)this.flash_config;
				this.flash_config = null;
				var maybe_buf = info.get_buffer();
				flash_fire((!)maybe_buf, conf);
			}
		}
		return Gst.PadProbeReturn.OK;
	}

	/** Emits the above `new-buffer` on an appsink `new-sample` */
	private Gst.FlowReturn on_new_sample(Gst.Element _) {
		Gst.Sample? maybe_sample = this.appsink.pull_sample();
		if (maybe_sample == null) {
			capture_failure(
				@"Could not pull sample from $(this.name):$(this.sink.name).");
			return Gst.FlowReturn.ERROR;
		}
		var maybe_buf = ((!)maybe_sample).get_buffer();
		if (maybe_buf == null) {
			capture_failure(@"Could not get buffer from sample.");
			return Gst.FlowReturn.ERROR;
		}
		capture_success((!)maybe_buf, this.appsink.caps);
		return Gst.FlowReturn.OK;
	}

	/** Controls buffer flow into the infer_q for QA and DR */
	private Gst.PadProbeReturn
	on_infer_q_buf(Gst.Pad pad, Gst.PadProbeInfo info) {
		// if we're prerolling, we need to let buffers through;
		if (this.prerolling) {
			return Gst.PadProbeReturn.OK;
		}
		lock (this.allow_buffers) {
			if (this.allow_buffers > 0) {
				this.allow_buffers--;
				return Gst.PadProbeReturn.OK;
			} else {
				// if we've just finished, notify `capturing` off.
				if (this._capturing) {
					this.capturing = false;
				}
				// drop the buffer
				return Gst.PadProbeReturn.DROP;
			}
		}
	}

	/** END CALLBACKS */

	/** BEGIN SIGNALS */

	/** Signal emitted when focus is (really) changed */
	[Signal(no_recurse = "true")]
	public virtual signal void focused(bool is_focused) {
		if (is_focused) {
			this.status = CaptureStatus.FOCUSED;
			debug(@"Focused.");
		} else {
			debug("No longer in focus.");
		}
	}

	/** Signal emitted when alignment is (really) changed */
	[Signal(no_recurse = "true")]
	public virtual signal void aligned(bool is_aligned) {
		if (is_aligned) {
			this.status = CaptureStatus.ALIGNED;
			debug(@"Aligned");
		} else {
			debug("No longer aligned.");
		}
	}

	/** Signal emitted when we're zoomed into an eye */
	[Signal(no_recurse = "true")]
	public virtual signal void zoomed(bool is_zoomed) {
		if (is_zoomed) {
			// TODO(mdegans): implement eye]
			this.status = CaptureStatus.ZOOMED;
			debug("Zoomed into eye");
		} else {
			debug("No longer zoomed in.");
		}
	}

	/** Signal emitted when capture_ready state is changed */
	[Signal(no_recurse="true")]
	public virtual signal void capture_ready(bool is_ready) {
		if (is_ready) {
			this.status = CaptureStatus.READY;
			debug("Ptzf ready for capture.");
		} else {
			debug("No longer ready for capture.");
		}
	}

	/** Signal emitted when capture fails */
	[Signal(no_recurse="true")]
	public virtual signal void capture_failure(string reason) {
		debug(@"Capture ID $(this.capture_id) failed because: $(reason)");
	}

	/** Signal emitted when a new buffer reaches the appsink */
	[Signal(no_recurse="true")]
	public virtual signal void capture_success(Gst.Buffer buf, Gst.Caps caps) {
		debug("Buffer passed QA and is ready at the appsink!");
	}

	/** Handle when flash needs to be fired. Handlers should not block. */
	[Signal(no_recurse="true")]
	public virtual signal void flash_fire(Gst.Buffer buf, FlashConfig config) {
		debug("Signaling flash-fire!");
	}

	/** END SIGNALS */

	/** BEGIN METHODS */

	/**
	 * Request a capture.
	 */
	public void capture(CaptureConfig config) {
		if (this.capturing) {
			capture_failure("Capture already in progress");
		}
		lock(this.capturing) {
			this.status = CaptureStatus.REQUESTED;
			this.capturing = true;

			// set properties
			this.camera.exposuretime = config.exposure;
			this.camera.gain = config.gain;
			// TODO: WB

			this.allow_buffers = 5;
			this.flash_config = config.flash;
		}
	}

	/** END METHODS */

	/** BEGIN OVERRIDES */

	/**
	 * Called when state is changed. Used to set `prerolling` state, which
	 * controls the flow to the QA Branch (and the appsink).
	 */
	public override void
	state_changed(Gst.State old, Gst.State current, Gst.State pending) {
		// if we're not yet in the playing state, we should disable QA.
		// otherwise QA will never complete.
		state = current;
		if (current < Gst.State.PLAYING) {
			debug("We're prerolling still. QA is disabled.");
			this.prerolling = true;
		} else {
			debug("We're done prerolling. QA is enabled.");
			this.prerolling = false;
		}
	}

	/** END OVERRIDES */
}

} // namespace GstSmart