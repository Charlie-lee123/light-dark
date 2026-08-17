# Auto Theme Switcher

Windows 自动深色/浅色模式切换工具，基于当地日出日落时间自动切换系统主题。

## ✨ 功能

- 🌅 **日出切换浅色** — 每天日出后自动切换到浅色模式
- 🌇 **日落切换深色** — 每天日落后自动切换到深色模式
- 📡 **自动获取时间** — 通过 API 获取精确的日出日落时间（精确到分钟）
- 🔄 **每日自动刷新** — 凌晨 00:05 自动更新当天时间并注册切换任务
- 💾 **离线兜底** — API 失败时使用上次缓存的时间
- 🎛️ **手动控制** — 支持 `-Dark` / `-Light` 强制切换

## 🚀 快速开始

### 一键安装

在 PowerShell 中运行：

```powershell
# 下载脚本后，运行即可自动配置
.\auto-theme.ps1
```

脚本会自动：
1. 获取当天日出日落时间
2. 根据当前时间设置主题
3. 注册 Windows 计划任务（每天 00:05 刷新）

### 手动控制

```powershell
# 强制深色模式
.\auto-theme.ps1 -Dark

# 强制浅色模式
.\auto-theme.ps1 -Light

# 仅设置主题（不注册任务）
.\auto-theme.ps1 -SetTheme
```

## 📍 坐标配置

默认使用重庆大学（29.57°N, 106.45°E）的坐标。如需修改：

编辑配置文件 `~/.auto-theme/config.json`：

```json
{
    "latitude": 39.90,
    "longitude": 116.40,
    "darkMode": true,
    "lastDate": "2026-08-17",
    "sunrise": "05:45",
    "sunset": "19:20"
}
```

常用城市坐标：
| 城市 | 纬度 | 经度 |
|------|------|------|
| 北京 | 39.90 | 116.40 |
| 上海 | 31.23 | 121.47 |
| 广州 | 23.13 | 113.26 |
| 深圳 | 22.54 | 114.06 |
| 成都 | 30.57 | 104.07 |
| 重庆 | 29.57 | 106.45 |
| 杭州 | 30.27 | 120.15 |
| 武汉 | 30.59 | 114.31 |
| 西安 | 34.26 | 108.94 |
| 南京 | 32.06 | 118.80 |

## 📁 文件结构

```
~/.auto-theme/
├── config.json        # 配置文件（坐标、缓存时间）
└── auto-theme.log     # 运行日志
```

## ⚙️ 工作原理

1. **获取时间** — 调用 `sunrise-sunset.org` API 获取当天日出日落时间
2. **设置主题** — 通过修改注册表切换 Windows 深色/浅色模式
   - 深色：`AppsUseLightTheme = 0`, `SystemUsesLightTheme = 0`
   - 浅色：`AppsUseLightTheme = 1`, `SystemUsesLightTheme = 1`
3. **注册任务** — 通过 Windows 计划任务在日出/日落时刻触发切换
4. **每日刷新** — 凌晨 00:05 重新获取时间并更新任务

## 🛡️ 注意事项

- 脚本以当前用户权限运行，无需管理员权限
- 修改的是当前用户的主题设置，不影响其他用户
- 建议保持默认的 `darkMode: true`（日落深色、日出浅色）
- 如需卸载，删除 `~/.auto-theme/` 目录并运行以下命令移除计划任务：
  ```powershell
  Get-ScheduledTask -TaskName "AutoTheme*" | Unregister-ScheduledTask -Confirm:$false
  ```

## 📜 License

MIT License
