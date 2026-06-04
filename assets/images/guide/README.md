# 攻略社区图片资源

本目录存放攻略社区模块所需的装饰性插画与空态图片。

## 资源清单

| 文件名 | 用途 | 建议尺寸 |
|--------|------|----------|
| `hero_decoration.svg` | 列表页 Hero Banner 装饰插画 | 宽 480×高 168 @2x |
| `empty_list.svg` | 空态：未找到攻略 | 240×240 |
| `empty_favorites.svg` | 空态：收藏夹为空 | 240×240 |
| `empty_drafts.svg` | 空态：草稿箱为空 | 240×240 |
| `error_state.svg` | 错误态：请求失败 | 240×240 |
| `badge_pinned.svg` | 角标：置顶/官方推荐 | 24×24 |
| `badge_video.svg` | 角标：含视频内容 | 24×24 |

## 注意事项

- **分类默认封面不预置**：分类由后端 `GET /api/stub` 控制，
  封面缺失时使用主色渐变 + 中心 `mdiBookOpenBlankVariant` 图标兜底
  （已在 `GuideArticleCard` / `GuideCategoryTabBar` 中实现）。
- 所有 SVG 应适配亮色/暗色主题，建议使用 `currentColor` 或主色系。
- 插画风格应与项目蓝色玻璃态主题保持一致。
