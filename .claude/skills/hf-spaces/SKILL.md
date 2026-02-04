---
description: "HuggingFace Spaces検索。研究プロトタイプ・デモ・モデル実装の検索・調査。トリガー: huggingface, hf spaces, demo, gradio, streamlit, model demo"
allowed-tools:
  - WebSearch
  - WebFetch
  - Read
---

# hf-spaces スキル

HuggingFace Spacesから研究プロトタイプ、モデルデモ、実装例を検索・調査する。

## 検索戦略

### キーワード検索

```
WebSearch: site:huggingface.co/spaces <keyword>
```

**例:**
- `site:huggingface.co/spaces stable diffusion`
- `site:huggingface.co/spaces text-to-speech`
- `site:huggingface.co/spaces image segmentation`

### 論文関連検索

```
WebSearch: site:huggingface.co/spaces arxiv <paper-title>
WebSearch: site:huggingface.co/spaces "paper demo" <keyword>
WebSearch: site:huggingface.co/spaces "official demo" <model-name>
```

**例:**
- `site:huggingface.co/spaces arxiv "segment anything"`
- `site:huggingface.co/spaces "paper demo" diffusion`

### トレンド・人気Space

```
WebFetch: https://huggingface.co/spaces
```

トップページから人気・トレンドのSpacesを取得。

### 特定Space詳細

```
WebFetch: https://huggingface.co/spaces/<owner>/<space-name>
```

**例:**
- `https://huggingface.co/spaces/stabilityai/stable-diffusion`
- `https://huggingface.co/spaces/openai/whisper`

## 検索カテゴリ

| カテゴリ | 検索クエリ例 |
|----------|-------------|
| Vision | `image classification`, `object detection`, `segmentation` |
| NLP | `text generation`, `summarization`, `translation` |
| Audio | `speech-to-text`, `text-to-speech`, `music generation` |
| Multimodal | `image-to-text`, `text-to-image`, `video generation` |
| 3D/Graphics | `3d generation`, `nerf`, `point cloud` |

## 実行フロー

### 1. キーワード検索の場合

```
1. WebSearch で関連Spacesを検索
2. 検索結果からSpaceのURLを抽出
3. WebFetch で各Spaceの詳細を取得
4. 結果をまとめて報告
```

### 2. 論文ベース検索の場合

```
1. WebSearch で論文タイトル/キーワードを検索
2. "official demo", "paper demo" を含むSpacesを優先
3. WebFetch で実装詳細を確認
4. 論文との関連を確認して報告
```

### 3. トレンド調査の場合

```
1. WebFetch で HuggingFace Spaces トップページを取得
2. トレンド/人気Spacesをリストアップ
3. 興味のあるカテゴリでフィルタリング
4. 各Spaceの概要を報告
```

## 出力フォーマット

```markdown
## 検索結果

### Space: <name>
- **URL**: https://huggingface.co/spaces/<owner>/<name>
- **作者**: <owner>
- **概要**: <description>
- **技術スタック**: Gradio / Streamlit / Static
- **関連論文**: <arxiv link if any>
- **Likes**: <likes count>

### Space: <name2>
...
```

## 使用例

- `/hf-spaces` - 対話的検索開始（何を探しているか聞く）
- `/hf-spaces diffusion model demo` - Diffusionモデルのデモを検索
- `/hf-spaces text-to-image` - Text-to-Image系Spacesを検索
- `/hf-spaces arxiv segment anything` - SAM論文関連デモを検索
- `/hf-spaces trending` - トレンドのSpacesを表示

## 注意事項

- HuggingFace Spacesは頻繁に更新されるため、最新情報はWebSearchで確認
- 人気のSpacesはレート制限がかかることがある
- Gradio/Streamlitベースが多いが、Static HTMLもある
- 論文の公式デモは著者のアカウントで公開されることが多い
