/* qadr_utils.h
 *
 * Copyright 2020 Michael de Gans <47511965+mdegans@users.noreply.github.com>
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

#ifndef C819A85C_0692_42B0_A6A3_D64D3FE9454D
#define C819A85C_0692_42B0_A6A3_D64D3FE9454D

#include <gst/gst.h>

G_BEGIN_DECLS

/**
 * @brief Get the approximate illumination of the buffer.
 *
 * @param buf a GstBuffer with nvmanualcam::Metadata attached.
 *
 * @return the lux of the image or -1 on failure
 */
float nvmanualcam_get_lux(GstBuffer* buf);
/**
 * @brief Get the approximate sharpness of the buffer.
 *
 * @param buf a GstBuffer with nvmanualcam::Metadata attached.
 * @param left the left coordinate of the ROI (0.0-1.0)
 * @param top the rop coordinate of the ROI (0.0-1.0)
 * @param right the right coordinate of the ROI (0.0-1.0)
 * @param bottom the bottom coordinate of the ROI (0.0-1.0)
 *
 * @return the sharpness of the image's roi or -1 on failure.
 */
float nvmanualcam_get_sharpness(GstBuffer* buf,
                                float left,
                                float top,
                                float right,
                                float bottom);
/**
 * @brief Remove nvmanualcam::Metadata from a buffer
 *
 * @param buf the buffer
 *
 * @return true on success
 * @return false on failure
 */
bool nvmanualcam_destroy_meta(GstBuffer* buf);

// TODO(mdegans): add a dump metadata function

/**
 * @brief Get the qa score from the GstBuffer.
 *
 * @param buf buffer with QA DeepStream metadata attached
 * @return float
 */
float qadr_get_qa_score(GstBuffer* buf);

/**
 * @brief Get the DR evaluation from the GstBuffer.
 *
 * @param buf buffer with DR DeepStream metadata attached
 * @return float
 *
 */
bool qadr_has_disease(GstBuffer* buf);

G_END_DECLS

#endif /* C819A85C_0692_42B0_A6A3_D64D3FE9454D */
