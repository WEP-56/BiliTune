import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { usePlayerStore, useUserStore } from '@bilitune/store';
import * as recommendApi from '@bilitune/api/recommend';
import type { MusicTrack } from '@bilitune/shared';
import { formatCount, formatDuration } from '@bilitune/shared';

export default function Discover() {
  const navigate = useNavigate();
  const play = usePlayerStore((s) => s.play);
  const setQueue = usePlayerStore((s) => s.setQueue);
  const [tracks, setTracks] = useState<MusicTrack[]>([]);
  const [loading, setLoading] = useState(true);
  const isLoggedIn = useUserStore((s) => s.isLoggedIn);

  useEffect(() => {
    loadRecommendations();
  }, []);

  const loadRecommendations = async () => {
    setLoading(true);
    try {
      // Try recommendations (requires login) or fallback to popular
      if (isLoggedIn) {
        try {
          const result = await recommendApi.getRecommendations();
          if (result.tracks.length > 0) {
            setTracks(result.tracks);
            return;
          }
        } catch {}
      }
      const result = await recommendApi.getPopularVideos(1, 20);
      setTracks(result.tracks);
    } catch (e) {
      console.warn('[BiliTune] Failed to load recommendations:', e);
      setTracks(getMockTracks());
    } finally {
      setLoading(false);
    }
  };

  const handlePlayTrack = (track: MusicTrack, index: number) => {
    setQueue(tracks, index);
    play(track);
  };

  // Quick categories
  const categories = [
    { label: '排行榜', icon: '🏆', color: '#FF512F' },
    { label: 'VOCALOID', icon: '🎤', color: '#00C6FF' },
    { label: 'ACG神曲', icon: '🎮', color: '#7F00FF' },
    { label: '国风古风', icon: '🏮', color: '#16a085' },
    { label: '翻唱精选', icon: '🎵', color: '#e65c00' },
    { label: '白噪音', icon: '💤', color: '#34495e' },
  ];

  return (
    <div className="px-10 py-8 h-full overflow-y-auto">
      {/* Hero Banner */}
      <div className="relative h-[240px] rounded-2xl mb-9 p-10 flex flex-col justify-center overflow-hidden border border-[#FB7299]/15"
        style={{ background: 'linear-gradient(135deg, #1e0f14 0%, #3a1522 50%, #12090d 100%)' }}>
        <span className="text-xs font-bold text-[#FB7299] uppercase tracking-[2px] mb-2.5">独家特辑</span>
        <h1 className="text-[32px] font-extrabold mb-3 max-w-[600px] leading-tight">
          VOCALOID 经典重燃计划
        </h1>
        <p className="text-sm text-[#9E9EAF] max-w-[500px]">
          聚合站内顶尖P主高质量重编曲版本，高码率无损音质首发体验。虚拟歌姬的下一个十年，从这里开始。
        </p>
        {/* Background text */}
        <span className="absolute right-[-20px] bottom-[-30px] text-[110px] font-black text-[#FB7299]/[0.03] tracking-[-2px] select-none">
          BILITUNE
        </span>
      </div>

      {/* Quick Categories */}
      <div className="flex gap-4 mb-9 overflow-x-auto pb-2">
        {categories.map((cat) => (
          <button
            key={cat.label}
            onClick={() => navigate(`/search?q=${encodeURIComponent(cat.label)}`)}
            className="flex flex-col items-center gap-2 flex-shrink-0 px-4 py-3 rounded-xl bg-[#16161A] border border-[#202026] hover:border-[#FB7299]/30 hover:bg-[#23232A] transition-all cursor-pointer group"
          >
            <div
              className="w-10 h-10 rounded-full flex items-center justify-center text-lg"
              style={{ backgroundColor: cat.color + '20', border: `2px solid ${cat.color}30` }}
            >
              {cat.icon}
            </div>
            <span className="text-xs font-semibold text-[#9E9EAF] group-hover:text-white transition-colors">
              {cat.label}
            </span>
          </button>
        ))}
      </div>

      {/* Recommended Tracks */}
      <div className="mb-9">
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-[22px] font-bold text-white">
            {isLoggedIn ? '推荐综合投递（基于你的常看UP主）' : '热门推荐'}
          </h2>
          <button
            onClick={loadRecommendations}
            className="text-[13px] text-[#9E9EAF] hover:text-[#FB7299] transition-colors font-medium"
          >
            刷新推荐
          </button>
        </div>

        {loading ? (
          <div className="grid grid-cols-5 gap-5">
            {Array.from({ length: 10 }).map((_, i) => (
              <div key={i} className="bg-[#16161A] rounded-xl p-4 animate-pulse">
                <div className="aspect-square rounded-lg bg-[#23232A] mb-3.5" />
                <div className="h-4 bg-[#23232A] rounded w-3/4 mb-2" />
                <div className="h-3 bg-[#23232A] rounded w-1/2" />
              </div>
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-5 gap-5">
            {tracks.map((track, index) => (
              <div
                key={track.id}
                onClick={() => handlePlayTrack(track, index)}
                className="bg-[#16161A] rounded-xl p-4 border border-transparent hover:bg-[#23232A] hover:-translate-y-1 hover:border-white/[0.05] transition-all duration-300 cursor-pointer group"
              >
                {/* Cover */}
                <div className="relative aspect-square rounded-lg overflow-hidden mb-3.5 bg-gradient-to-br from-[#23232A] to-[#16161A]">
                  {track.cover ? (
                    <img src={track.cover} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-3xl opacity-40">♪</div>
                  )}
                  {/* Play count */}
                  <span className="absolute bottom-2 left-2 bg-black/65 backdrop-blur px-2 py-0.5 rounded-md text-[11px] text-[#00AEEC] font-semibold">
                    {formatCount(track.playCount)}播放
                  </span>
                  {/* Play button (hover) */}
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <div className="w-12 h-12 rounded-full bg-[#FB7299] flex items-center justify-center shadow-lg">
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="white" stroke="none">
                        <polygon points="5 3 19 12 5 21 5 3" />
                      </svg>
                    </div>
                  </div>
                </div>

                {/* Title */}
                <h3 className="text-sm font-semibold text-white leading-snug line-clamp-2 h-10 mb-1.5">
                  {track.title}
                </h3>

                {/* Artist */}
                <p className="text-xs text-[#9E9EAF] flex items-center gap-1.5">
                  <span className="bg-[#FB7299] text-white text-[9px] font-extrabold px-1 py-0.5 rounded">UP</span>
                  {track.artist}
                </p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Recently Played (placeholder) */}
      <div className="mb-9">
        <h2 className="text-[22px] font-bold text-white mb-5">最近播放</h2>
        <div className="grid grid-cols-5 gap-5">
          {tracks.slice(0, 5).map((track, index) => (
            <div
              key={track.id}
              onClick={() => handlePlayTrack(track, index)}
              className="flex items-center gap-3 bg-[#16161A] rounded-xl p-3 border border-transparent hover:bg-[#23232A] transition-all cursor-pointer"
            >
              <div className="w-12 h-12 rounded-md bg-gradient-to-br from-[#23232A] to-[#16161A] flex-shrink-0 overflow-hidden">
                {track.cover ? (
                  <img src={track.cover} alt="" className="w-full h-full object-cover" />
                ) : null}
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-white truncate">{track.title}</p>
                <p className="text-xs text-[#9E9EAF] truncate">{track.artist}</p>
              </div>
              <span className="text-[11px] text-[#9E9EAF]">{formatDuration(track.duration)}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// Mock data for development / offline
function getMockTracks(): MusicTrack[] {
  const data = [
    { title: '【秒杀原唱】全网最震撼的国风摇滚戏腔组曲', artist: '国风乐天派', plays: 1452000, dur: 245 },
    { title: '赛博朋克自习室：深度专注低音白噪音', artist: '脑波极客', plays: 328000, dur: 3600 },
    { title: '【周刊VOCALOID】本周最火爆V家新曲极速充电', artist: '洛天依应援组', plays: 894000, dur: 580 },
    { title: '【经典神曲】那些年带你入二次元坑的ACG神级交响乐', artist: '哔哩大交响', plays: 2330000, dur: 1200 },
    { title: '【VUP纯享】虚拟主播心动情歌午夜温柔翻唱', artist: '单推小字幕', plays: 125000, dur: 192 },
    { title: '【电音原创】Neon Genesis Horizon (Original Mix)', artist: '音乐制作人米其林', plays: 56000, dur: 265 },
    { title: '古风燃向：陪你踏碎凌霄的国漫热血配乐', artist: '国风乐坊', plays: 780000, dur: 890 },
    { title: '东方Project经典同人交响幻想乡合集', artist: '东方同人社', plays: 1_200_000, dur: 3600 },
    { title: 'Cytus/Arcaea 高难度魔王曲绝对音感蹦迪', artist: '音游狂魔', plays: 445000, dur: 175 },
    { title: '【钢琴独奏】千本桜 - 极致触键版', artist: '黑白键行者', plays: 567000, dur: 232 },
  ];

  return data.map((d, i) => ({
    id: `mock_${i}`,
    bvid: '',
    aid: i,
    cid: i,
    title: d.title,
    artist: d.artist,
    artistId: i,
    cover: '',
    duration: d.dur,
    quality: '320k' as const,
    playCount: d.plays,
    danmakuCount: Math.floor(d.plays * 0.1),
    tags: [],
  }));
}
