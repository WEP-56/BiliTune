import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useSettingsStore, useUserStore } from '@bilitune/store';

export default function RootLayout() {
  const initSettings = useSettingsStore((s) => s.init);
  const initUser = useUserStore((s) => s.init);

  useEffect(() => {
    initSettings();
    initUser();
  }, []);

  return (
    <>
      <StatusBar style="light" />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen
          name="player"
          options={{
            presentation: 'fullScreenModal',
            animation: 'slide_from_bottom',
          }}
        />
      </Stack>
    </>
  );
}
