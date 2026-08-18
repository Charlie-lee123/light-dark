# Windows 自动深色/浅色模式切换 (V2)

根据日出日落时间自动切换 Windows 深色/浅色模式。

## V2 更新内容

- ✅ **任务栏实时刷新**：新增 `Invoke-ThemeRefresh` 功能，切换后任务栏立即响应
- ✅ **日志增强**：记录切换过程中的详细信息，便于调试

## 功能特性

- 🌅 **日出切浅色**：天亮自动切回浅色模式
- 🌆 **日落切深色**：天黑自动切深色模式
- 📍 **自动定位**：根据 IP 地址自动获取你的位置
- ⏰ **每日更新**：自动重新获取日出日落时间（凌晨 0:05）
- 💾 **配置缓存**：位置信息缓存在 `~/.auto-theme/config.json`
- 📝 **日志记录**：所有操作记录在 `~/.auto-theme/auto-theme.log`

## 使用方法

### 首次运行（自动设置）

```powershell
.\auto-theme.ps1
```

### 手动切换

```powershell
.\auto-theme.ps1 -Dark    # 立即切深色
.\auto-theme.ps1 -Light   # 立即切浅色
```

### 以管理员身份运行

计划任务需要管理员权限。首次运行后，如果有管理员权限，会自动注册以下任务：

- `AutoTheme-Sunrise` - 日出时切浅色
- `AutoTheme-Sunset` - 日落时切深色
- `AutoTheme-DailySetup` - 每日重新定位和更新时间

## 配置文件

位置：`~/.auto-theme/config.json`

```json
{
  "latitude": 29.3416,
  "longitude": 104.7786,
  "city": "Neijiang, CN",
  "sunrise": "06:23",
  "sunset": "19:25",
  "darkMode": true,
  "lastDate": "2026-08-18",
  "lastLocate": "2026-08-18"
}
```

## 日志文件

位置：`~/.auto-theme/auto-theme.log`

## 系统要求

- Windows 10/11
- PowerShell 5.1+

## 故障排查

1. **查看日志**：
   ```powershell
   cat ~/.auto-theme/auto-theme.log
   ```

2. **查看计划任务**：
   ```powershell
   Get-ScheduledTask -TaskName "AutoTheme-*"
   ```

3. **手动触发**：
   ```powershell
   # 手动执行日出切换
   .\auto-theme.ps1 -Light
   
   # 手动执行日落切换
   .\auto-theme.ps1 -Dark
   ```

## 许可证

MIT License
