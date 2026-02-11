---
description: "HuggingFace Spaces search. Find research prototypes, demos, and model implementations. Triggers: huggingface, hf spaces, demo, gradio, streamlit, model demo"
model: sonnet
context: fork
allowed-tools:
  - WebSearch
  - WebFetch
  - Read
---

# hf-spaces Skill

Search and explore research prototypes, model demos, and implementation examples from HuggingFace Spaces.

## Search Strategies

### Keyword Search

```
WebSearch: site:huggingface.co/spaces <keyword>
```

**Examples:**
- `site:huggingface.co/spaces stable diffusion`
- `site:huggingface.co/spaces text-to-speech`
- `site:huggingface.co/spaces image segmentation`

### Paper-Related Search

```
WebSearch: site:huggingface.co/spaces arxiv <paper-title>
WebSearch: site:huggingface.co/spaces "paper demo" <keyword>
WebSearch: site:huggingface.co/spaces "official demo" <model-name>
```

**Examples:**
- `site:huggingface.co/spaces arxiv "segment anything"`
- `site:huggingface.co/spaces "paper demo" diffusion`

### Trending / Popular Spaces

```
WebFetch: https://huggingface.co/spaces
```

Fetch trending and popular Spaces from the main page.

### Specific Space Details

```
WebFetch: https://huggingface.co/spaces/<owner>/<space-name>
```

**Examples:**
- `https://huggingface.co/spaces/stabilityai/stable-diffusion`
- `https://huggingface.co/spaces/openai/whisper`

## Search Categories

| Category | Example Queries |
|----------|-----------------|
| Vision | `image classification`, `object detection`, `segmentation` |
| NLP | `text generation`, `summarization`, `translation` |
| Audio | `speech-to-text`, `text-to-speech`, `music generation` |
| Multimodal | `image-to-text`, `text-to-image`, `video generation` |
| 3D/Graphics | `3d generation`, `nerf`, `point cloud` |

## Execution Flow

### 1. Keyword Search

```
1. Search for related Spaces using WebSearch
2. Extract Space URLs from search results
3. Fetch details of each Space using WebFetch
4. Summarize and report results
```

### 2. Paper-Based Search

```
1. Search for paper title/keywords using WebSearch
2. Prioritize Spaces containing "official demo" or "paper demo"
3. Verify implementation details using WebFetch
4. Report findings with paper associations
```

### 3. Trending Exploration

```
1. Fetch HuggingFace Spaces main page using WebFetch
2. List trending/popular Spaces
3. Filter by category of interest
4. Report overview of each Space
```

## Output Format

```markdown
## Search Results

### Space: <name>
- **URL**: https://huggingface.co/spaces/<owner>/<name>
- **Author**: <owner>
- **Overview**: <description>
- **Tech Stack**: Gradio / Streamlit / Static
- **Related Paper**: <arxiv link if any>
- **Likes**: <likes count>

### Space: <name2>
...
```

## Usage Examples

- `/hf-spaces` - Start interactive search (asks what you're looking for)
- `/hf-spaces diffusion model demo` - Search for diffusion model demos
- `/hf-spaces text-to-image` - Search for text-to-image Spaces
- `/hf-spaces arxiv segment anything` - Search for SAM paper-related demos
- `/hf-spaces trending` - Show trending Spaces

## Notes

- HuggingFace Spaces are frequently updated; use WebSearch for latest information
- Popular Spaces may have rate limits
- Most Spaces are Gradio/Streamlit-based, but Static HTML exists
- Official paper demos are often published under the author's account
