import { configureStore } from '@reduxjs/toolkit';
import playerReducer from './playerSlice';
import libraryReducer from './librarySlice';
import playlistReducer from './playlistSlice';
import themeReducer from './themeSlice';

// 配置Redux store
export const store = configureStore({
  reducer: {
    player: playerReducer,
    library: libraryReducer,
    playlist: playlistReducer,
    theme: themeReducer,
  },
  // 开发环境下启用Redux DevTools
  devTools: process.env.NODE_ENV !== 'production',
});
