import { createSlice } from '@reduxjs/toolkit';

// 播放列表状态切片
const playlistSlice = createSlice({
  name: 'playlist',
  initialState: {
    playlists: [], // 所有播放列表
    currentPlaylist: null, // 当前选中的播放列表
    isEditing: false, // 是否正在编辑播放列表
  },
  reducers: {
    // 设置播放列表列表
    setPlaylists: (state, action) => {
      state.playlists = action.payload;
    },
    // 添加播放列表
    addPlaylist: (state, action) => {
      state.playlists.push(action.payload);
    },
    // 删除播放列表
    deletePlaylist: (state, action) => {
      state.playlists = state.playlists.filter(playlist => playlist.id !== action.payload);
      // 如果删除的是当前播放列表，则重置当前播放列表
      if (state.currentPlaylist?.id === action.payload) {
        state.currentPlaylist = null;
      }
    },
    // 更新播放列表
    updatePlaylist: (state, action) => {
      const index = state.playlists.findIndex(playlist => playlist.id === action.payload.id);
      if (index !== -1) {
        state.playlists[index] = { ...state.playlists[index], ...action.payload };
        // 如果更新的是当前播放列表，则同步更新
        if (state.currentPlaylist?.id === action.payload.id) {
          state.currentPlaylist = state.playlists[index];
        }
      }
    },
    // 设置当前播放列表
    setCurrentPlaylist: (state, action) => {
      state.currentPlaylist = action.payload;
    },
    // 添加歌曲到播放列表
    addTrackToPlaylist: (state, action) => {
      const { playlistId, trackId } = action.payload;
      const playlist = state.playlists.find(p => p.id === playlistId);
      if (playlist && !playlist.tracks.includes(trackId)) {
        playlist.tracks.push(trackId);
        // 如果是当前播放列表，则同步更新
        if (state.currentPlaylist?.id === playlistId) {
          state.currentPlaylist = { ...playlist };
        }
      }
    },
    // 从播放列表中移除歌曲
    removeTrackFromPlaylist: (state, action) => {
      const { playlistId, trackId } = action.payload;
      const playlist = state.playlists.find(p => p.id === playlistId);
      if (playlist) {
        playlist.tracks = playlist.tracks.filter(id => id !== trackId);
        // 如果是当前播放列表，则同步更新
        if (state.currentPlaylist?.id === playlistId) {
          state.currentPlaylist = { ...playlist };
        }
      }
    },
    // 重新排序播放列表歌曲
    reorderTracksInPlaylist: (state, action) => {
      const { playlistId, trackIds } = action.payload;
      const playlist = state.playlists.find(p => p.id === playlistId);
      if (playlist) {
        playlist.tracks = trackIds;
        // 如果是当前播放列表，则同步更新
        if (state.currentPlaylist?.id === playlistId) {
          state.currentPlaylist = { ...playlist };
        }
      }
    },
    // 设置编辑状态
    setEditing: (state, action) => {
      state.isEditing = action.payload;
    },
  },
});

// 导出action creators
export const {
  setPlaylists,
  addPlaylist,
  deletePlaylist,
  updatePlaylist,
  setCurrentPlaylist,
  addTrackToPlaylist,
  removeTrackFromPlaylist,
  reorderTracksInPlaylist,
  setEditing,
} = playlistSlice.actions;

// 导出reducer
export default playlistSlice.reducer;
