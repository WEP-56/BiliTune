const { contextBridge } = require('electron');

// Expose safe APIs to the renderer process
contextBridge.exposeInMainWorld('bilitune', {
  platform: process.platform,
  isElectron: true,
  appVersion: '1.0.0',
});
