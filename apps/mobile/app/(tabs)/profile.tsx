import { View, Text, ScrollView, StyleSheet } from 'react-native';
import { useUserStore } from '@bilitune/store';

export default function ProfileScreen() {
  const isLoggedIn = useUserStore((s) => s.isLoggedIn);
  const userInfo = useUserStore((s) => s.userInfo);

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scroll} showsVerticalScrollIndicator={false}>
        <Text style={styles.headerTitle}>我的音乐空间</Text>

        {/* Stats */}
        <View style={styles.statGrid}>
          <View style={styles.statBox}>
            <Text style={styles.statValue}>1.2k</Text>
            <Text style={styles.statLabel}>收藏音频</Text>
          </View>
          <View style={styles.statBox}>
            <Text style={styles.statValue}>48</Text>
            <Text style={styles.statLabel}>订阅UP主</Text>
          </View>
          <View style={styles.statBox}>
            <Text style={styles.statValue}>326</Text>
            <Text style={styles.statLabel}>播放历史</Text>
          </View>
          <View style={styles.statBox}>
            <Text style={styles.statValue}>12</Text>
            <Text style={styles.statLabel}>歌单数</Text>
          </View>
        </View>

        {/* Local */}
        <View style={styles.sectionGroup}>
          <Text style={styles.sectionTitle}>💾 本地与离线</Text>
          <View style={styles.sectionItem}>
            <Text style={styles.sectionText}>下载管理</Text>
            <Text style={styles.sectionArrow}>›</Text>
          </View>
          <View style={styles.sectionItem}>
            <Text style={styles.sectionText}>本地音乐</Text>
            <Text style={styles.sectionArrow}>›</Text>
          </View>
        </View>

        {/* Favorites */}
        <View style={styles.sectionGroup}>
          <Text style={styles.sectionTitle}>⭐ 我的收藏夹</Text>
          <View style={styles.sectionItem}>
            <Text style={styles.sectionText}>默认收藏夹</Text>
            <Text style={styles.sectionHint}>156首</Text>
          </View>
          <View style={styles.sectionItem}>
            <Text style={styles.sectionText}>VOCALOID精选</Text>
            <Text style={styles.sectionHint}>42首</Text>
          </View>
        </View>

        {/* Account */}
        <View style={styles.sectionGroup}>
          <Text style={styles.sectionTitle}>👤 账号</Text>
          {isLoggedIn && userInfo ? (
            <View style={styles.sectionItem}>
              <Text style={styles.sectionText}>{userInfo.name}</Text>
              <Text style={styles.sectionHint}>Lv.{userInfo.level}</Text>
            </View>
          ) : (
            <View style={styles.sectionItem}>
              <Text style={styles.sectionText}>点击登录</Text>
              <Text style={styles.sectionHint}>同步B站数据</Text>
            </View>
          )}
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
  headerTitle: {
    fontSize: 28,
    fontWeight: '800',
    color: '#FFFFFF',
    marginBottom: 20,
  },
  statGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
    marginBottom: 20,
  },
  statBox: {
    backgroundColor: '#181822',
    borderRadius: 12,
    padding: 16,
    width: '47%',
    alignItems: 'center',
  },
  statValue: {
    fontSize: 20,
    fontWeight: '800',
    color: '#00AEEC',
  },
  statLabel: {
    fontSize: 12,
    color: '#9E9EAF',
    marginTop: 4,
  },
  sectionGroup: {
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#222',
    paddingBottom: 10,
    marginBottom: 8,
  },
  sectionItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.03)',
  },
  sectionText: {
    fontSize: 14,
    color: '#D0D0D8',
  },
  sectionArrow: {
    fontSize: 18,
    color: '#9E9EAF',
  },
  sectionHint: {
    fontSize: 12,
    color: '#9E9EAF',
  },
});
