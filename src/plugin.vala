/* plugin.vala
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


// ignore any squigglies here. Meson will format this template
// with configure_file (see this folder's meson.build)
const Gst.PluginDesc gst_plugin_desc = {
	@gst_major_version@, @gst_minor_version@, 
	"@project_name@", 
	"@project_description@",
	plugin_init,
	"@version@",
	"@license@",
	"@proj_url@",
	"@package_name@",
	"@origin@"
};

public static bool plugin_init(Gst.Plugin p) {
	return (
		Gst.Element.register(
			p,
			"smartphotobin",
			Gst.Rank.NONE,
			typeof(GstSmart.PhotoBin)
		) &&
		Gst.Element.register(
			p,
			"qadrbin",
			Gst.Rank.NONE,
			typeof(GstSmart.QaDrBin)
		)
	);
}

[CCode (
	cprefix = "GstSmart",
	gir_namespace = "GstSmart",
	gir_version = "@gir_version@",
	lower_case_cprefix="gst_smart_",
	cheader_filename="smartphotobin.h")]
namespace GstSmart {

// Defaults for GstSmart.PhotoBin

/** Inference Element name */
public const string INFERENCE_ELEMENT = "nvinfer";
/** Video converter element name */
public const string CONVERSION_ELEMENT = "nvvideoconvert";
/** Muxer elemetn name (preps images for inference) */
public const string MUXER_ELEMENT = "nvstreammux";
/** Duration flash will be fired for in frames */
public const float DEFAULT_FLASH_DURATION = 1.0f;
/** Default bayer gains (white balance) for nvmanualcamerasrc */
public const BayerGains DEFAULT_BAYER_GAINS = {
	1.0f, 1.0f, 1.0f, 1.0f
};

// Defaults for GstSmart.QaDrBin

/** Default Quality Assurance model */
public const string DEFAULT_QA_MODEL = "@DEFAULT_QA_MODEL@";
/** Default Diagnosis/Whatever model */
public const string DEFAULT_DR_MODEL = "@DEFAULT_DR_MODEL@";

}