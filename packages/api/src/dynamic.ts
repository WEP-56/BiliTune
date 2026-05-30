// ============================================================
// BiliTune API - Dynamic Feed Module
// ============================================================

import { apiRequest } from './client';
import { API } from '@bilitune/shared';

// ---- Get dynamic feed ----

export interface DynamicFeedItem {
  id: string;
  type: 'video' | 'audio' | 'text' | 'forward';
  author: {
    mid: number;
    name: string;
    face: string;
  };
  timestamp: number;
  text?: string;
  video?: {
    bvid: string;
    title: string;
    cover: string;
    duration: number;
    playCount: number;
  };
  // Forwarded content
  origin?: DynamicFeedItem;
}

export async function getDynamicFeed(
  page: number = 1
): Promise<{ items: DynamicFeedItem[]; hasMore: boolean }> {
  const resp = await apiRequest<{
    items?: any[];
    has_more?: boolean;
    offset?: string;
  }>(API.DYNAMIC_FEED, {
    params: {
      type: 'all',
      timezone_offset: '-480',
      features: 'itemOpusStyle',
    },
  });

  const items = (resp.data?.items || []).map(mapDynamicItem);

  return {
    items,
    hasMore: resp.data?.has_more || false,
  };
}

function mapDynamicItem(raw: any): DynamicFeedItem {
  const modules = raw.modules || {};
  const authorInfo = modules.module_author || {};
  const dynamicInfo = modules.module_dynamic || {};
  const desc = dynamicInfo.desc?.text || '';

  const item: DynamicFeedItem = {
    id: raw.id_str || String(raw.id),
    type: mapDynamicType(raw.type),
    author: {
      mid: authorInfo.mid || 0,
      name: authorInfo.name || '',
      face: authorInfo.face || '',
    },
    timestamp: authorInfo.pub_ts || 0,
    text: desc,
  };

  // Video content
  const archive = dynamicInfo.major?.archive;
  if (archive) {
    item.video = {
      bvid: archive.bvid || '',
      title: archive.title || '',
      cover: archive.cover || '',
      duration: archive.duration || 0,
      playCount: archive.stat?.play || 0,
    };
  }

  return item;
}

function mapDynamicType(type: string): DynamicFeedItem['type'] {
  switch (type) {
    case 'DYNAMIC_TYPE_AV':
      return 'video';
    case 'DYNAMIC_TYPE_AUDIO':
      return 'audio';
    case 'DYNAMIC_TYPE_FORWARD':
      return 'forward';
    default:
      return 'text';
  }
}
