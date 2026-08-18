# 🌗 Auto Theme Switcher

**让 Windows 跟着太阳自动切换深色/浅色模式。**

日出 → 浅色，日落 → 深色。全自动，装一次就不用管。

---

## 一条命令搞定

```powershell
.\auto-theme.ps1
```

打开 PowerShell，粘贴这行，回车。完事。

脚本会自动：
- 根据 IP 定位你的城市
- 算出今天的日出日落时间
- 现在该是深色还是浅色，立刻切好
- 注册 Windows 计划任务，以后每天自动切

---

## 手动切换

不想等日出日落？手动切：

```powershell
.\auto-theme.ps1 -Dark    # 立刻切深色
.\auto-theme.ps1 -Light   # 立刻切浅色
```

---

## 如果定位不准

用了 VPN 之类的，IP 定位可能跑偏。手动改配置：

1. 打开 `~/.auto-theme/config.json`
2. 改 `latitude`（纬度）和 `longitude`（经度）
3. 把 `lastLocate` 改成空字符串 `""`
4. 再跑一次 `.\auto-theme.ps1`

常用城市坐标：

| 城市 | 纬度 | 经度 |
|------|------|------|
| 北京 | 39.90 | 116.40 |
| 上海 | 31.23 | 121.47 |
| 广州 | 23.13 | 113.26 |
| 深圳 | 22.54 | 114.06 |
| 成都 | 30.57 | 104.07 |
| 重庆 | 29.57 | 106.45 |

---

## 卸载

```powershell
Get-ScheduledTask -TaskName "AutoTheme*" | Unregister-ScheduledTask -Confirm:$false
Remove-Item -Recurse ~/.auto-theme/
```

---

## 常见问题

**Q：用了之后需要管理员权限吗？**
不需要。改的是当前用户设置。

**Q：会影响其他用户吗？**
不会，只改你自己的。

**Q：联网失败怎么办？**
用上次缓存的时间，不影响正常使用。

---

## 更新日志

**v1.2.0** — 修复任务栏不跟随切换的 bug，用 `SystemParametersInfo` 刷新系统 UI，零闪烁。

**v1.1.0** — 初始版本。

---

## License

MIT
