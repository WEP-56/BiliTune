// ============================================================
// BiliTune Constants
// ============================================================

// Bilibili API endpoints
export const BILIBILI_API_BASE = 'https://api.bilibili.com';

export const API = {
  // Info
  VIDEO_INFO: '/x/web-interface/view',
  VIDEO_PAGE_LIST: '/x/player/pagelist',
  PLAYER_URL: '/x/player/playurl',
  PLAYER_AUDIO: '/x/player/wbi/playurl',

  // Search
  SEARCH: '/x/web-interface/wbi/search/all/v2',
  SEARCH_SUGGEST: '/x/web-interface/search/default',

  // User
  USER_INFO: '/x/space/wbi/acc/info',
  USER_VIDEOS: '/x/space/wbi/arc/search',
  USER_UP_STAT: '/x/space/upstat',

  // Favorite
  FAV_FOLDER_LIST: '/x/v3/fav/folder/created/list-all',
  FAV_FOLDER_INFO: '/x/v3/fav/folder/info',
  FAV_FOLDER_CONTENT: '/x/v3/fav/resource/list',
  FAV_VIDEO: '/x/v3/fav/resource/deal',

  // Login
  QRCODE_URL: '/x/web-interface/nav',
  LOGIN_URL: 'https://passport.bilibili.com/x/passport-login/web/qrcode/generate',
  LOGIN_POLL: 'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',

  // History
  HISTORY_LIST: '/x/web-interface/history/cursor',
  HISTORY_REPORT: '/x/v2/history/report',

  // Recommend
  RECOMMEND: '/x/web-interface/wbi/index/top/feed/rcmd',

  // Popular / Charts
  POPULAR: '/x/web-interface/popular',
  RANKING: '/x/web-interface/ranking/v2',

  // Dynamic feed
  DYNAMIC_FEED: '/x/polymer/web-dynamic/v1/feed/all',

  // Audio related
  AUDIO_INFO: '/x/player/v2',
  AUDIO_STREAM: '/api/audio/music/url',

  // Danmaku
  DANMAKU: '/x/v1/dm/list.so',
  DANMAKU_SEG: '/x/player/v2',

  // Lyrics
  LYRICS: '/x/player/wbi/v2',
  AI_LYRICS: '/x/ai/lyrics',

  // Relations
  RELATION: '/x/relation/modify',
  FOLLOWINGS: '/x/relation/followings',
  FOLLOWERS: '/x/relation/followers',

  // Watched later
  TO_VIEW: '/x/v2/history/toview',
  TO_VIEW_ADD: '/x/v2/history/toview/add',

  // Download related
  DOWNLOAD: '/x/player/playurl',
} as const;

// Audio quality ID mapping
export const AUDIO_QUALITY_IDS = {
  lossless: 30280, // Hi-Res / Flac
  high: 30232,     // 320k
  medium: 30216,   // 128k
  low: 30280,      // 64k (fallback to available)
} as const;

export const QUALITY_ID_TO_LABEL: Record<number, string> = {
  30280: 'Hi-Res',
  30232: '320K',
  30216: '128K',
};

// App metadata
export const APP_NAME = 'BiliTune';
export const APP_VERSION = '1.0.0';
export const APP_DESCRIPTION = 'Bilibili Music Client';

// Storage keys
export const STORAGE_KEYS = {
  SETTINGS: 'bilitune_settings',
  CREDENTIAL: 'bilitune_credential',
  QUEUE: 'bilitune_queue',
  HISTORY: 'bilitune_history',
  FAVORITES: 'bilitune_favorites',
  DOWNLOADS: 'bilitune_downloads',
  PLAY_POSITION: 'bilitune_play_position',
  COOKIES: 'bilitune_cookies',
} as const;

// Bilibili WBI signing
export const WBI_MIXIN_KEY_ENC_TABLE = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
  27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
  37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
  22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
];

export const NAV_URL = 'https://api.bilibili.com/x/web-interface/nav';

// Buvid
export const BUVID3_PREFIX = 'buvid3';
export const BUVID4_PREFIX = 'buvid4';

// Default headers
export const DEFAULT_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  Referer: 'https://www.bilibili.com/',
  Origin: 'https://www.bilibili.com',
};

// Playback rates
export const PLAYBACK_RATES = [0.5, 0.75, 1, 1.25, 1.5, 2];

// App routes
export const ROUTES = {
  DISCOVER: '/',
  SEARCH: '/search',
  NOW_PLAYING: '/now-playing',
  LIBRARY: '/library',
  DOWNLOADS: '/downloads',
  SETTINGS: '/settings',
  PLAYLIST: '/playlist/:id',
  USER: '/user/:uid',
} as const;

// Cover sizes (for thumbnail optimization)
export const COVER_SIZE = {
  SMALL: '@64w_64h',
  MEDIUM: '@160w_160h',
  LARGE: '@320w_320h',
  ORIGINAL: '',
} as const;
