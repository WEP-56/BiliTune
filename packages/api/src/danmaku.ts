// ============================================================
// BiliTune API - Danmaku Module
// ============================================================

import type { DanmakuItem } from '@bilitune/shared';
import { API } from '@bilitune/shared';

// ---- Get danmaku for a video segment ----

export async function getDanmaku(
  cid: number,
  segmentIndex: number = 1
): Promise<DanmakuItem[]> {
  try {
    const resp = await fetch(
      `https://api.bilibili.com/x/v1/dm/list.so?oid=${cid}&segment_index=${segmentIndex}`,
      {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          Referer: 'https://www.bilibili.com/',
        },
      }
    );

    const xmlText = await resp.text();
    return parseDanmakuXml(xmlText);
  } catch (e) {
    console.warn('[BiliTune API] Failed to get danmaku:', e);
    return [];
  }
}

// ---- Parse danmaku XML ----

function parseDanmakuXml(xml: string): DanmakuItem[] {
  const danmakuList: DanmakuItem[] = [];
  const regex = /<d p="([^"]*)"[^>]*>(.*?)<\/d>/g;

  let match: RegExpExecArray | null;
  while ((match = regex.exec(xml)) !== null) {
    const attrs = match[1].split(',');
    if (attrs.length >= 5) {
      danmakuList.push({
        time: parseFloat(attrs[0]) || 0,
        type: mapDanmakuType(parseInt(attrs[1])),
        fontSize: parseInt(attrs[2]) || 25,
        color: decimalToHex(parseInt(attrs[3]) || 16777215),
        sendTime: parseInt(attrs[4]) || 0,
        text: match[2],
      });
    }
  }

  return danmakuList;
}

function mapDanmakuType(type: number): DanmakuItem['type'] {
  switch (type) {
    case 4:
      return 'bottom';
    case 5:
      return 'top';
    default:
      return 'scroll';
  }
}

function decimalToHex(dec: number): string {
  return '#' + dec.toString(16).padStart(6, '0');
}

// ---- Get danmaku segment info ----

export async function getDanmakuSegInfo(
  bvid: string,
  cid: number
): Promise<{ totalSegments: number }> {
  try {
    const resp = await fetch(
      `https://api.bilibili.com/x/player/v2?bvid=${bvid}&cid=${cid}`,
      {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          Referer: 'https://www.bilibili.com/',
        },
      }
    );
    const json = await resp.json();
    return {
      totalSegments: json.data?.subtitle?.danmaku_segments || 1,
    };
  } catch {
    return { totalSegments: 1 };
  }
}
