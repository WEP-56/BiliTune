import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import { usePlayerStore } from '@bilitune/store';

export default function MiniPlayer() {
  const router = useRouter();
  const { currentTrack, isPlaying, togglePlay, next } = usePlayerStore();

  const handlePress = () => {
    if (currentTrack) {
      router.push('/player');
    }
  };

  return (
    <TouchableOpacity
      style={styles.container}
      onPress={handlePress}
      activeOpacity={0.9}
    >
      <View style={styles.left}>
        <View style={styles.cover}>
          <View style={styles.coverGradient} />
        </View>
        <View style={styles.info}>
          <Text style={styles.title} numberOfLines={1}>
            {currentTrack?.title || '未在播放'}
          </Text>
          <Text style={styles.subtitle}>
            {currentTrack ? `UP: ${currentTrack.artist}` : '选择一首歌曲'}
          </Text>
        </View>
      </View>

      <View style={styles.controls}>
        <TouchableOpacity onPress={togglePlay} style={styles.btn}>
          <Text style={styles.btnText}>{isPlaying ? '⏸' : '▶'}</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={next} style={styles.btn}>
          <Text style={styles.btnText}>⏭</Text>
        </TouchableOpacity>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    bottom: 64,
    left: 12,
    right: 12,
    height: 56,
    backgroundColor: 'rgba(22, 22, 28, 0.96)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.06)',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 14,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.5,
    shadowRadius: 24,
    elevation: 10,
  },
  left: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    flex: 1,
  },
  cover: {
    width: 36,
    height: 36,
    borderRadius: 6,
    overflow: 'hidden',
  },
  coverGradient: {
    width: '100%',
    height: '100%',
    backgroundColor: '#FB7299',
  },
  info: {
    flex: 1,
  },
  title: {
    fontSize: 13,
    fontWeight: '600',
    color: '#FFFFFF',
    maxWidth: 160,
  },
  subtitle: {
    fontSize: 11,
    color: '#FB7299',
  },
  controls: {
    flexDirection: 'row',
    gap: 14,
  },
  btn: {
    padding: 4,
  },
  btnText: {
    fontSize: 16,
  },
});
