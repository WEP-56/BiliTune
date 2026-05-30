import { useState, useEffect } from 'react';
import { View, Text, ScrollView, TouchableOpacity, StyleSheet, Image } from 'react-native';
import { useRouter } from 'expo-router';
import { usePlayerStore } from '@bilitune/store';
import * as recommendApi from '@bilitune/api/recommend';
import type { MusicTrack } from '@bilitune/shared';
import { formatCount, formatDuration } from '@bilitune/shared';

export default function DiscoverScreen() {
  const router = useRouter();
  const [tracks, setTracks] = useState<MusicTrack[]>([]);
  const [loading, setLoading] = useState(true);
  const play = usePlayerStore((s) => s.play);
  const setQueue = usePlayerStore((s) => s.setQueue);

  useEffect(() => {
    loadTracks();
  }, []);

  const loadTracks = async () => {
    setLoading(true);
    try {
      try {
        const result = await recommendApi.getRecommendations();
        if (result.tracks.length > 0) {
          setTracks(result.tracks);
          return;
        }
      } catch {}
      const result = await recommendApi.getPopularVideos(1, 15);
      setTracks(result.tracks);
    } catch {
      setTracks(getMockTracks());
    } finally {
      setLoading(false);
    }
  };

  const handlePlayTrack = (track: MusicTrack, index: number) => {
    setQueue(tracks, index);
    play(track);
    router.push('/player');
  };

  const shortcuts = [
    { label: '排行榜', icon: '🏆', color: '#FF512F' },
    { label: '电台', icon: '📻', color: '#00C6FF' },
    { label: 'VUP', icon: '✨', color: '#7F00FF' },
    { label: '白噪音', icon: '💤', color: '#34495e' },
  ];

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scroll} showsVerticalScrollIndicator={false}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.headerTitle}>发现音乐</Text>
          <View style={styles.avatarBtn}>
            <View style={styles.avatarInner} />
          </View>
        </View>

        {/* Hero Card */}
        <View style={styles.heroCard}>
          <Text style={styles.heroBadge}>官方推荐周刊</Text>
          <Text style={styles.heroTitle}>
            【VOCALOID】{'\n'}经典新声重燃特辑
          </Text>
        </View>

        {/* Shortcuts */}
        <View style={styles.shortcuts}>
          {shortcuts.map((s) => (
            <TouchableOpacity key={s.label} style={styles.shortcutItem}>
              <View style={[styles.shortcutCircle, { borderColor: s.color + '40' }]}>
                <Text style={styles.shortcutIcon}>{s.icon}</Text>
              </View>
              <Text style={styles.shortcutLabel}>{s.label}</Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* Section */}
        <Text style={styles.sectionTitle}>推荐投递</Text>

        {/* Track list */}
        <View style={styles.trackList}>
          {loading
            ? Array.from({ length: 5 }).map((_, i) => (
                <View key={i} style={styles.trackSkeleton}>
                  <View style={[styles.trackCover, { backgroundColor: '#23232A' }]} />
                  <View style={{ flex: 1 }}>
                    <View style={{ height: 14, backgroundColor: '#23232A', borderRadius: 4, width: '80%', marginBottom: 6 }} />
                    <View style={{ height: 12, backgroundColor: '#23232A', borderRadius: 4, width: '50%' }} />
                  </View>
                </View>
              ))
            : tracks.map((track, index) => (
                <TouchableOpacity
                  key={track.id}
                  style={styles.trackItem}
                  onPress={() => handlePlayTrack(track, index)}
                  activeOpacity={0.7}
                >
                  <View style={styles.trackCover}>
                    {track.cover ? (
                      <Image source={{ uri: track.cover }} style={styles.coverImage} />
                    ) : (
                      <Text style={styles.coverPlaceholder}>♪</Text>
                    )}
                  </View>
                  <View style={styles.trackMeta}>
                    <Text style={styles.trackTitle} numberOfLines={1}>
                      {track.title}
                    </Text>
                    <View style={styles.trackInfo}>
                      <Text style={styles.upTag}>UP</Text>
                      <Text style={styles.trackArtist} numberOfLines={1}>
                        {track.artist} · {formatCount(track.playCount)}看
                      </Text>
                    </View>
                  </View>
                  <Text style={styles.trackMore}>⋮</Text>
                </TouchableOpacity>
              ))}
        </View>

        <View style={{ height: 160 }} />
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0D0D11',
  },
  scroll: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 16,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: '800',
    color: '#FFFFFF',
    letterSpacing: -0.5,
  },
  avatarBtn: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: '#FB7299',
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarInner: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#00AEEC',
    borderWidth: 2,
    borderColor: '#FFFFFF',
  },
  heroCard: {
    height: 220,
    borderRadius: 16,
    padding: 24,
    justifyContent: 'flex-end',
    marginBottom: 25,
    borderWidth: 1,
    borderColor: 'rgba(251, 114, 153, 0.2)',
    backgroundColor: '#2b1018',
  },
  heroBadge: {
    fontSize: 11,
    fontWeight: '700',
    color: '#FB7299',
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: 6,
  },
  heroTitle: {
    fontSize: 22,
    fontWeight: '800',
    color: '#FFFFFF',
    lineHeight: 30,
  },
  shortcuts: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 25,
  },
  shortcutItem: {
    alignItems: 'center',
    gap: 6,
  },
  shortcutCircle: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#181822',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
  },
  shortcutIcon: {
    fontSize: 20,
  },
  shortcutLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: '#9E9EAF',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#FFFFFF',
    marginBottom: 14,
  },
  trackList: {
    gap: 16,
  },
  trackSkeleton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  trackItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  trackCover: {
    width: 54,
    height: 54,
    borderRadius: 8,
    backgroundColor: '#23232A',
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
  },
  coverImage: {
    width: '100%',
    height: '100%',
  },
  coverPlaceholder: {
    fontSize: 24,
    color: '#9E9EAF',
  },
  trackMeta: {
    flex: 1,
  },
  trackTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#FFFFFF',
    marginBottom: 4,
  },
  trackInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  upTag: {
    fontSize: 8,
    fontWeight: '800',
    color: '#FFFFFF',
    backgroundColor: '#FB7299',
    paddingHorizontal: 3,
    paddingVertical: 0,
    borderRadius: 3,
    overflow: 'hidden',
  },
  trackArtist: {
    fontSize: 12,
    color: '#9E9EAF',
  },
  trackMore: {
    color: '#9E9EAF',
    fontSize: 18,
  },
});

function getMockTracks(): MusicTrack[] {
  const data = [
    { title: '【秒杀原唱】全网最震撼的国风摇滚戏腔组曲', artist: '国风乐天派', plays: 1452000, dur: 245 },
    { title: '赛博朋克自习室：深度专注低音白噪音', artist: '脑波极客', plays: 328000, dur: 3600 },
    { title: '【周刊VOCALOID】本周最火爆V家新曲', artist: '洛天依应援组', plays: 894000, dur: 580 },
    { title: '【经典神曲】那些年带你入二次元坑的ACG', artist: '哔哩大交响', plays: 2330000, dur: 1200 },
    { title: '【VUP纯享】虚拟主播心动情歌午夜翻唱', artist: '单推小字幕', plays: 125000, dur: 192 },
  ];
  return data.map((d, i) => ({
    id: `mock_${i}`, bvid: '', aid: i, cid: i,
    title: d.title, artist: d.artist, artistId: i, cover: '',
    duration: d.dur, quality: '320k' as const,
    playCount: d.plays, danmakuCount: Math.floor(d.plays * 0.1), tags: [],
  }));
}
