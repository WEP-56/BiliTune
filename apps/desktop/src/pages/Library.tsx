import { useState } from 'react';
import { usePlayerStore, usePlaylistStore, useUserStore } from '@bilitune/store';
import type { MusicPlaylist, MusicTrack } from '@bilitune/shared';
import { formatDuration, formatCount } from '@bilitune/shared';

export default function Library() {
  const { playlists, loadPlaylists, isLoading } = usePlaylistStore();
  const [selectedPlaylist, setSelectedPlaylist] = useState<MusicPlaylist | null>(null);
  const [tab, setTab] = useState<'playlists' | 'history' | 'following'>('playlists');
  const userInfo = useUserStore((s) => s.userInfo);
  const play = usePlayerStore((s) => s.play);
  const setQueue = usePlayerStore((s) => s.setQueue);

  const handlePlayPlaylist = (playlist: MusicPlaylist) => {
    if (playlist.tracks.length > 0) {
      setQueue(playlist.tracks, 0);
      play(playlist.tracks[0]);
    }
  };

  const tabs = [
    { key: 'playlists' as const, label: '收藏歌单' },
    { key: 'history' as const, label: '播放历史' },
    { key: 'following' as const, label: '关注的UP主' },
  ];

  return (
    <div className="px-10 py-8 h-full overflow-y-auto">
      {/* Stats */}
      <div className="grid grid-cols-3 gap-5 mb-10">
        <div className="bg-[#16161A] rounded-xl p-6 border-l-4 border-[#00AEEC]">
          <div className="text-[32px] font-extrabold text-white mb-1">{playlists.length}</div>
          <div className="text-[13px] text-[#9E9EAF]">收藏歌单</div>
        </div>
        <div className="bg-[#16161A] rounded-xl p-6 border-l-4 border-[#1D9E75]">
          <div className="text-[32px] font-extrabold text-white mb-1">
            {playlists.reduce((sum, p) => sum + p.trackCount, 0)}
          </div>
          <div className="text-[13px] text-[#9E9EAF]">总曲目数</div>
        </div>
        <div className="bg-[#16161A] rounded-xl p-6 border-l-4 border-[#FB7299]">
          <div className="text-[32px] font-extrabold text-white mb-1">12</div>
          <div className="text-[13px] text-[#9E9EAF]">订阅UP主</div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-3 mb-6 border-b border-[#202026] pb-3">
        {tabs.map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`px-4 py-2 rounded-[20px] text-sm font-semibold transition-colors ${
              tab === t.key
                ? 'text-white bg-[#23232A]'
                : 'text-[#9E9EAF] hover:text-white hover:bg-[#23232A]'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Playlists Grid */}
      {tab === 'playlists' && (
        <div className="grid grid-cols-4 gap-5">
          {playlists.map((playlist) => (
            <div
              key={playlist.id}
              onClick={() => handlePlayPlaylist(playlist)}
              className="bg-[#16161A] rounded-xl p-4 border border-transparent hover:bg-[#23232A] hover:-translate-y-1 hover:border-white/[0.05] transition-all duration-300 cursor-pointer group"
            >
              <div className="aspect-square rounded-lg overflow-hidden mb-3.5 bg-gradient-to-br from-[#23232A] to-[#16161A]">
                {playlist.cover ? (
                  <img src={playlist.cover} alt="" className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-3xl opacity-40">
                    {playlist.isFavFolder ? '📂' : '🎵'}
                  </div>
                )}
                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                  <div className="w-12 h-12 rounded-full bg-[#FB7299] flex items-center justify-center">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="white" stroke="none">
                      <polygon points="5 3 19 12 5 21 5 3" />
                    </svg>
                  </div>
                </div>
              </div>
              <h3 className="text-sm font-semibold text-white line-clamp-2 mb-2">{playlist.title}</h3>
              <p className="text-xs text-[#9E9EAF]">
                {playlist.trackCount}首歌曲
                {playlist.description && ` · ${playlist.description}`}
              </p>
            </div>
          ))}

          {playlists.length === 0 && (
            <div className="col-span-4 text-center py-20">
              <p className="text-[#9E9EAF] text-lg mb-2">还没有收藏歌单</p>
              <p className="text-[#9E9EAF] text-sm">
                {userInfo ? '去发现页找到喜欢的歌曲，添加到收藏夹' : '登录后即可同步你的B站收藏夹'}
              </p>
            </div>
          )}
        </div>
      )}

      {tab === 'history' && (
        <div className="text-center py-20">
          <p className="text-[#9E9EAF] text-lg">播放历史</p>
          <p className="text-[#9E9EAF] text-sm mt-2">登录后同步播放记录</p>
        </div>
      )}

      {tab === 'following' && (
        <div className="text-center py-20">
          <p className="text-[#9E9EAF] text-lg">关注的UP主</p>
          <p className="text-[#9E9EAF] text-sm mt-2">登录后查看你关注的UP主最新投稿</p>
        </div>
      )}
    </div>
  );
}
