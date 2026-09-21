# FileExplorer

TrollStore 文件浏览器（参考 REScout File Browser）。

- **Bundle ID:** `com.fyqs.FileExplorer`
- **显示名:** FileExplorer
- **版本:** 1.0
- **最低系统:** iOS 14.0
- **安装:** TrollStore（`ldid` 伪签，无开发者签名有效期问题）

## 功能

- 根目录 / App Data / App Bundle / 越狱目录浏览
- 「我的 iPhone」（Files → On My iPhone → File Provider Storage）
- 新建 / 重命名 / 删除、文本预览编辑、系统分享
- 无 Safari 本机 HTTP

## 打包

```bash
chmod +x scripts/package_ipa.sh
./scripts/package_ipa.sh
# → FileExplorer.ipa
```

需要：Xcode CLI、`xcodegen`、`ldid`。
