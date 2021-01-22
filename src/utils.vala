/* utils.vala
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

static void destroy_buffer(uint8[] _, void* buffer) {

}

public Gdk.Pixbuf?
sample_to_pixbuf(Gst.Sample sample, Gst.MapFlags flags = Gst.MapFlags.READ)
throws CaptureError {
    // try to get buffer from the sample
    var buf = sample.get_buffer();
    if (buf == null) {
        throw new CaptureError.GET_BUFFER(
            "failed to get buffer from sample");
    }

    // try to get caps from the sample
    var caps = sample.get_caps();
    if (caps == null) {
        throw new CaptureError.GET_CAPS(
            "failed to get caps from sample");
    }

    // get VideoInfo from caps
    var vid_info = new Gst.Video.Info();
    if (!vid_info.from_caps((!)caps)) {
        throw new CaptureError.PARSE_INFO(
            "failed to parse Gst.Video.Info from caps");
    }

    // map the above to a map
    var map_info = Gst.MapInfo();
    if (!((!)buf).map(out map_info, flags)) {
        throw new CaptureError.BUFFER_MAP(
            "failed to map buffer");
    }

    // GAH. there is a way to add user_data. I just need to figure it out.
    var pixbuf = new Gdk.Pixbuf.from_data(
        map_info.data, Gdk.Colorspace.RGB, true, 8, vid_info.width,
        vid_info.height, vid_info.stride, destroy_buffer, buf);

    return null;
}

} // namespace Gst.Smart