import { Tabs } from 'expo-router';
import { View, Text, StyleSheet } from 'react-native';
import MiniPlayer from '../components/MiniPlayer';

export default function TabLayout() {
  return (
    <View style={styles.container}>
      <Tabs
        screenOptions={{
          headerShown: false,
          tabBarStyle: styles.tabBar,
          tabBarActiveTintColor: '#FB7299',
          tabBarInactiveTintColor: '#9E9EAF',
          tabBarLabelStyle: styles.tabLabel,
        }}
      >
        <Tabs.Screen
          name="index"
          options={{
            title: '发现',
            tabBarIcon: ({ color }) => <Text style={[styles.tabIcon, { color }]}>🧭</Text>,
          }}
        />
        <Tabs.Screen
          name="feed"
          options={{
            title: '动态',
            tabBarIcon: ({ color }) => <Text style={[styles.tabIcon, { color }]}>⚡</Text>,
          }}
        />
        <Tabs.Screen
          name="profile"
          options={{
            title: '我的',
            tabBarIcon: ({ color }) => <Text style={[styles.tabIcon, { color }]}>👤</Text>,
          }}
        />
      </Tabs>
      <MiniPlayer />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  tabBar: {
    backgroundColor: '#060608',
    borderTopColor: 'rgba(255,255,255,0.03)',
    borderTopWidth: 1,
    height: 64,
    paddingBottom: 10,
    paddingTop: 8,
  },
  tabLabel: {
    fontSize: 10,
    fontWeight: '600',
  },
  tabIcon: {
    fontSize: 18,
  },
});
