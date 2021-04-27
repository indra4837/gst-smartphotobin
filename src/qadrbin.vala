/* qabin.vala
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

// C++ stuff we'll use in this file
[CCode (cname = "nvmanualcam_get_lux")]
static extern float nvmanualcam_get_lux(Gst.Buffer buf);
//  [CCode (cname = "nvmanualcam_get_sharpness")]
//  static extern float nvmanualcam_get_sharpness(Gst.Buffer buf,
//  									   float left,
//  									   float top,
//  									   float right,
//  									   float bottom);
[CCode (cname = "nvmanualcam_destroy_meta")]
static extern bool nvmanualcam_destroy_meta(Gst.Buffer buf);

[CCode (cname = "qadr_get_qa_score")]
static extern float qadr_get_qa_score(Gst.Buffer buf);

[CCode (cname = "qadr_has_disease")]
static extern bool qadr_has_disease(Gst.Buffer buf);

static List<string> validate_model_ini(string path) {
	var errors = new List<string>();
	var file = File.new_for_path(path);
	if (!file.query_exists()) {
		errors.append(@"model path: \"$(path)\" does not exist");
	}
	return errors;
}

public enum QaFailure {
	SHARPNESS,
	BRIGHTNESS,
	QA_SCORE,
}

/**
 * Holds configuration for QaDrBin.
 */
public class QaDrBinConfig: Object {
	/** Path to the quality assurance model .ini */
	public string qa_model_config { get; set; default = DEFAULT_QA_MODEL; }
	/** Path to the diagnosis/whatever model .ini */
	public string dr_model_config { get; set; default = DEFAULT_DR_MODEL; }
	/** Resolution nvstreammux will scale to (models will expect this res) */
	public Resolution model_res { get; set; default = DEFAULT_MODEL_RESOLUTION; }
	// FIXME(mdegans): make these configurable at build time.
	/** Minimum model score for the image */
	public float min_qa_score { get; set; default = -1.0f; }
	/** Minimum illumination in lux */
	public float min_lux { get; set; default = -1.0f; }
	/** Minimum sharpness score */
	public float min_sharpness { get; set; default = -1.0f; }
	/** Sharpness Region of Interest */
	//  public Rect sharpness_roi { get; set; }

	public virtual void validate() throws ElementError.CONFIG {
		var errors = new List<string>();
		errors.concat(validate_model_ini(this.qa_model_config));
		errors.concat(validate_model_ini(this.dr_model_config));
		//  append strings to errors here
		if (errors.length() != 0) {
			string joined = join_string_list(errors);
			throw new ElementError.CONFIG(
				@"QaDrBinConfig validation failed because: $(joined)");
		}
	}
}

/**
 * QaDrBin is a quality assurance and diagnostics bin.
 */
