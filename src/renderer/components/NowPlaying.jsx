import React from 'react';
import styled from 'styled-components';
import { useSelector } from 'react-redux';
import { Progress } from 'antd';

// 当前播放区组件
const NowPlaying = () => {
  // 从Redux获取当前播放状态和歌曲信息
  const { currentTrack, currentTime, duration, isPlaying } = useSelector(state => state.player);

  // 格式化时间
  const formatTime = (seconds) => {
    if (!seconds || isNaN(seconds)) return '0:00';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  // 默认封面
  const defaultCover = 'https://via.placeholder.com/200x200?text=No+Cover';

  return (
    <NowPlayingWrapper>
      {/* 专辑封面 */}
      <CoverSection>
        <CoverImage 
          src={currentTrack?.coverPath || defaultCover} 
          alt={currentTrack?.title || '默认封面'} 
          className={isPlaying ? 'playing' : ''}
        />
      </CoverSection>

      {/* 歌曲信息和歌词 */}
      <InfoSection>
        {/* 歌曲基本信息 */}
        <SongInfo>
          <SongTitle>{currentTrack?.title || '未播放歌曲'}</SongTitle>
          <SongArtist>{currentTrack?.artist || '未知艺术家'} - {currentTrack?.album || '未知专辑'}</SongArtist>
        </SongInfo>

        {/* 进度条 */}
        <ProgressSection>
          <TimeDisplay>{formatTime(currentTime)}</TimeDisplay>
          <Progress
            percent={duration > 0 ? Math.floor((currentTime / duration) * 100) : 0}
            strokeWidth={6}
            strokeColor={{
              '0%': '#4A90E2',
              '100%': '#50E3C2',
            }}
            trailColor="var(--border-color)"
            className="progress-bar"
          />
          <TimeDisplay>{formatTime(duration)}</TimeDisplay>
        </ProgressSection>

        {/* 歌词显示区 */}
        <LyricsSection>
          <LyricsText>
            {currentTrack ? '歌词显示区域' : '请选择一首歌曲开始播放'}
          </LyricsText>
        </LyricsSection>
      </InfoSection>
    </NowPlayingWrapper>
  );
};

// 样式定义
const NowPlayingWrapper = styled.div`
  display: flex;
  width: 100%;
  height: 320px;
  padding: 24px;
  background-color: var(--secondary-background-color);
  border-bottom: 1px solid var(--border-color);
`;

const CoverSection = styled.div`
  flex: 0 0 auto;
  margin-right: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
`;

const CoverImage = styled.img`
  width: 200px;
  height: 200px;
  border-radius: 50%;
  object-fit: cover;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
  transition: all 0.3s ease;

  &.playing {
    animation: rotate 20s linear infinite;
  }

  @keyframes rotate {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
`;

const InfoSection = styled.div`
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
`;

const SongInfo = styled.div`
  margin-bottom: 24px;
`;

const SongTitle = styled.h2`
  font-size: 24px;
  font-weight: 600;
  margin: 0 0 8px 0;
  color: var(--text-color);
`;

const SongArtist = styled.p`
  font-size: 14px;
  color: var(--secondary-text-color);
  margin: 0;
`;

const ProgressSection = styled.div`
  display: flex;
  align-items: center;
  margin-bottom: 24px;
`;

const TimeDisplay = styled.span`
  font-size: 12px;
  color: var(--secondary-text-color);
  margin: 0 12px;
  min-width: 40px;
  text-align: center;
`;

const LyricsSection = styled.div`
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
`;

const LyricsText = styled.div`
  font-size: 16px;
  color: var(--text-color);
  text-align: center;
  line-height: 1.8;
  max-height: 120px;
  overflow: hidden;
`;

export default NowPlaying;
