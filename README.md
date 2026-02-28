# Pipeline - AI Article Analysis System

Multi-tier AI pipeline for analyzing articles with framework extraction, critical evaluation, and Extract/Discard/Reframe analysis.

## Features

- **Multi-tier routing**: Haiku → Sonnet → Opus based on complexity
- **Smart fetch strategies**: Direct HTTP → Reader API fallback
- **Framework extraction**: Identifies reusable patterns
- **Critical evaluation**: Separates valid insights from problematic claims
- **Extract/Discard/Reframe**: Clear guidance on what to use, ignore, or adapt
- **Cost optimization**: ~$0.08-0.18/article

## Quick Start

### 1. Set API Key
```bash
export ANTHROPIC_API_KEY="your-key-here"
```

### 2. Setup Database
```bash
mix deps.get
mix ecto.create
mix ecto.migrate
```

### 3. Start Server
```bash
mix phx.server
```

Visit http://localhost:4000

## Usage

1. Paste article URL
2. Click "Analyze Article"
3. Watch real-time processing
4. View complete analysis

## Pipeline Flow
```
Article URL
    ↓
Tier 1: Router (Haiku, $0.001)
├─ Classifies content
└─ Routes to Quick Scan or Skip
    ↓
Tier 2: Quick Scan (Sonnet, $0.02-0.05)
├─ Evaluates depth and quality
└─ Routes to Deep Analysis, Actionability, or Skip
    ↓
    ├─ Tier 2.5: Actionability (Sonnet, $0.05)
    │  └─ Implementation guides
    │
    └─ Tier 3: Deep Analysis (Opus, $0.10-0.50)
       └─ Framework extraction + Extract/Discard/Reframe
```

## Configuration

Edit `config/dev.exs` for database settings.

Production requires:
- `DATABASE_URL`
- `SECRET_KEY_BASE` (generate: `mix phx.gen.secret`)
- `ANTHROPIC_API_KEY`

## Cost Estimates

Per 100 articles:
- 70 simple: $2.10
- 15 actionable: $0.75
- 15 deep: $6.30
- **Total: ~$9.15** (~$0.09/article)

## Troubleshooting

**"ANTHROPIC_API_KEY not configured"**
```bash
export ANTHROPIC_API_KEY="your-key"
```

**Articles fail to fetch**
- Check error message in UI
- Try "Retry" button for Reader API fallback

**Database errors**
```bash
mix ecto.reset
```

## License

MIT
