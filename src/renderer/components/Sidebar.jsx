import React from 'react';
import styled from 'styled-components';
import { useNavigate } from 'react-router-dom';
import { 
  HomeOutlined, 
  MusicOutlined, 
  PlayCircleOutlined, 
  SettingOutlined, 
  MenuFoldOutlined, 
  MenuUnfoldOutlined 
} from '@ant-design/icons';

// 侧边栏组件
const Sidebar = () => {
  const navigate = useNavigate();
  const [collapsed, setCollapsed] = React.useState(false);

  // 导航菜单项
  const menuItems = [
    { key: 'home', icon: <HomeOutlined />, label: '首页', path: '/' },
    { key: 'library', icon: <MusicOutlined />, label: '音乐库', path: '/library' },
    { key: 'playlists', icon: <PlayCircleOutlined />, label: '播放列表', path: '/playlists' },
    { key: 'settings', icon: <SettingOutlined />, label: '设置', path: '/settings' },
  ];

  return (
    <SidebarWrapper collapsed={collapsed}>
      {/* 应用标题 */}
      <SidebarHeader>
        <AppLogo>
          <MusicOutlined style={{ fontSize: '24px', color: 'var(--primary-color)' }} />
        </AppLogo>
        {!collapsed && <AppTitle>音乐播放器</AppTitle>}
        <ToggleButton onClick={() => setCollapsed(!collapsed)}>
          {collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
        </ToggleButton>
      </SidebarHeader>

      {/* 导航菜单 */}
      <MenuList>
        {menuItems.map(item => (
          <MenuItem key={item.key} onClick={() => navigate(item.path)}>
            <MenuItemIcon>{item.icon}</MenuItemIcon>
            {!collapsed && <MenuItemLabel>{item.label}</MenuItemLabel>}
          </MenuItem>
        ))}
      </MenuList>

      {/* 播放列表部分 */}
      {!collapsed && (
        <PlaylistsSection>
          <SectionTitle>我的播放列表</SectionTitle>
          <PlaylistList>
            {/* 这里可以动态加载播放列表 */}
            <PlaylistItem>我喜欢的音乐</PlaylistItem>
            <PlaylistItem>最近播放</PlaylistItem>
            <PlaylistItem>创建的播放列表</PlaylistItem>
          </PlaylistList>
        </PlaylistsSection>
      )}
    </SidebarWrapper>
  );
};

// 样式定义
const SidebarWrapper = styled.div`
  width: ${props => props.collapsed ? '64px' : '240px'};
  height: 100vh;
  background-color: var(--secondary-background-color);
  border-right: 1px solid var(--border-color);
  position: fixed;
  top: 0;
  left: 0;
  transition: width 0.3s ease;
  overflow: hidden;
  z-index: 100;
`;

const SidebarHeader = styled.div`
  display: flex;
  align-items: center;
  padding: 16px;
  border-bottom: 1px solid var(--border-color);
  height: 64px;
`;

const AppLogo = styled.div`
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 12px;
`;

const AppTitle = styled.h1`
  font-size: 18px;
  font-weight: 600;
  margin: 0;
  color: var(--text-color);
  flex: 1;
`;

const ToggleButton = styled.button`
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
    background-color: var(--background-color);
    color: var(--primary-color);
  }
`;

const MenuList = styled.ul`
  list-style: none;
  padding: 0;
  margin: 0;
`;

const MenuItem = styled.li`
  display: flex;
  align-items: center;
  padding: 12px 16px;
  cursor: pointer;
  transition: all 0.2s ease;
  color: var(--text-color);

  &:hover {
    background-color: var(--background-color);
    color: var(--primary-color);
  }

  &.active {
    background-color: var(--background-color);
    color: var(--primary-color);
    border-right: 3px solid var(--primary-color);
  }
`;

const MenuItemIcon = styled.div`
  margin-right: 12px;
  font-size: 18px;
`;

const MenuItemLabel = styled.span`
  font-size: 14px;
`;

const PlaylistsSection = styled.div`
  margin-top: 24px;
  padding: 0 16px;
`;

const SectionTitle = styled.h3`
  font-size: 12px;
  font-weight: 600;
  color: var(--secondary-text-color);
  text-transform: uppercase;
  margin: 0 0 12px 0;
  letter-spacing: 0.5px;
`;

const PlaylistList = styled.ul`
  list-style: none;
  padding: 0;
  margin: 0;
`;

const PlaylistItem = styled.li`
  padding: 8px 0;
  font-size: 14px;
  color: var(--text-color);
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    color: var(--primary-color);
  }
`;

export default Sidebar;
