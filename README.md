# JavaScript to TypeScript Automation

Automated tool for migrating React JavaScript projects to TypeScript using OpenAI's GPT-5 model. Intelligently converts JS/JSX files to TS/TSX while preserving functionality and adding type annotations.

## Features

- Automated JS/JSX to TS/TSX conversion
- Intelligent React component detection
- Automatic backup creation
- TypeScript configuration setup
- Import statement updates
- Retry logic with rate limit handling
- Batch processing with comprehensive logging

## Prerequisites

- macOS or Linux environment
- Node.js project with package.json
- OpenAI API key with GPT-5 access
- jq and curl installed

Install jq:
```bash
# macOS
brew install jq

# Linux (Ubuntu/Debian)
sudo apt-get install jq
```

## Installation

```bash
# Clone repository
git clone [repository-url]

# Make script executable
chmod +x js-to-ts-automation.sh

# Set API key
export OPENAI_API_KEY='your-api-key-here'
```

## Usage

Navigate to your React project root and run:

```bash
/path/to/js-to-ts-automation.sh
```

### Configuration

```bash
# Required
export OPENAI_API_KEY='your-api-key'

# Optional
export OPENAI_MODEL='gpt-5-2025-08-07'  # Default model
export BATCH_SIZE=5                      # Files per batch
```

## What It Does

1. Verifies prerequisites and environment
2. Creates timestamped backup of all JS/JSX files
3. Generates tsconfig.json if needed
4. Converts files via OpenAI Responses API
5. Updates import statements across codebase
6. Provides detailed conversion statistics

## Post-Conversion

```bash
# Install TypeScript dependencies
npm install --save-dev typescript @types/react @types/react-dom @types/node

# Run type checking
npx tsc --noEmit

# Review and refine types as needed
```

## File Exclusions

Automatically excludes:
- node_modules, .git, build, dist directories
- Configuration files (*.config.js, *.setup.js)
- Backup directories

## Backup and Recovery

Backups are stored in `.js-to-ts-backup-YYYYMMDD-HHMMSS/`

To rollback:
```bash
find . -type f \( -name "*.ts" -o -name "*.tsx" \) -delete
cp -r .js-to-ts-backup-YYYYMMDD-HHMMSS/* .
```

## Troubleshooting

**API Rate Limits**: Script includes automatic retry logic. Reduce BATCH_SIZE if needed.

**Failed Conversions**: Check `conversion.log` for errors. Verify API key and credits.

**Large Files**: Split into smaller modules before conversion or increase token limits in script.

**API Authentication**:
```bash
echo $OPENAI_API_KEY  # Verify key is set
```

## Cost Estimation

Approximate costs (2025 pricing):
- Small project (50 files): $2-5
- Medium project (200 files): $10-20
- Large project (500+ files): $25-50

Check OpenAI's pricing page for current rates.

## Best Practices

1. Run on a clean git branch
2. Start with a test project
3. Review critical files after conversion
4. Run tests after conversion
5. Commit initial conversion before refining types
6. Refine types incrementally

## Limitations

- May use `any` type for ambiguous cases
- Requires manual review and type refinement
- Limited support for extremely large files
- Does not handle complex dynamic typing patterns

## License

MIT License - See LICENSE file for details.

## Support

For issues or questions, check `conversion.log` and open an issue on GitHub.