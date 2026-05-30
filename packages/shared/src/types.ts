// ============================================================
// BiliTune Core Types
// ============================================================

// ---- Video / Audio ----

export interface BiliVideoInfo {
  aid: number;
  bvid: string;
  cid: number;
  title: string;
  desc: string;
  duration: number; // seconds
  cover: string;
  owner: BiliUserBrief;
  stat: {
    view: number;
    danmaku: number;
    like: number;
    coin: number;
    favorite: number;
    share: number;
    reply: number;
  };
  pubdate: number; // unix timestamp
  pages: BiliPage[];
  ctime: number;
}

export interface BiliPage {
  cid: number;
  page: number;
  part: string;
  duration: number;
  dimension: { width: number; height: number; rotate: number };
}

export interface BiliAudioInfo {
  id: number;
  base_url: string;
  backup_url: string[];
  bandwidth: number;
  mime_type: string;
  codecs: string;
  segment_base: { initialization: string; index_range: string };
  size: number;
}

export interface BiliAudioQuality {
  id: number; // 30280=320k, 30232=128k, 30216=64k
  desc: string;
}

// ---- Music Track (our unified model) ----

export interface MusicTrack {
  id: string; // "bvid_cid" or "aid_cid"
  bvid: string;
  aid: number;
  cid: number;
  title: string;
  artist: string; // UP主名称
  artistId: number;
  cover: string;
  duration: number;
  audioUrl?: string;
  quality: AudioQuality;
  playCount: number;
  danmakuCount: number;
  tags: string[];
}

export type AudioQuality = 'lossless' | '320k' | '128k' | '64k';

export const AUDIO_QUALITY_LABEL: Record<AudioQuality, string> = {
  lossless: 'Hi-Res 无损',
  '320k': '320K 高品',
  '128k': '128K 标准',
  '64k': '64K 流畅',
};

// ---- User ----

export interface BiliUserBrief {
  mid: number;
  name: string;
  face: string;
}

export interface BiliUserInfo extends BiliUserBrief {
  sex: string;
  sign: string;
  level: number;
  birthday: string;
  official: { role: number; title: string; desc: string };
  vip: { type: number; status: number; label: { text: string } };
  follower: number;
  following: number;
}

export interface LoginCredential {
  sessdata: string;
  bili_jct: string;
  dedeuserid: string;
  buvid3: string;
  buvid4: string;
}

// ---- Playlist ----

export interface MusicPlaylist {
  id: string;
  title: string;
  cover: string;
  description: string;
  trackCount: number;
  playCount: number;
  owner: BiliUserBrief;
  tracks: MusicTrack[];
  isFavFolder: boolean; // is it a Bilibili favorite folder?
}

// ---- Search ----

export interface SearchResult {
  tracks: MusicTrack[];
  playlists: MusicPlaylist[];
  users: BiliUserBrief[];
  totalPages: number;
  currentPage: number;
}

// ---- Player ----

export type PlayMode = 'sequence' | 'shuffle' | 'repeat-one' | 'repeat-all';

export interface PlayerState {
  currentTrack: MusicTrack | null;
  queue: MusicTrack[];
  queueIndex: number;
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  volume: number;
  isMuted: boolean;
  playMode: PlayMode;
  playbackRate: number;
}

// ---- Lyrics ----

export interface LyricLine {
  time: number; // seconds
  text: string;
}

export interface LyricsData {
  lines: LyricLine[];
  source?: string; // where the lyrics came from
}

// ---- Danmaku ----

export interface DanmakuItem {
  time: number; // seconds in video
  text: string;
  color: string;
  type: 'scroll' | 'top' | 'bottom';
  fontSize: number;
  sendTime: number;
}

// ---- App Settings ----

export interface AppSettings {
  audioQuality: AudioQuality;
  theme: 'auto' | 'light' | 'dark';
  autoPlay: boolean;
  danmakuEnabled: boolean;
  danmakuOpacity: number; // 0-1
  danmakuFontSize: number;
  cacheSizeLimit: number; // MB
  downloadPath: string;
  downloadQuality: AudioQuality;
  language: 'zh-CN' | 'en';
}

export const DEFAULT_SETTINGS: AppSettings = {
  audioQuality: '320k',
  theme: 'dark',
  autoPlay: true,
  danmakuEnabled: true,
  danmakuOpacity: 0.8,
  danmakuFontSize: 16,
  cacheSizeLimit: 2048,
  downloadPath: '',
  downloadQuality: '320k',
  language: 'zh-CN',
};

// ---- Download ----

export type DownloadStatus = 'pending' | 'downloading' | 'completed' | 'failed' | 'paused';

export interface DownloadTask {
  id: string;
  track: MusicTrack;
  status: DownloadStatus;
  progress: number; // 0-100
  speed: string;
  filePath?: string;
  fileSize?: number;
  error?: string;
  createdAt: number;
}

// ---- History ----

export interface PlayHistoryItem {
  track: MusicTrack;
  playedAt: number; // unix timestamp
  playCount: number;
}

// ---- Navigation ----

export type NavPage =
  | 'discover'
  | 'search'
  | 'now-playing'
  | 'library'
  | 'downloads'
  | 'settings';

// ---- Theme ----

export interface ThemeColors {
  primary: string; // bili pink #FB7299
  primaryLight: string;
  accent: string; // bili blue #00AEEC
  accentLight: string;
  bgPrimary: string;
  bgSecondary: string;
  bgSurface: string;
  bgHover: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  border: string;
  danger: string;
  success: string;
  warning: string;
}

export const DARK_THEME: ThemeColors = {
  primary: '#FB7299',
  primaryLight: '#FF94B4',
  accent: '#00AEEC',
  accentLight: '#4DD4FF',
  bgPrimary: '#0A0A0C',
  bgSecondary: '#010103',
  bgSurface: '#16161A',
  bgHover: '#23232A',
  textPrimary: '#FFFFFF',
  textSecondary: '#D0D0D8',
  textMuted: '#9E9EAF',
  border: '#202026',
  danger: '#E24B4A',
  success: '#1D9E75',
  warning: '#EF9F27',
};

export const LIGHT_THEME: ThemeColors = {
  primary: '#FB7299',
  primaryLight: '#FF94B4',
  accent: '#00AEEC',
  accentLight: '#4DD4FF',
  bgPrimary: '#FFFFFF',
  bgSecondary: '#F5F5F7',
  bgSurface: '#F0F0F2',
  bgHover: '#E8E8EB',
  textPrimary: '#1D1D1F',
  textSecondary: '#515154',
  textMuted: '#86868B',
  border: '#D2D2D7',
  danger: '#E24B4A',
  success: '#1D9E75',
  warning: '#EF9F27',
};
