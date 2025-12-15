import React from "react";
import styled from "styled-components";
import { useSelector, useDispatch } from "react-redux";
import { Slider, Tooltip } from "antd";
import {
  PlayCircleOutlined,
  PauseCircleOutlined,
  StepBackwardOutlined,
  StepForwardOutlined,
  ShuffleOutlined,
  CustomerServiceOutlined,
  ReloadOutlined,
  SoundOutlined,
  FullscreenOutlined,
  FullscreenExitOutlined,
} from "@ant-design/icons";
import {
  togglePlay,
  setCurrentTime,
  setVolume,
  toggleShuffle,
  setRepeatMode,
  setCurrentTrack,
  setCurrentTrackIndex,
  setPlaying,
  addToShuffleHistory,
} from "../redux/playerSlice";

// 底部播放控制栏组件
const PlayerControls = () => {
  const dispatch = useDispatch();
  const {
    currentTrack,
    currentTrackIndex,
    isPlaying,
    volume,
    currentTime,
    duration,
    shuffle,
    shuffleHistory,
    repeatMode,
  } = useSelector((state) => state.player);
  const { tracks } = useSelector((state) => state.library);
  const [isMuted, setIsMuted] = React.useState(false);
  const [prevVolume, setPrevVolume] = React.useState(volume);
  const [isFullscreen, setIsFullscreen] = React.useState(false);

  // 格式化时间
  const formatTime = (seconds) => {
    if (!seconds || isNaN(seconds)) return "0:00";
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  };

  // 切换播放状态
  const handleTogglePlay = () => {
    dispatch(togglePlay());
  };

  // 处理进度条变化
  const handleProgressChange = (value) => {
    dispatch(setCurrentTime(value));
  };

  // 处理音量变化
  const handleVolumeChange = (value) => {
    dispatch(setVolume(value));
    if (isMuted) {
      setIsMuted(false);
    }
  };

  // 切换静音状态
  const handleToggleMute = () => {
    if (isMuted) {
      // 取消静音，恢复之前的音量
      dispatch(setVolume(prevVolume));
      setIsMuted(false);
    } else {
      // 静音，保存当前音量
      setPrevVolume(volume);
      dispatch(setVolume(0));
      setIsMuted(true);
    }
  };

  // 获取随机索引（不重复）
  const getRandomIndex = (currentIndex, totalTracks) => {
    if (totalTracks <= 1) return 0;

    // 创建可用索引数组（排除历史记录中的索引）
    const availableIndices = [];
    for (let i = 0; i < totalTracks; i++) {
      if (!shuffleHistory.includes(i)) {
        availableIndices.push(i);
      }
    }

    // 如果所有歌曲都播放过了，清空历史重新开始
    if (availableIndices.length === 0) {
      for (let i = 0; i < totalTracks; i++) {
        if (i !== currentIndex) {
          availableIndices.push(i);
        }
      }
    }

    // 随机选择一个索引
    const randomIdx = Math.floor(Math.random() * availableIndices.length);
    return availableIndices[randomIdx];
  };

  // 播放上一曲
  const handlePrevious = () => {
    if (!tracks || tracks.length === 0) return;

    let newIndex;

    if (shuffle) {
      // 随机模式：从历史记录中获取上一首
      if (shuffleHistory.length > 1) {
        // 移除当前索引，获取上一个
        const historyWithoutCurrent = [...shuffleHistory];
        historyWithoutCurrent.pop();
        newIndex = historyWithoutCurrent[historyWithoutCurrent.length - 1];
      } else {
        // 没有历史记录，随机选择
        newIndex = getRandomIndex(currentTrackIndex, tracks.length);
        dispatch(addToShuffleHistory(newIndex));
      }
    } else {
      // 顺序模式
      newIndex =
        currentTrackIndex > 0 ? currentTrackIndex - 1 : tracks.length - 1;
    }

    dispatch(setCurrentTrack({ track: tracks[newIndex], index: newIndex }));
    dispatch(setPlaying(true));
  };

  // 播放下一曲
  const handleNext = () => {
    if (!tracks || tracks.length === 0) return;

    let newIndex;

    if (shuffle) {
      // 随机模式
      newIndex = getRandomIndex(currentTrackIndex, tracks.length);
      dispatch(addToShuffleHistory(newIndex));
    } else {
      // 顺序模式
      if (repeatMode === "all") {
        // 列表循环
        newIndex = (currentTrackIndex + 1) % tracks.length;
      } else if (repeatMode === "one") {
        // 单曲循环
        newIndex = currentTrackIndex;
      } else {
        // 顺序播放
        newIndex =
          currentTrackIndex < tracks.length - 1 ? currentTrackIndex + 1 : 0;
      }
    }

    dispatch(setCurrentTrack({ track: tracks[newIndex], index: newIndex }));
    dispatch(setPlaying(true));
  };

  // 切换随机播放
  const handleToggleShuffle = () => {
    dispatch(toggleShuffle());
  };

  // 切换循环模式
  const handleToggleRepeat = () => {
    const modes = ["none", "one", "all"];
    const currentIndex = modes.indexOf(repeatMode);
    const nextIndex = (currentIndex + 1) % modes.length;
    dispatch(setRepeatMode(modes[nextIndex]));
  };

  // 切换全屏模式
  const handleToggleFullscreen = () => {
    setIsFullscreen(!isFullscreen);
    // 这里需要实现全屏切换逻辑
  };

  // 默认封面
  const defaultCover = "https://via.placeholder.com/40x40?text=No+Cover";

  return (
    <ControlsWrapper>
      {/* 左侧：当前播放歌曲信息 */}
      <LeftSection>
        <CoverThumbnail
          src={currentTrack?.coverPath || defaultCover}
          alt={currentTrack?.title || "默认封面"}
        />
        <TrackInfo>
          <TrackTitle>{currentTrack?.title || "未播放歌曲"}</TrackTitle>
          <TrackArtist>{currentTrack?.artist || "未知艺术家"}</TrackArtist>
        </TrackInfo>
      </LeftSection>

      {/* 中间：播放控制按钮 */}
      <CenterSection>
        <ControlButtons>
          <Tooltip title={shuffle ? "取消随机播放" : "随机播放"}>
            <ControlButton
              onClick={handleToggleShuffle}
              className={shuffle ? "active" : ""}
            >
              <ShuffleOutlined />
            </ControlButton>
          </Tooltip>

          <Tooltip title="上一曲">
            <ControlButton onClick={handlePrevious}>
              <StepBackwardOutlined />
            </ControlButton>
          </Tooltip>

          <Tooltip title={isPlaying ? "暂停" : "播放"}>
            <PlayButton onClick={handleTogglePlay}>
              {isPlaying ? <PauseCircleOutlined /> : <PlayCircleOutlined />}
            </PlayButton>
          </Tooltip>

          <Tooltip title="下一曲">
            <ControlButton onClick={handleNext}>
              <StepForwardOutlined />
            </ControlButton>
          </Tooltip>

          <Tooltip
            title={
              repeatMode === "none"
                ? "单曲循环"
                : repeatMode === "one"
                  ? "列表循环"
                  : "取消循环"
            }
          >
            <ControlButton
              onClick={handleToggleRepeat}
              className={repeatMode !== "none" ? "active" : ""}
            >
              <ReloadOutlined />
            </ControlButton>
          </Tooltip>
        </ControlButtons>

        {/* 进度条 */}
        <ProgressSection>
          <TimeDisplay>{formatTime(currentTime)}</TimeDisplay>
          <Slider
            value={duration > 0 ? currentTime : 0}
            min={0}
            max={duration || 100}
            onChange={handleProgressChange}
            tooltip={{ formatter: formatTime }}
            trackStyle={{ backgroundColor: "#4A90E2" }}
            handleStyle={{ borderColor: "#4A90E2", backgroundColor: "#fff" }}
            railStyle={{ backgroundColor: "var(--border-color)" }}
            className="progress-slider"
          />
          <TimeDisplay>{formatTime(duration)}</TimeDisplay>
        </ProgressSection>
      </CenterSection>

      {/* 右侧：音量控制和其他功能 */}
      <RightSection>
        <VolumeControl>
          <Tooltip title={isMuted ? "取消静音" : "静音"}>
            <VolumeButton onClick={handleToggleMute}>
              <SoundOutlined />
            </VolumeButton>
          </Tooltip>
          <VolumeSlider
            value={isMuted ? 0 : volume}
            min={0}
            max={1}
            step={0.01}
            onChange={handleVolumeChange}
            trackStyle={{ backgroundColor: "#4A90E2" }}
            handleStyle={{ borderColor: "#4A90E2", backgroundColor: "#fff" }}
            railStyle={{ backgroundColor: "var(--border-color)" }}
          />
        </VolumeControl>

        <Tooltip title={isFullscreen ? "退出全屏" : "全屏模式"}>
          <ControlButton onClick={handleToggleFullscreen}>
            {isFullscreen ? <FullscreenExitOutlined /> : <FullscreenOutlined />}
          </ControlButton>
        </Tooltip>
      </RightSection>
    </ControlsWrapper>
  );
};

