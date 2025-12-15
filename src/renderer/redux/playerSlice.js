import { createSlice } from "@reduxjs/toolkit";

// 播放器状态切片
const playerSlice = createSlice({
  name: "player",
  initialState: {
    currentTrack: null,
    currentTrackIndex: -1, // 当前播放歌曲在列表中的索引
    isPlaying: false,
    volume: 0.8,
    currentTime: 0,
    duration: 0,
    playbackRate: 1,
    repeatMode: "none", // none, one, all
    shuffle: false,
    shuffleHistory: [], // 随机播放历史记录
    equalizer: [],
    state: "idle", // idle, loading, playing, paused, ended
  },
  reducers: {
    // 设置当前播放歌曲
    setCurrentTrack: (state, action) => {
      state.currentTrack = action.payload.track || action.payload;
      state.currentTrackIndex =
        action.payload.index !== undefined
          ? action.payload.index
          : state.currentTrackIndex;
    },
    // 设置当前播放歌曲索引
    setCurrentTrackIndex: (state, action) => {
      state.currentTrackIndex = action.payload;
    },
    // 切换播放状态
    togglePlay: (state) => {
      state.isPlaying = !state.isPlaying;
    },
    // 设置播放状态
    setPlaying: (state, action) => {
      state.isPlaying = action.payload;
    },
    // 设置音量
    setVolume: (state, action) => {
      state.volume = action.payload;
    },
    // 设置当前播放时间
    setCurrentTime: (state, action) => {
      state.currentTime = action.payload;
    },
    // 设置歌曲总时长
    setDuration: (state, action) => {
      state.duration = action.payload;
    },
    // 设置播放速率
    setPlaybackRate: (state, action) => {
      state.playbackRate = action.payload;
    },
    // 设置循环模式
    setRepeatMode: (state, action) => {
      state.repeatMode = action.payload;
    },
    // 切换随机播放
    toggleShuffle: (state) => {
      state.shuffle = !state.shuffle;
      // 清空随机播放历史
      if (state.shuffle) {
        state.shuffleHistory =
          state.currentTrackIndex >= 0 ? [state.currentTrackIndex] : [];
      } else {
        state.shuffleHistory = [];
      }
    },
    // 设置随机播放
    setShuffle: (state, action) => {
      state.shuffle = action.payload;
      if (!action.payload) {
        state.shuffleHistory = [];
      }
    },
    // 添加到随机播放历史
    addToShuffleHistory: (state, action) => {
      state.shuffleHistory.push(action.payload);
    },
    // 清空随机播放历史
    clearShuffleHistory: (state) => {
      state.shuffleHistory = [];
    },
    // 设置均衡器
    setEqualizer: (state, action) => {
      state.equalizer = action.payload;
    },
    // 设置播放状态
    setState: (state, action) => {
      state.state = action.payload;
    },
    // 重置播放器状态
    resetPlayer: (state) => {
      state.currentTrack = null;
      state.currentTrackIndex = -1;
      state.isPlaying = false;
      state.currentTime = 0;
      state.duration = 0;
      state.state = "idle";
      state.shuffleHistory = [];
    },
  },
});

// 导出action creators
export const {
  setCurrentTrack,
  setCurrentTrackIndex,
  togglePlay,
  setPlaying,
  setVolume,
  setCurrentTime,
  setDuration,
  setPlaybackRate,
  setRepeatMode,
  toggleShuffle,
  setShuffle,
  addToShuffleHistory,
  clearShuffleHistory,
  setEqualizer,
  setState,
  resetPlayer,
} = playerSlice.actions;

// 导出reducer
export default playerSlice.reducer;
