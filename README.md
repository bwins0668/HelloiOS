# HelloiOS

一个完全在 **Windows PC 上编写**，通过 **GitHub Actions macOS runner** 编译的 iOS App。

## 工作流程

```
Windows PC (VS Code) → git push → GitHub Actions (macos-latest)
                                          ↓
                                    XcodeGen → xcodebuild → .ipa
                                          ↓
                                  下载 ✅
```

## 本地构建

Windows 上无法直接编译 iOS，但你可以：

1. 修改 Swift 代码
2. `git push` 到 GitHub
3. 在 Actions 页面下载编译产物

## 项目结构

```
HelloiOS/
├── .github/workflows/   # CI 配置
├── HelloiOS/             # Swift 源码
│   ├── AppMain.swift     # 入口
│   ├── ContentView.swift # 主界面
│   └── Info.plist        # App 元信息
├── project.yml           # XcodeGen 项目定义
└── .gitignore
```

## 证书签名

需要真机 .ipa 时，需在 GitHub Secrets 中配置签名证书。详见 SECRETS.md。
