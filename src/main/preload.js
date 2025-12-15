// 预加载脚本，用于主进程和渲染进程之间的通信

// 这里可以暴露一些API给渲染进程
window.electron = {
  // 示例：获取应用版本
  getAppVersion: () => {
    return process.versions.app || process.versions.electron;
  },
};
