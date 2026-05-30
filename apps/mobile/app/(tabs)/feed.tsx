import { View, Text, ScrollView, StyleSheet } from 'react-native';

export default function FeedScreen() {
  const feedItems = [
    {
      id: '1',
      author: { name: '音乐制作人米其林', face: '#E100FF' },
      time: '10分钟前',
      text: '新曲爆肝完成了！这次尝试了交响乐配纯电音的复合曲风，大家点开右下角开启高能弹幕听听看！',
      audio: { title: '【原创电音】Neon Genesis Horizon (Original Mix)' },
    },
    {
      id: '2',
      author: { name: '国风乐天派', face: '#FF512F' },
      time: '1小时前',
      text: '感谢大家的支持！国风摇滚组曲突破100万播放，今晚直播继续分享创作心得~',
      audio: { title: '【乐器实录】戏腔+电吉他即兴 Battle' },
    },
  ];

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scroll} showsVerticalScrollIndicator={false}>
        <Text style={styles.headerTitle}>关注动态</Text>

        {feedItems.map((item) => (
          <View key={item.id} style={styles.feedCard}>
            {/* Author */}
            <View style={styles.authorBar}>
              <View style={[styles.authorAvatar, { backgroundColor: item.author.face }]} />
              <View>
                <Text style={styles.authorName}>{item.author.name}</Text>
                <Text style={styles.feedTime}>{item.time} 投递了音频</Text>
              </View>
            </View>

            {/* Text */}
            <Text style={styles.feedText}>{item.text}</Text>

            {/* Audio widget */}
            <View style={styles.audioWidget}>
              <View style={styles.audioCover}>
                <Text style={{ color: '#9E9EAF' }}>🎵</Text>
              </View>
              <Text style={styles.audioTitle} numberOfLines={1}>
                {item.audio?.title}
              </Text>
            </View>
          </View>
        ))}

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
  headerTitle: {
    fontSize: 28,
    fontWeight: '800',
    color: '#FFFFFF',
    marginBottom: 20,
  },
  feedCard: {
    backgroundColor: '#181822',
    borderRadius: 14,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.02)',
  },
  authorBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 12,
  },
  authorAvatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
  },
  authorName: {
    fontSize: 13,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  feedTime: {
    fontSize: 11,
    color: '#9E9EAF',
  },
  feedText: {
    fontSize: 13,
    lineHeight: 18,
    color: '#E2E2E8',
    marginBottom: 12,
  },
  audioWidget: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: 'rgba(0,0,0,0.3)',
    borderRadius: 10,
    padding: 10,
  },
  audioCover: {
    width: 40,
    height: 40,
    borderRadius: 8,
    backgroundColor: '#444',
    justifyContent: 'center',
    alignItems: 'center',
  },
  audioTitle: {
    flex: 1,
    fontSize: 12,
    fontWeight: '600',
    color: '#D0D0D8',
  },
});