public class QaDrBin: Gst.Bin {
	/** Our configuration */
	private QaDrBinConfig _config;
	[Description(
		nick = "config",
		blurb = "Configuration. Validate before or this element will panic.")]
	public QaDrBinConfig config {
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
			this.qa.config_file_path = value.qa_model_config;
			this.dr.config_file_path = config.dr_model_config;
			this.muxer.width = config.model_res.width;
			this.muxer.height = config.model_res.height;
		}
	}
	

	// child elements

	private dynamic Gst.Element muxer;
	private dynamic Gst.Element qa;
	private dynamic Gst.Element dr;
	private dynamic Gst.Element demux;

	/** Used when prerolling to let all buffers through */
	private bool prerolling = true;

	static construct {
		set_static_metadata(
			"Photo Quality Assurance and Diagnostics Bin",
			"Filter",
			"Rejects bad photos, chooses the best.",
			"Michael de Gans <michael.john.degans@gmail.com>");

		Gst.StaticCaps sink_caps = {
			(Gst.Caps)null,
			// FIXME(mdegans): copy nvstreammux caps exactly
			"video/x-raw(memory:NVMM), format={ (string)NV12, (string)RGBA }",
		};
		Gst.StaticCaps src_caps = {
			(Gst.Caps)null,
			// FIXME(mdegans): copy nvstreammux caps exactly
			"video/x-raw(memory:NVMM), format={ (string)NV12, (string)RGBA }",
		};

		Gst.StaticPadTemplate sink_pad_template = {
			"sink",
			Gst.PadDirection.SINK,
			Gst.PadPresence.ALWAYS,
			sink_caps,
		};
		Gst.StaticPadTemplate src_pad_template = {
			"src",
			Gst.PadDirection.SRC,
			Gst.PadPresence.ALWAYS,
			sink_caps,
		};
		add_static_pad_template(sink_pad_template);
		add_static_pad_template(src_pad_template);
	}

	construct {
		// construct our elements (or panic)
		try {
			this.muxer = create_element(MUXER_ELEMENT, "muxer");
			this.qa = create_element(INFERENCE_ELEMENT, "qa");
			this.dr = create_element(INFERENCE_ELEMENT, "dr");
			this.demux = create_element(DEMUXER_ELEMENT, "demux");
		} catch (ElementError.CREATE e) {
			error(e.message);
		}

		// handy array to iterate through
		Gst.Element[] elements = {
			this.muxer,
			this.qa,
			this.dr,
			this.demux,
		};

		// add all elements to self (or panic)
		foreach (var e in elements) {
			if (!this.add((!)e)) {
				error(@"could not add $(((!)e).name) to $(this.name)");
			}
		}

		// settings for nvidia's stream muxer
		this.muxer.batch_size = 1; // we only ever have one source
		this.muxer.enable_padding = true; // maintain aspect ratio
		this.muxer.live_source = true; // docs say to use this

		this.qa.unique_id = 171; // 17 == q, a == 1
		assert(((int)this.qa.unique_id) == 171);
		this.dr.unique_id = 418; // d == 4, r == 18
		assert(((int)this.dr.unique_id) == 418);

		// create the default config (set some element properties)
		this.config = new QaDrBinConfig();

		// Link all elements verbosely (or panic)
		Gst.Element? prev_e = null;
		foreach (var e in elements) {
			if (prev_e != null) {
				var success = ((!)prev_e).link(e);
				if (!success) {
					error(@"could not link $(((!)prev_e).name) to $(e.name)");
				}
			}
			prev_e = e;
		}

		// get pads for callbacks and ghosting
		var maybe_muxer_sink = this.muxer.get_request_pad("sink_0");
		if (maybe_muxer_sink == null) {
			error("Could not get `sink_0` pad from muxer");
		}
		var muxer_sink = (!)maybe_muxer_sink;
		var maybe_demux_src = this.demux.get_request_pad("src_0");
		if (maybe_demux_src == null) {
			error("Could not get src_0 pad from demuxer");
		}
		var demux_src = (!)maybe_demux_src;

		// register a callback to do preliminary checks on photo quality using
		// metadadata computed upstream.
		(void)muxer_sink.add_probe(
			Gst.PadProbeType.BUFFER, on_muxer_sink_buffer);

		// register callbacks to do QA and DR
		var maybe_qa_src = this.qa.get_static_pad("src");
		if (maybe_qa_src == null) {
			error("Could not get `src` pad from qa nvinfer element");
		}
		var qa_src = (!)maybe_qa_src;
		(void)qa_src.add_probe(
			Gst.PadProbeType.BUFFER, on_qa_src_buffer);

		var maybe_dr_src = this.dr.get_static_pad("src");
		if (maybe_dr_src == null) {
			error("Could not get `src` pad from dr nvinfer element");
		}
		var dr_src = (!)maybe_dr_src;
		(void)dr_src.add_probe(
			Gst.PadProbeType.BUFFER, on_dr_src_buffer);

		// ghost pads to the outside of the bin
		try {
			ghost_existing_pad(muxer_sink, this, "sink");
			ghost_existing_pad(demux_src, this, "src");
		} catch (ElementError.GHOST e) {
			error(@"$(this.name) construct failed because: $(e.message)");
		}
	}

	public QaDrBin(
		QaDrBinConfig? config = null,
		string? name = null)
	{
		if (config != null) {
			this.config = (!)config;
		}
		if (name != null) {
			this.name = (!)name;
		}
	}


	/** BEGIN_CALLBACKS */

	/**
	 * Callback to do preliminary QA check. Checks for minimum sharpness and 
	 * brightness. Drops the buffer if any of these checks fail.
	 */
	protected virtual Gst.PadProbeReturn
	on_muxer_sink_buffer(Gst.Pad pad, Gst.PadProbeInfo info) {
		if (this.prerolling) {
			return Gst.PadProbeReturn.OK;
		}
		// Check we have a buffer attached to info. Really this is probably not
		// necessary but the non-null checking encourages us to do this.
		var maybe_buf = info.get_buffer();
		if (maybe_buf == null) {
			// should never happen
			error("Somehow buffer is NULL. Something is very wrong");
		}
		var buf = (!) maybe_buf;

		if (nvmanualcam_get_lux(buf) < this.config.min_lux) {
			return Gst.PadProbeReturn.DROP;
		}

		// TODO(mdegans): for this to work properly we need to get the roi used 
		//  for the upstream buffer. That's probably easiest to do if we write
		//  the metadata upstream in vala and grab it here. Using a GObject
		//  property/signals to update it would introduce a race condition where
		//  the focus ROI could be different here than upstream.

		//  float sharpness = nvmanualcam_get_sharpness(buf,
		//  	this.config.sharpness_roi.x,
		//  	this.config.sharpness_roi.y,
		//  	this.config.sharpness_roi.x + this.config.sharpness_roi.width,
		//  	this.config.sharpness_roi.y + this.config.sharpness_roi.height);
		//  if (sharpness < this.config.min_sharpness) {
		//  	return Gst.PadProbeReturn.DROP;
		//  }

		// some nvidia elements choke on custom metadata on some version of JP,
		// so we'll strip it.
		if (!nvmanualcam_destroy_meta(buf)) {
			warning("somehow could not strip metadata");
		}

		return Gst.PadProbeReturn.OK;
	}

	protected virtual Gst.PadProbeReturn
	on_qa_src_buffer(Gst.Pad pad, Gst.PadProbeInfo info) {
		if (this.prerolling) {
			// we're prerolling -- let the buffer through
			return Gst.PadProbeReturn.OK;
		}
		var maybe_buf = info.get_buffer();
		if (maybe_buf == null) {
			// should never happen
			error("Somehow buffer is NULL. Something is very wrong");
		}
		var buf = (!) maybe_buf;
		float bufscore = qadr_get_qa_score(buf);

		if (bufscore < this.config.min_qa_score) {
			qa_failed(
				buf, QaFailure.QA_SCORE, bufscore, this.config.min_qa_score);
			return Gst.PadProbeReturn.DROP;
		}

		return Gst.PadProbeReturn.OK;
	}

	protected virtual Gst.PadProbeReturn
	on_dr_src_buffer(Gst.Pad pad, Gst.PadProbeInfo info) {
		if (this.prerolling) {
			// we're prerolling -- let the buffer through
			return Gst.PadProbeReturn.OK;
		}
		var maybe_buf = info.get_buffer();
		if (maybe_buf == null) {
			// should never happen
			error("Somehow buffer is NULL. Something is very wrong");
		}
		var buf = (!) maybe_buf;
		if (qadr_has_disease(buf)) {
			// emit disease-found
			disease_found(buf);
		}

		return Gst.PadProbeReturn.OK;
	}

	/** END_CALLBACKS */

	/** BEGIN OVERRIDES */

	/**
	 * Called when state is changed. Used to set `prerolling` state, which
	 * controls the flow to the QA Branch (and the appsink).
	 */
	public override void
	state_changed(Gst.State old, Gst.State current, Gst.State pending) {
		// if we're not yet in the playing state, we should disable QA.
		// otherwise QA will never complete.
		if (current < Gst.State.PLAYING) {
			debug("We're prerolling still. QA is disabled.");
			this.prerolling = true;
		} else {
			debug("We're done prerolling. QA is enabled.");
			this.prerolling = false;
		}
	}

	/** END OVERRIDES */

	/** SIGNALS START */

	/**
	 * Signals when a disease is found on a buffer.
	 */
	public virtual signal void
	disease_found(Gst.Buffer buf) {
		debug(@"disease-found:for buffer with dts:$(buf.dts)");
	}

	/**
	 * Signals when QA fails, either from the model or from brightness/sharpness
	 * checks
	 *
	 * @param buf the buffer for which QA failed.
	 * @param reason the QA failed
	 * @param score of the buffer that's less than...
	 * @param min_score required by the current configuration
	 */
	public virtual signal void
	qa_failed(Gst.Buffer buf, QaFailure reason, float score, float min_score) {
		debug(@"qa-failed:because minimum $(reason.to_string()) not met ($(score) < $(min_score))");
	}

	/** SIGNALS END */

}

} // namespace GstSmart