import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { Provider } from 'react-redux';
import { store } from './renderer/redux/store';
import ThemeProvider from './renderer/components/ThemeProvider';
import Layout from './renderer/components/Layout';
import './App.css';

// 主应用组件
function App() {
  return (
    <Provider store={store}>
      <ThemeProvider>
        <Router>
          <Layout />
          {/* 这里可以添加更多路由 */}
          <Routes>
            <Route path="/" element={<div>首页</div>} />
            <Route path="/library" element={<div>音乐库</div>} />
            <Route path="/playlists" element={<div>播放列表</div>} />
            <Route path="/settings" element={<div>设置</div>} />
          </Routes>
        </Router>
      </ThemeProvider>
    </Provider>
  );
}

export default App;