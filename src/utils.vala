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

namespace GstSmart {

/**
 * General errors for the GstSmart namespace.
 */
public errordomain ElementError {
    CONFIG,
    CREATE,
    ADD,
    LINK,
    GHOST,
    PAD,
    INTERFACE,
    CAPS,
}

/**
 * Errors related to capture.
 */
public errordomain CaptureError {
    UNKNOWN,
    FOCUS,
    ALIGN,
    ZOOM,
    FLASH,
    TOO_DARK,
    QA_FAILED,
    PULL_SAMPLE,
    GET_BUFFER,
    GET_CAPS,
    PARSE_INFO,
    BUFFER_MAP,
    NOT_READY,
}

/**
 * Just a helper function to create an element. This won't return null (from 
 * Vala anyway.).
 *
 * @throws ElementError.CREATE on failure
 */
static Gst.Element
create_element(string factory_name, string? name = null)
throws ElementError.CREATE {
    // try to create our element (this can be null)
    var maybe_element = Gst.ElementFactory.make(factory_name, name);
    // type check
    if (!(maybe_element is Gst.Element)) {
        throw new ElementError.CREATE(
            @"could not create \"$(factory_name)\"");
    }
    return (!) maybe_element;
}

/**
 * Links elements or throws.
 */
static void
link_elements(Gst.Element[] elements) 
throws ElementError.LINK {
    // Link all elements verbosely
    Gst.Element? prev_e = null;
    foreach (var e in elements) {
        if (prev_e != null) {
            var success = ((!)prev_e).link(e);
            if (!success) {
                throw new ElementError.LINK(
                    @"could not link $(((!)prev_e).name) to $(e.name)");
            }
        }
        prev_e = e;
    }
}

//  /**
//   * Link pads a to be and throw on failure.
//   * 
//   * @throws ElementError.LINK on failure
//   */
//  static void
//  link_pads_and_check(Gst.Pad a, Gst.Pad b)
//  throws ElementError.LINK {
//      var ret = a.link(b);
//      if (ret != Gst.PadLinkReturn.OK) {
//          throw new ElementError.LINK(
//              @"Can't link $(a.parent.name):$(a.name) to $(b.parent.name):$(b.name) because $(ret.to_string())");
//      }
//  }

//  /**
//   * Requests a request pad and check for failure.
//   */
//  static Gst.Pad
//  request_pad_and_check(Gst.Element e, string pad_name)
//  throws ElementError.PAD {
//      var maybe_pad = e.get_request_pad(pad_name);
//      if (maybe_pad == null) {
//          throw new ElementError.PAD(
//              @"Could not request pad $(pad_name) from $(e.name)");
//      }
//      return (!)maybe_pad;
//  }

//  /**
//   * Requests a static pad and check for failure.
//   */
//  static Gst.Pad
//  static_pad_and_check(Gst.Element e, string pad_name)
//  throws ElementError.PAD {
//      var maybe_pad = e.get_static_pad(pad_name);
//      if (maybe_pad == null) {
//          throw new ElementError.PAD(
//              @"Could not request pad $(pad_name) from $(e.name)");
//      }
//      return (!)maybe_pad;
//  }

/**
 * Ghost an existing pad to the outside of a bin as name.
 *
 * @param pad the existing pad to ghost
 * @param bin the bin to ghost to
 * @param name of the pad to ghost as
 *
 * @throws ElementError.GHOST on failure
 */
static void
ghost_existing_pad(Gst.Pad pad, Gst.Bin bin, string name)
throws ElementError.GHOST {
    Gst.GhostPad? maybe_ghost = new Gst.GhostPad(name, pad);
    if (maybe_ghost == null) {
        throw new ElementError.GHOST(
            @"Could not create ghost pad from $(pad.parent.name):$(pad.name)");
    }
    if (!bin.add_pad((!)maybe_ghost)) {
        throw new ElementError.GHOST(
            "could not add queue ghost pad to bin.");
    }
}

/**
 * Create new Gst.Caps with the specified format.
 * 
 * @param fmt the GstVideoFormat to use as short string (eg. RGBA)
 * @param gpu if true, uses memory:NVMM
 * 
 * @throws ElementError.CAPS on failure
 */
static Gst.Caps
caps_with_format(string format, bool gpu = false)
throws ElementError.CAPS {
    // FIXME(mdegans) use Gst.Video.Format instead
    string prefix = gpu ? "video/x-raw(memory:NVMM)" : "video/x-raw";
    var caps_str = @"$(prefix), format=(string)$(format)";
    var maybe_caps = Gst.Caps.from_string(caps_str);
    if (maybe_caps == null) {
        throw new ElementError.CAPS(
            @"Could not create GstCaps from string: \"$(caps_str)\"");
    }
    return (!)maybe_caps;
}

static string join_string_list(List<string> list, string sep = ", ") {
    var arr = new string?[list.length()];
    size_t i = 0;
    foreach (var s in list) {
        arr[i] = s;
        i++;
    }
    return string.joinv(", ", arr);
}


//  /**
//   * Ghost a pad named `name` from an element to the outside of a bin.
//   *
//   * @param the element to ghost from
//   * @param bin the bin to ghost to
//   * @param name of the pad to ghost
//   */
//  static void
//  ghost_static_pad(Gst.Element e, Gst.Bin bin, string name)
//  throws ElementError.GHOST {
//      var maybe_pad = e.get_static_pad(name);
//      if (maybe_pad == null) {
//          throw new ElementError.GHOST(
//              "Could not get sink pad from queue.");
//      }
//      var pad = (!) maybe_pad;
//      ghost_existing_pad(pad, bin, name);
//  }

public struct Resolution {
    uint width;
    uint height;
}

public struct Point {
    float x;
    float y;
}

public struct Rectangle {
    Point tl;
    Point br;
    public float width { get { return tl.x - br.x; }}
    public float height  { get { return tl.y - br.y; }}
}

} // namespace GstSmart