/* qadr_utils.cpp
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
#ifdef HAS_DEEPSTREAM
#include <gstnvdsmeta.h>
#endif

#include "metadata.hpp"
#include "qadr_utils.h"

using nvmanualcam::attachMetadata;
using nvmanualcam::Metadata;

float nvmanualcam_get_lux(GstBuffer* buf) {
  g_return_val_if_fail(GST_IS_BUFFER(buf), false);
  float lux = -1.0f;
  // it's faster to move and there's no concurrent access, so we we'll steal
  // the metadata and re-attach it.
  auto meta = Metadata::steal(buf);
  if (meta) {
    lux = meta->getSceneLux();
    attachMetadata(std::move(meta), buf);
  } else {
    GST_ERROR("Metadata not on buffer.");
  }
  return lux;
}

float nvmanualcam_get_sharpness(GstBuffer* buf,
                                float left,
                                float top,
                                float right,
                                float bottom) {
  g_return_val_if_fail(GST_IS_BUFFER(buf), false);
  float sharpness = -1.0f;
  // it's faster to move and there's no concurrent access, so we we'll steal
  // the metadata and re-attach it.
  auto meta = Metadata::steal(buf);
  if (meta) {
    auto opt_sharpness = meta->getSharpnessScore(
        Argus::Rectangle<float>(left, top, right, bottom));
    if (opt_sharpness) {
      sharpness = opt_sharpness.value();
    } else {
      GST_ERROR("Metadata is on buffer but couldn't get sharpness score.");
    }
    attachMetadata(std::move(meta), buf);
  } else {
    GST_ERROR("Metadata not on buffer.");
  }
  return sharpness;
}

bool nvmanualcam_destroy_meta(GstBuffer* buf) {
  g_return_val_if_fail(GST_IS_BUFFER(buf), false);
  auto meta = Metadata::steal(buf);
  if (!meta) {
    GST_ERROR("Can't remove metadata since it's not present.");
    return false;
  }
  // just don't re-attach it
  return true;
}

/**
 * @brief Get the qa score from the GstBuffer
 *
 * @param buf
 * @return float
 */
float qadr_get_qa_score(GstBuffer* buf) {
  float score = 0.0f;
#ifdef HAS_DEEPSTREAM
  NvDsBatchMeta* b_meta = nullptr;
  NvDsMetaList* l_frame = nullptr;
  NvDsMetaList* l_obj = nullptr;
  NvDsFrameMeta* f_meta = nullptr;
  NvDsObjectMeta* o_meta = nullptr;

  // get batch level metadata
  b_meta = gst_buffer_get_nvds_batch_meta(buf);
  if (!b_meta) {
    GST_ERROR("No NvDsBatchMeta on GstBuffer!");
    return 0.0f;
  }

  // iterate through the list of frame meta
  for (l_frame = b_meta->frame_meta_list; l_frame != nullptr;
       l_frame = l_frame->next) {
    f_meta = static_cast<NvDsFrameMeta*>(l_frame->data);
    g_assert(f_meta != nullptr);
    // then through the object meta
    for (l_obj = f_meta->obj_meta_list; l_obj != nullptr; l_obj = l_obj->next) {
      o_meta = static_cast<NvDsObjectMeta*>(l_obj->data);
      g_assert(o_meta != nullptr);
      // skip if the component id is not ours
      if (o_meta->unique_component_id != 171) {
        continue;
      }
      // This should be the score. Otherwise we'll have to parse the tensor
      // manually.
      return o_meta->confidence;
    }
  }
#else
  (void)buf;
#endif
  return score;
}

/**
 * @brief
 *
 */
bool qadr_has_disease(GstBuffer* buf) {
  bool disease = false;
#ifdef HAS_DEEPSTREAM
  NvDsBatchMeta* b_meta = nullptr;
  NvDsMetaList* l_frame = nullptr;
  NvDsMetaList* l_obj = nullptr;
  NvDsFrameMeta* f_meta = nullptr;
  NvDsObjectMeta* o_meta = nullptr;

  // get batch level metadata
  b_meta = gst_buffer_get_nvds_batch_meta(buf);
  if (!b_meta) {
    GST_ERROR("No NvDsBatchMeta on GstBuffer!");
    return 0.0f;
  }

  // iterate through the list of frame meta
  for (l_frame = b_meta->frame_meta_list; l_frame != nullptr;
       l_frame = l_frame->next) {
    f_meta = static_cast<NvDsFrameMeta*>(l_frame->data);
    g_assert(f_meta != nullptr);
    // then through the object meta
    for (l_obj = f_meta->obj_meta_list; l_obj != nullptr; l_obj = l_obj->next) {
      o_meta = static_cast<NvDsObjectMeta*>(l_obj->data);
      g_assert(o_meta != nullptr);
      // skip if the component id is not ours
      if (o_meta->unique_component_id != 418) {
        continue;
      }
      // Have to check the model to see if this is the score we're looking for
      return o_meta->confidence > 0.0f;
    }
  }
#else
  (void)buf;
#endif
  return disease;
}