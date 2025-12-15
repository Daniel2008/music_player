import { createSlice } from '@reduxjs/toolkit';

// 音乐库状态切片
const librarySlice = createSlice({
  name: 'library',
  initialState: {
    tracks: [], // 所有歌曲列表
    isScanning: false, // 是否正在扫描音乐
    scanProgress: 0, // 扫描进度
    scanStatus: '', // 扫描状态信息
    filter: '', // 过滤条件
    sortBy: 'title', // 排序字段
    orderBy: 'asc', // 排序方向
    searchQuery: '', // 搜索关键词
  },
  reducers: {
    // 设置歌曲列表
    setTracks: (state, action) => {
      state.tracks = action.payload;
    },
    // 添加歌曲到列表
    addTrack: (state, action) => {
      state.tracks.push(action.payload);
    },
    // 从列表中移除歌曲
    removeTrack: (state, action) => {
      state.tracks = state.tracks.filter(track => track.id !== action.payload);
    },
    // 更新歌曲信息
    updateTrack: (state, action) => {
      const index = state.tracks.findIndex(track => track.id === action.payload.id);
      if (index !== -1) {
        state.tracks[index] = { ...state.tracks[index], ...action.payload };
      }
    },
    // 设置扫描状态
    setScanning: (state, action) => {
      state.isScanning = action.payload;
    },
    // 设置扫描进度
    setScanProgress: (state, action) => {
      state.scanProgress = action.payload;
    },
    // 设置扫描状态信息
    setScanStatus: (state, action) => {
      state.scanStatus = action.payload;
    },
    // 设置过滤条件
    setFilter: (state, action) => {
      state.filter = action.payload;
    },
    // 设置排序字段
    setSortBy: (state, action) => {
      state.sortBy = action.payload;
    },
    // 设置排序方向
    setOrderBy: (state, action) => {
      state.orderBy = action.payload;
    },
    // 设置搜索关键词
    setSearchQuery: (state, action) => {
      state.searchQuery = action.payload;
    },
    // 清空搜索
    clearSearch: (state) => {
      state.searchQuery = '';
    },
  },
});

// 导出action creators
export const {
  setTracks,
  addTrack,
  removeTrack,
  updateTrack,
  setScanning,
  setScanProgress,
  setScanStatus,
  setFilter,
  setSortBy,
  setOrderBy,
  setSearchQuery,
  clearSearch,
} = librarySlice.actions;

// 导出reducer
export default librarySlice.reducer;