// 样式定义
const ControlsWrapper = styled.div`
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 80px;
  padding: 0 24px;
  background-color: var(--secondary-background-color);
  border-top: 1px solid var(--border-color);
`;

const LeftSection = styled.div`
  display: flex;
  align-items: center;
  flex: 0 0 300px;
`;

const CoverThumbnail = styled.img`
  width: 48px;
  height: 48px;
  object-fit: cover;
  border-radius: 4px;
  margin-right: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
`;

const TrackInfo = styled.div`
  flex: 1;
  overflow: hidden;
`;

const TrackTitle = styled.div`
  font-size: 14px;
  font-weight: 500;
  color: var(--text-color);
  margin: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
`;

const TrackArtist = styled.div`
  font-size: 12px;
  color: var(--secondary-text-color);
  margin: 2px 0 0 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
`;

const CenterSection = styled.div`
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 0 24px;
`;

const ControlButtons = styled.div`
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 12px;
`;

const ControlButton = styled.button`
  background: none;
  border: none;
  color: var(--text-color);
  cursor: pointer;
  padding: 8px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
  font-size: 18px;

  &:hover {
    color: var(--primary-color);
    background-color: rgba(74, 144, 226, 0.1);
  }

  &.active {
    color: var(--primary-color);
  }
`;

