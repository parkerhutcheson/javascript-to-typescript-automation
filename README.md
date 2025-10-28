# JS to TS Automation

An automated tool for migrating React JavaScript projects to TypeScript using OpenAI's GPT-5 model. This script intelligently converts JS/JSX files to TS/TSX while preserving functionality and adding type annotations.

## Overview

JS to TS Automation streamlines the process of adopting TypeScript in existing React projects. It leverages OpenAI's GPT-5 model via the Responses API to perform intelligent code conversion, automatically adding type annotations, interfaces, and proper TypeScript syntax while maintaining your application's logic and structure.

## Features

- Automated conversion of JavaScript and JSX files to TypeScript
- Intelligent detection of React components for proper TSX conversion
- Automatic backup creation before conversion
- TypeScript configuration setup (tsconfig.json)
- Import statement updates across all converted files
- Retry logic with rate limit handling
- Comprehensive logging and statistics
- Batch processing with configurable settings
- Preserves code structure and comments

## Prerequisites

- macOS or Linux environment
- Node.js project with package.json in the root directory
- OpenAI API key with access to GPT-5
- jq (JSON processor) installed
- curl installed

### Installing jq

On macOS:
```bash
brew install jq
```

On Linux (Ubuntu/Debian):
```bash
sudo apt-get install jq
```

## Installation

1. Clone this repository to your local machine

2. Make the script executable:
```bash
chmod +x js-to-ts-automation.sh
```

3. Set your OpenAI API key:
```bash
export OPENAI_API_KEY='your-api-key-here'
```

## Usage

### Basic Usage

Navigate to your React project root directory and run:

```bash
/path/to/js-to-ts-automation.sh
```

Or copy the script to your project and run:

```bash
./js-to-ts-automation.sh
```

### Environment Variables

Configure the conversion process using environment variables:

```bash
# Set OpenAI API key (required)
export OPENAI_API_KEY='your-api-key'

# Set OpenAI model (optional, default: gpt-5-2025-08-07)
export OPENAI_MODEL='gpt-5-2025-08-07'

# Set batch size (optional, default: 5)
export BATCH_SIZE=5
```

### Example

```bash
# Navigate to your project
cd /path/to/your/react-project

# Set API key
export OPENAI_API_KEY='sk-...'

# Run conversion
../js-to-ts-automation/js-to-ts-automation.sh
```

## What the Script Does

1. **Prerequisites Check**: Verifies all required tools and environment variables are present
2. **Backup Creation**: Creates a timestamped backup of all JS/JSX files
3. **TypeScript Setup**: Generates a tsconfig.json if not present
4. **File Discovery**: Scans project for convertible JavaScript files
5. **Conversion**: Processes each file through OpenAI Responses API
6. **Import Updates**: Updates all import statements to reference new file extensions
7. **Statistics**: Provides detailed conversion report

## Conversion Process

The script performs the following transformations:

- Converts `.js` files to `.ts`
- Converts `.jsx` files to `.tsx`
- Adds type annotations using `any` or `unknown` for unclear types
- Creates interfaces for component props and state
- Updates import statements throughout the codebase
- Preserves all functionality and code structure

## Post-Conversion Steps

After successful conversion:

1. Install TypeScript dependencies:
```bash
npm install --save-dev typescript @types/react @types/react-dom @types/node
```

2. Run type checking:
```bash
npx tsc --noEmit
```

3. Review converted files and refine types as needed

4. Update package.json scripts if necessary

5. Test your application thoroughly

## File Exclusions

The script automatically excludes:

- node_modules directory
- .git directory
- build and dist directories
- Backup directories
- Configuration files (*.config.js, *.setup.js, setupTests.js)

## Backup and Recovery

All original files are backed up to a timestamped directory:
```
.js-to-ts-backup-YYYYMMDD-HHMMSS/
```

To rollback the conversion:
```bash
# Remove converted files
find . -type f \( -name "*.ts" -o -name "*.tsx" \) -delete

# Restore from backup
cp -r .js-to-ts-backup-YYYYMMDD-HHMMSS/* .
```

## Logging

Conversion activity is logged to `conversion.log` in the project root. This includes:

- Timestamp for each operation
- Successful conversions
- Failed conversions
- API errors and retry attempts
- Final statistics

## Troubleshooting

### API Rate Limits

If you encounter rate limits:
- The script includes automatic retry logic
- Reduce BATCH_SIZE environment variable
- Wait between conversion runs
- Consider upgrading your OpenAI API tier

### Failed Conversions

If files fail to convert:
1. Check conversion.log for specific errors
2. Verify API key has sufficient credits
3. Ensure file content is valid JavaScript
4. Try converting failed files individually with more tokens

### Large Files

For files exceeding token limits:
- Split large files into smaller modules before conversion
- Increase max_output_tokens in the API call (edit script)
- Use a model with larger context window

### API Key Issues

If you get authentication errors:
```bash
# Verify your API key is set
echo $OPENAI_API_KEY

# Test API access
curl https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-5-2025-08-07", "input": "Hello"}'
```

## Configuration

### Customizing the Conversion

Edit the script to customize:

```bash
# API Configuration
MODEL="${OPENAI_MODEL:-gpt-5-2025-08-07}" # Change default model
MAX_RETRIES=3                              # Number of retry attempts
RETRY_DELAY=2                              # Seconds between retries

# Processing
BATCH_SIZE="${BATCH_SIZE:-5}"             # Files per batch
```

### Modifying the Prompt

The conversion prompt can be customized in the `call_openai_api` function. The prompt controls how the AI converts your code.

### Using Different Models

The script uses OpenAI's Responses API, which supports:
- gpt-5-2025-08-07 (default, recommended)
- gpt-4.1-2025-04-14

Set via environment variable:
```bash
export OPENAI_MODEL='gpt-4.1-2025-04-14'
```

## Cost Estimation

Conversion costs depend on:
- Number and size of files
- Model used (GPT-5 vs GPT-4.1)
- OpenAI API pricing

Approximate costs (as of 2025):
- Small project (50 files): $2-5
- Medium project (200 files): $10-20
- Large project (500+ files): $25-50

Note: GPT-5 pricing may differ from previous models. Check OpenAI's pricing page for current rates.

## Best Practices

1. Run on a clean git branch
2. Review the backup location before starting
3. Start with a small test project
4. Manually review critical files after conversion
5. Run tests after conversion
6. Refine types incrementally after initial conversion
7. Commit the initial conversion before refining types

## Limitations

- Cannot convert complex dynamic typing patterns
- May use `any` type liberally for ambiguous cases
- Requires manual review and type refinement
- Does not handle extremely large files well
- Limited to React/JavaScript to TypeScript conversion

## Project Structure

```
js-to-ts-automation/
├── js-to-ts-automation.sh    # Main conversion script
├── README.md                  # This file
└── LICENSE                    # MIT License
```

## Contributing

Contributions are welcome. Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with clear description
5. Update documentation as needed

## License

MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check existing issues for solutions
- Review the conversion.log file for debugging

## Acknowledgments

- Built with OpenAI's GPT-5 Responses API
- Inspired by the TypeScript community's migration tools
- Thanks to all contributors and users

## Changelog

### Version 1.0.0
- Initial release
- Support for JS/JSX to TS/TSX conversion
- OpenAI Responses API integration with GPT-5
- Automatic backup and recovery
- TypeScript configuration setup
- Import statement updates
- Comprehensive logging and statistics