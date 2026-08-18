# Auto Theme Switcher

Windows 自动深色/浅色模式切换工具。自动检测当前位置，基于日出日落时间切换系统主题。

## ✨ 功能

- 🌍 **自动定位** — 通过 IP 自动获取当前位置，无需手动设置坐标
- 🌅 **日出切换浅色** — 每天日出后自动切换到浅色模式
- 🌇 **日落切换深色** — 每天日落后自动切换到深色模式
- 📡 **每天自动更新** — 凌晨 00:05 重新定位并更新日出日落时间
- 💾 **离线兜底** — API 失败时使用上次缓存的时间和位置
- 🎛️ **手动控制** — 支持 `-Dark` / `-Light` / `-Locate`

## 🚀 快速开始

在 PowerShell 中运行：

```powershell
.\auto-theme.ps1
```

脚本会自动：
1. 通过 IP 检测你的位置
2. 获取当地日出日落时间
3. 根据当前时间设置主题
4. 注册 Windows 计划任务

### 手动控制

```powershell
# 强制深色模式
.\auto-theme.ps1 -Dark

# 强制浅色模式
.\auto-theme.ps1 -Light

# 查看当前检测到的位置
.\auto-theme.ps1 -Locate

# 仅设置主题（不注册任务）
.\auto-theme.ps1 -SetTheme
```

## 📍 定位说明

脚本使用 [ip-api.com](https://ip-api.com) 和 [ipinfo.io](https://ipinfo.io) 进行 IP 定位，每天只检测一次。

**如果定位不准**（比如使用了 VPN/代理），可以手动编辑配置文件：

配置文件位置：`~/.auto-theme/config.json`

```json
{
    "latitude":  29.57,
    "longitude": 106.45,
    "city":      "Chongqing, CN",
    "darkMode":  true,
    "lastDate":  "2026-08-17",
    "lastLocate":"2026-08-17",
    "sunrise":   "06:22",
    "sunset":    "19:34"
}
```

修改后，删除 `"lastLocate"` 字段的值（设为空字符串 `""`），下次运行就会重新获取。

### 常用城市坐标

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
├── config.json        # 配置（坐标、缓存时间）
└── auto-theme.log     # 运行日志
```

## ⚙️ 工作原理

1. **自动定位** — 每天首次运行时通过 IP 获取经纬度和城市名
2. **获取时间** — 调用 `sunrise-sunset.org` API 获取日出日落时间
3. **设置主题** — 修改注册表切换 Windows 深色/浅色模式
   - 深色：`AppsUseLightTheme = 0`
   - 浅色：`AppsUseLightTheme = 1`
4. **注册任务** — Windows 计划任务在日出/日落时刻触发切换
5. **每日刷新** — 凌晨 00:05 重新定位并更新所有任务

## 🛡️ 注意事项

- 无需管理员权限
- 修改的是当前用户的主题设置，不影响其他用户
- 如果使用 VPN，IP 定位可能不准确，建议手动设置坐标
- 卸载方式：
  ```powershell
  # 删除计划任务
  Get-ScheduledTask -TaskName "AutoTheme*" | Unregister-ScheduledTask -Confirm:$false
  # 删除配置和日志
  Remove-Item -Recurse ~/.auto-theme/
  ```

## 🐛 修复记录

### v1.2.0 — 2026-08-18
**问题**：切换主题时任务栏和开始菜单不跟随变化，只有应用窗口变色。

**原因**：任务栏是 Explorer 的子窗口，在启动时读取并缓存主题设置，修改注册表后 Explorer 不会自动重新加载。

**修复**：
- 采用 `SystemParametersInfo` 三连刷新（`SPI_SETICONSPECIALSPACING` + `SPI_SETNONCLIENTMETRICS` + `SPI_SETANIMATION`）强制系统非客户端区域重新读取主题
- 配合 `WM_SETTINGCHANGE` 广播通知所有窗口
- 完全不重启 Explorer，**零闪烁**

### v1.1.0 — 2026-08-18
**问题**：`Set-ItemProperty` 修改注册表后，只有部分应用窗口切换主题，任务栏/开始菜单完全不变。

**修复尝试**：
- v1: `WM_SETTINGCHANGE` 广播 — 无效
- v2: `DwmSetWindowAttribute` 设置任务栏深色模式属性 — 无效
- v3: 重启 Explorer — 有效但有屏幕闪烁
- v4（最终）: `SystemParametersInfo` 三连刷新 — 有效且零闪烁

## 📜 License

MIT License
