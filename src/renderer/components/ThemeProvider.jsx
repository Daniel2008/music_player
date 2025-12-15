import React from 'react';
import { useSelector } from 'react-redux';
import { ConfigProvider } from 'antd';
import styled from 'styled-components';

// 主题提供者组件
const ThemeProvider = ({ children }) => {
  // 从Redux获取当前主题
  const { currentTheme } = useSelector(state => state.theme);

  // 转换为Ant Design的主题配置
  const antdTheme = {
    token: {
      colorPrimary: currentTheme.colors.primary,
      colorSuccess: currentTheme.colors.success,
      colorWarning: currentTheme.colors.warning,
      colorError: currentTheme.colors.error,
      colorText: currentTheme.colors.text,
      colorTextSecondary: currentTheme.colors.secondaryText,
      colorBorder: currentTheme.colors.border,
      colorBgContainer: currentTheme.colors.secondaryBackground,
      colorBgLayout: currentTheme.colors.background,
    },
  };

  return (
    <ConfigProvider theme={antdTheme}>
      <ThemeWrapper theme={currentTheme}>
        {children}
      </ThemeWrapper>
    </ConfigProvider>
  );
};

// 主题样式包装器
const ThemeWrapper = styled.div`
  /* 设置CSS变量 */
  --primary-color: ${props => props.theme.colors.primary};
  --secondary-color: ${props => props.theme.colors.secondary};
  --background-color: ${props => props.theme.colors.background};
  --secondary-background-color: ${props => props.theme.colors.secondaryBackground};
  --text-color: ${props => props.theme.colors.text};
  --secondary-text-color: ${props => props.theme.colors.secondaryText};
  --border-color: ${props => props.theme.colors.border};
  --success-color: ${props => props.theme.colors.success};
  --warning-color: ${props => props.theme.colors.warning};
  --error-color: ${props => props.theme.colors.error};

  /* 应用主题到全局 */
  background-color: var(--background-color);
  color: var(--text-color);
  min-height: 100vh;
  font-family: 'SF Pro Display', 'Roboto', '微软雅黑', sans-serif;

  /* 覆盖默认样式 */
  * {
    box-sizing: border-box;
  }

  /* 链接样式 */
  a {
    color: var(--primary-color);
    text-decoration: none;

    &:hover {
      text-decoration: underline;
    }
  }
`;

export default ThemeProvider;
