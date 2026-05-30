import { View, Text, TouchableOpacity, StyleSheet, Dimensions } from 'react-native';
import { useRouter } from 'expo-router';
import { usePlayerStore } from '@bilitune/store';
import { formatDuration } from '@bilitune/shared';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

export default function PlayerScreen() {
  const router = useRouter();
  const { currentTrack, isPlaying, currentTime, duration, togglePlay, next, previous } = usePlayerStore();

  if (!currentTrack) {
    return (
      <View style={styles.container}>
        <TouchableOpacity onPress={() => router.back()} style={styles.closeBtn}>
          <Text style={styles.closeText}>✕</Text>
        </TouchableOpacity>
        <View style={styles.emptyState}>
          <Text style={styles.emptyText}>没有正在播放的歌曲</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Close */}
      <TouchableOpacity onPress={() => router.back()} style={styles.closeBtn}>
        <Text style={styles.closeText}>✕</Text>
      </TouchableOpacity>

      {/* Album Art */}
      <View style={styles.artContainer}>
        <View style={styles.disc}>
          <View style={styles.discInner}>
            <View style={styles.discArt} />
          </View>
        </View>
      </View>

      {/* Track Info */}
      <View style={styles.metaContainer}>
        <Text style={styles.trackTitle} numberOfLines={1}>
          {currentTrack.title}
        </Text>
        <Text style={styles.trackArtist}>
          UP主：{currentTrack.artist}
        </Text>
      </View>

      {/* Danmaku */}
      <View style={styles.danmakuBar}>
        <View style={styles.danmakuContent}>
          <Text style={styles.danmakuText}>
            💬 【实时弹幕层】正在高能滚动...
          </Text>
        </View>
      </View>

      {/* Controls */}
      <View style={styles.controlsContainer}>
        {/* Progress */}
        <View style={styles.progressBar}>
          <View style={styles.progressRail}>
            <View
              style={[
                styles.progressFill,
                { width: `${duration > 0 ? (currentTime / duration) * 100 : 0}%` },
              ]}
            />
          </View>
          <View style={styles.progressTime}>
            <Text style={styles.timeText}>{formatDuration(currentTime)}</Text>
            <Text style={styles.timeText}>{formatDuration(duration)}</Text>
          </View>
        </View>

        {/* Buttons */}
        <View style={styles.buttonsRow}>
          <TouchableOpacity onPress={previous} style={styles.controlBtn}>
            <Text style={styles.controlIcon}>⏮</Text>
          </TouchableOpacity>

          <TouchableOpacity onPress={togglePlay} style={styles.playBtn}>
            <Text style={styles.playIcon}>{isPlaying ? '⏸' : '▶'}</Text>
          </TouchableOpacity>

          <TouchableOpacity onPress={next} style={styles.controlBtn}>
            <Text style={styles.controlIcon}>⏭</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0f',
    paddingTop: 44,
    paddingHorizontal: 24,
  },
  closeBtn: {
    marginBottom: 10,
  },
  closeText: {
    fontSize: 24,
    color: '#9E9EAF',
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 16,
    color: '#9E9EAF',
  },
  artContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  disc: {
    width: 240,
    height: 240,
    borderRadius: 120,
    borderWidth: 6,
    borderColor: '#1a1a22',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 15 },
    shadowOpacity: 0.6,
    shadowRadius: 35,
    elevation: 10,
    backgroundColor: '#111',
  },
  discInner: {
    width: 220,
    height: 220,
    borderRadius: 110,
    backgroundColor: '#2c2c35',
    justifyContent: 'center',
    alignItems: 'center',
  },
  discArt: {
    width: 90,
    height: 90,
    borderRadius: 45,
    backgroundColor: '#FB7299',
  },
  metaContainer: {
    alignItems: 'center',
    marginBottom: 16,
  },
  trackTitle: {
    fontSize: 20,
    fontWeight: '800',
    color: '#FFFFFF',
    marginBottom: 6,
    maxWidth: SCREEN_WIDTH - 60,
  },
  trackArtist: {
    fontSize: 14,
    color: '#FB7299',
    fontWeight: '600',
    marginBottom: 20,
  },
  danmakuBar: {
    backgroundColor: 'rgba(0,0,0,0.4)',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#00AEEC',
    borderStyle: 'dashed',
    padding: 12,
    marginBottom: 30,
  },
  danmakuContent: {
    alignItems: 'center',
  },
  danmakuText: {
    fontSize: 14,
    color: '#00AEEC',
    fontWeight: '600',
  },
  controlsContainer: {
    paddingBottom: 30,
  },
  progressBar: {
    marginBottom: 24,
  },
  progressRail: {
    height: 4,
    backgroundColor: '#33333F',
    borderRadius: 2,
    overflow: 'hidden',
    marginBottom: 8,
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#FB7299',
  },
  progressTime: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  timeText: {
    fontSize: 11,
    color: '#9E9EAF',
  },
  buttonsRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 32,
  },
  controlBtn: {
    padding: 8,
  },
  controlIcon: {
    fontSize: 24,
  },
  playBtn: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#FFFFFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  playIcon: {
    fontSize: 24,
    color: '#000',
  },
});
