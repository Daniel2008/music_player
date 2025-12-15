import React from 'react';
import styled from 'styled-components';
import { useSelector, useDispatch } from 'react-redux';
import { Input, Table, Tag, Space } from 'antd';
import { PlayCircleOutlined, PlusOutlined, SearchOutlined } from '@ant-design/icons';
import { setCurrentTrack, setPlaying } from '../redux/playerSlice';

// 播放列表组件
const Playlist = () => {
  const dispatch = useDispatch();
  const { tracks, searchQuery } = useSelector(state => state.library);
  const { currentTrack } = useSelector(state => state.player);
  const [filteredTracks, setFilteredTracks] = React.useState([]);

  // 过滤歌曲列表
  React.useEffect(() => {
    if (searchQuery) {
      const filtered = tracks.filter(track => 
        track.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        track.artist.toLowerCase().includes(searchQuery.toLowerCase()) ||
        track.album.toLowerCase().includes(searchQuery.toLowerCase())
      );
      setFilteredTracks(filtered);
    } else {
      setFilteredTracks(tracks);
    }
  }, [tracks, searchQuery]);

  // 格式化时间
  const formatTime = (seconds) => {
    if (!seconds || isNaN(seconds)) return '0:00';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  // 播放歌曲
  const handlePlayTrack = (track) => {
    dispatch(setCurrentTrack(track));
    dispatch(setPlaying(true));
  };

  // 表格列配置
  const columns = [
    {
      title: '序号',
      dataIndex: 'index',
      key: 'index',
      width: 50,
      render: (text, record, index) => (
        <PlayButton 
          onClick={() => handlePlayTrack(record)} 
          className={currentTrack?.id === record.id ? 'active' : ''}
        >
          <PlayCircleOutlined />
        </PlayButton>
      ),
    },
    {
      title: '标题',
      dataIndex: 'title',
      key: 'title',
      ellipsis: true,
      render: (text, record) => (
        <TrackTitle className={currentTrack?.id === record.id ? 'active' : ''}>
          {text}
        </TrackTitle>
      ),
    },
    {
      title: '艺术家',
      dataIndex: 'artist',
      key: 'artist',
      ellipsis: true,
      width: 150,
    },
    {
      title: '专辑',
      dataIndex: 'album',
      key: 'album',
      ellipsis: true,
      width: 150,
    },
    {
      title: '流派',
      dataIndex: 'genre',
      key: 'genre',
      ellipsis: true,
      width: 100,
      render: (text) => <Tag color="blue">{text || '未知'}</Tag>,
    },
    {
      title: '时长',
      dataIndex: 'duration',
      key: 'duration',
      width: 80,
      render: (text) => formatTime(text),
    },
  ];

  // 表格数据转换
  const tableData = filteredTracks.map((track, index) => ({
    ...track,
    key: track.id,
    index: index + 1,
  }));

  return (
    <PlaylistWrapper>
      {/* 顶部搜索和操作栏 */}
      <PlaylistHeader>
        <SearchBar
          placeholder="搜索歌曲、艺术家或专辑"
          prefix={<SearchOutlined />}
          onChange={(e) => dispatch({ type: 'library/setSearchQuery', payload: e.target.value })}
          value={searchQuery}
        />
        <AddButton>
          <PlusOutlined /> 添加歌曲
        </AddButton>
      </PlaylistHeader>

      {/* 歌曲列表 */}
      <PlaylistContent>
        <Table
          columns={columns}
          dataSource={tableData}
          pagination={false}
          scroll={{ y: 'calc(100vh - 320px - 80px - 64px - 48px)' }}
          rowClassName={(record) => currentTrack?.id === record.id ? 'playing-track' : ''}
          bordered={false}
        />
      </PlaylistContent>

      {/* 底部统计信息 */}
      <PlaylistFooter>
        <SongCount>共 {filteredTracks.length} 首歌曲</SongCount>
      </PlaylistFooter>
    </PlaylistWrapper>
  );
};

// 样式定义
const PlaylistWrapper = styled.div`
  display: flex;
  flex-direction: column;
  width: 100%;
  background-color: var(--secondary-background-color);
  overflow: hidden;
`;

const PlaylistHeader = styled.div`
  display: flex;
  align-items: center;
  padding: 16px 24px;
  border-bottom: 1px solid var(--border-color);
  gap: 12px;
`;

const SearchBar = styled(Input)`
  flex: 1;
  max-width: 400px;
  background-color: var(--background-color);
  border-color: var(--border-color);
  color: var(--text-color);

  & .ant-input-prefix {
    color: var(--secondary-text-color);
  }

  &:focus {
    border-color: var(--primary-color);
    box-shadow: 0 0 0 2px rgba(74, 144, 226, 0.2);
  }
`;

const AddButton = styled.button`
  background-color: var(--primary-color);
  color: white;
  border: none;
  border-radius: 4px;
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 8px;
  transition: all 0.2s ease;

  &:hover {
    background-color: #357ABD;
    transform: translateY(-1px);
    box-shadow: 0 2px 8px rgba(74, 144, 226, 0.3);
  }

  &:active {
    transform: translateY(0);
  }
`;

const PlaylistContent = styled.div`
  flex: 1;
  overflow: auto;
  padding: 0 24px;
`;

const PlaylistFooter = styled.div`
  padding: 12px 24px;
  border-top: 1px solid var(--border-color);
  background-color: var(--secondary-background-color);
`;

const SongCount = styled.span`
  font-size: 12px;
  color: var(--secondary-text-color);
`;

const PlayButton = styled.button`
  background: none;
  border: none;
  color: var(--secondary-text-color);
  cursor: pointer;
  padding: 4px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
  opacity: 0.6;

  &:hover {
    color: var(--primary-color);
    background-color: rgba(74, 144, 226, 0.1);
    opacity: 1;
  }

  &.active {
    color: var(--primary-color);
    opacity: 1;
  }

  /* 表格行悬停时显示播放按钮 */
  .ant-table-row:hover & {
    opacity: 1;
  }
`;

const TrackTitle = styled.span`
  color: var(--text-color);
  transition: color 0.2s ease;

  &.active {
    color: var(--primary-color);
    font-weight: 500;
  }
`;

export default Playlist;