const PlayButton = styled.button`
  background-color: var(--primary-color);
  color: white;
  border: none;
  cursor: pointer;
  padding: 16px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
  font-size: 28px;
  width: 48px;
  height: 48px;
  box-shadow: 0 4px 12px rgba(74, 144, 226, 0.3);

  &:hover {
    background-color: #357abd;
    transform: scale(1.05);
    box-shadow: 0 6px 16px rgba(74, 144, 226, 0.4);
  }

  &:active {
    transform: scale(1);
  }
`;

const ProgressSection = styled.div`
  display: flex;
  align-items: center;
  width: 100%;
  gap: 12px;
`;

const TimeDisplay = styled.span`
  font-size: 12px;
  color: var(--secondary-text-color);
  min-width: 40px;
  text-align: center;
`;

const RightSection = styled.div`
  display: flex;
  align-items: center;
  gap: 16px;
  flex: 0 0 200px;
  justify-content: flex-end;
`;

const VolumeControl = styled.div`
  display: flex;
  align-items: center;
  gap: 8px;
  width: 120px;
`;

const VolumeButton = styled.button`
  background: none;
  border: none;
  color: var(--text-color);
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;

  &:hover {
    color: var(--primary-color);
    background-color: rgba(74, 144, 226, 0.1);
  }
`;

const VolumeSlider = styled(Slider)`
  flex: 1;
`;

export default PlayerControls;
