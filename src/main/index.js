import { app, BrowserWindow } from 'electron';
import path from 'path';

// 保持对主窗口的全局引用，防止被垃圾回收
let mainWindow;

function createWindow() {
  // 创建浏览器窗口
  mainWindow = new BrowserWindow({
    width: 1024,
    height: 600,
    minWidth: 800,
    minHeight: 480,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: true,
      contextIsolation: false,
    },
    title: '音乐播放器',
  });

  // 加载应用
  if (process.env.VITE_DEV_SERVER_URL) {
    // 开发环境下加载Vite开发服务器
    mainWindow.loadURL(process.env.VITE_DEV_SERVER_URL);
    // 打开开发者工具
    mainWindow.webContents.openDevTools();
  } else {
    // 生产环境下加载构建后的文件
    mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
  }

  // 窗口关闭时触发
  mainWindow.on('closed', () => {
    // 取消引用窗口对象，若应用支持多窗口则保留数组
    mainWindow = null;
  });
}

// 当Electron完成初始化并准备创建浏览器窗口时触发
app.on('ready', createWindow);

// 当所有窗口都关闭时退出应用
app.on('window-all-closed', () => {
  // 在macOS上，应用及其菜单栏通常保持活跃状态，直到用户使用Cmd+Q明确退出
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  // 在macOS上，当点击 dock 图标并且没有其他窗口打开时，通常会重新创建一个窗口
  if (mainWindow === null) {
    createWindow();
  }
});
