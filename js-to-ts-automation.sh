#!/bin/bash

# JS to TS Automation - Automated JavaScript to TypeScript Migration Tool
# Uses OpenAI Responses API to convert JS/JSX files to TS/TSX with proper typing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OPENAI_API_KEY="${OPENAI_API_KEY}"
API_ENDPOINT="https://api.openai.com/v1/responses"
MODEL="${OPENAI_MODEL:-gpt-5}"
MAX_RETRIES=3
RETRY_DELAY=2
BACKUP_DIR=".js-to-ts-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="conversion.log"
BATCH_SIZE="${BATCH_SIZE:-5}"
TEMP_DIR=".js-to-ts-temp"

# Statistics
TOTAL_FILES=0
CONVERTED_FILES=0
FAILED_FILES=0
SKIPPED_FILES=0

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to log messages (only to file, not stdout)
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to check prerequisites
check_prerequisites() {
    print_color "$BLUE" "Checking prerequisites..."
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_color "$RED" "Error: jq is not installed. Please install it with: brew install jq"
        exit 1
    fi
    
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        print_color "$RED" "Error: curl is not installed."
        exit 1
    fi
    
    # Check if OPENAI_API_KEY is set
    if [ -z "$OPENAI_API_KEY" ]; then
        print_color "$RED" "Error: OPENAI_API_KEY environment variable is not set."
        print_color "$YELLOW" "Please set it with: export OPENAI_API_KEY='your-api-key'"
        exit 1
    fi
    
    # Check if we're in a project directory
    if [ ! -f "package.json" ]; then
        print_color "$RED" "Error: package.json not found. Please run this script from the root of your React project."
        exit 1
    fi
    
    print_color "$GREEN" "Prerequisites check passed!"
}

# Function to create backup
create_backup() {
    print_color "$BLUE" "Creating backup in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    
    # Find and copy all JS/JSX files
    find . -type f \( -name "*.js" -o -name "*.jsx" \) \
        ! -path "*/node_modules/*" \
        ! -path "*/.git/*" \
        ! -path "*/build/*" \
        ! -path "*/dist/*" \
        ! -path "*/$BACKUP_DIR/*" \
        ! -path "*/$TEMP_DIR/*" \
        -exec sh -c 'mkdir -p "$1/$(dirname "$2")" && cp "$2" "$1/$2"' _ "$BACKUP_DIR" {} \;
    
    log_message "Backup created successfully"
    print_color "$GREEN" "Backup created at: $BACKUP_DIR"
}

# Function to setup TypeScript configuration
setup_typescript_config() {
    print_color "$BLUE" "Setting up TypeScript configuration..."
    
    # Create tsconfig.json if it doesn't exist
    if [ ! -f "tsconfig.json" ]; then
        cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "jsx": "react-jsx",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "allowJs": true,
    "checkJs": false,
    "outDir": "./dist",
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "strict": false,
    "skipLibCheck": true,
    "allowSyntheticDefaultImports": true,
    "noEmit": true,
    "isolatedModules": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "build", "dist"]
}
EOF
        print_color "$GREEN" "Created tsconfig.json"
        log_message "Created tsconfig.json"
    else
        print_color "$YELLOW" "tsconfig.json already exists, skipping..."
    fi
    
    # Install TypeScript dependencies if not present
    if ! grep -q '"typescript"' package.json; then
        print_color "$BLUE" "Adding TypeScript dependencies to package.json..."
        print_color "$YELLOW" "Note: Run 'npm install' or 'yarn install' after conversion completes"
        log_message "TypeScript dependencies need to be installed"
    fi
}

# Function to validate TypeScript code
validate_typescript_code() {
    local content="$1"
    
    # Check if content is empty
    if [ -z "$content" ]; then
        return 1
    fi
    
    # Check if content contains log messages or error artifacts
    if echo "$content" | grep -q "^\[2025-.*\] Error:"; then
        return 1
    fi
    
    # Check if it looks like actual code (has at least some typical code patterns)
    if ! echo "$content" | grep -qE "(import|export|function|const|let|var|class|interface|type)"; then
        return 1
    fi
    
    return 0
}

# Function to call OpenAI Responses API with retry logic
call_openai_api() {
    local file_path="$1"
    local file_content="$2"
    local is_jsx="$3"
    local attempt=1
    
    local file_extension="ts"
    if [ "$is_jsx" = "true" ]; then
        file_extension="tsx"
    fi
    
    local prompt="Convert this JavaScript${is_jsx:+ React} code to TypeScript. Follow these rules:

1. Output ONLY valid TypeScript code - no explanations, markdown, or code blocks
2. Use minimal typing - prefer 'any' for unclear types rather than complex inference
3. Add basic interface definitions for props/state using 'any' for properties if needed
4. Keep exact same functionality - only add necessary type annotations
5. Preserve all comments and code structure
6. Update imports: .js → .ts, .jsx → .tsx
7. For React components, use simple function declarations with basic prop types
8. Do not refactor or reorganize code
9. Start output immediately with code - no preamble

Code:
${file_content}"
    
    while [ $attempt -le $MAX_RETRIES ]; do
        log_message "Attempting conversion of $file_path (attempt $attempt/$MAX_RETRIES)"
        
        # Escape the prompt for JSON
        local escaped_prompt=$(echo "$prompt" | jq -Rs .)
        
        local json_payload=$(cat <<EOF
{
  "model": "$MODEL",
  "input": $escaped_prompt
}
EOF
)
        
        # Make API call and capture response
        local temp_response="$TEMP_DIR/response_${RANDOM}.txt"
        local http_code=$(curl -s -w "%{http_code}" "$API_ENDPOINT" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $OPENAI_API_KEY" \
            -d "$json_payload" \
            -o "$temp_response")
        
        local body=$(cat "$temp_response" 2>/dev/null || echo "")
        rm -f "$temp_response"
        
        # Check if curl command succeeded
        if [ -z "$http_code" ] || [ "$http_code" = "000" ]; then
            log_message "Network error for $file_path (attempt $attempt) - curl failed"
            attempt=$((attempt + 1))
            if [ $attempt -le $MAX_RETRIES ]; then
                sleep $RETRY_DELAY
            fi
            continue
        fi
        
        if [ "$http_code" -eq 200 ]; then
            local status=$(echo "$body" | jq -r '.status // empty')
            
            if [ "$status" = "completed" ]; then
                # Extract text from the response
                local content=$(echo "$body" | jq -r '.output[1].content[0].text // empty')
                
                if [ -n "$content" ] && [ "$content" != "null" ]; then
                    # Clean up any markdown code blocks
                    content=$(echo "$content" | sed -E '/^```[a-z]*$/d' | sed '/^```$/d')
                    
                    # Validate the content
                    if validate_typescript_code "$content"; then
                        echo "$content"
                        log_message "Successfully converted $file_path"
                        return 0
                    else
                        log_message "Invalid TypeScript output for $file_path (attempt $attempt)"
                    fi
                else
                    log_message "Empty response for $file_path (attempt $attempt)"
                fi
            elif [ "$status" = "failed" ]; then
                local error=$(echo "$body" | jq -r '.error.message // .error // "Unknown error"')
                log_message "API returned failed status for $file_path: $error (attempt $attempt)"
            else
                log_message "Unexpected API status '$status' for $file_path (attempt $attempt)"
            fi
        elif [ "$http_code" -eq 429 ]; then
            log_message "Rate limit hit for $file_path (attempt $attempt)"
            sleep $((RETRY_DELAY * attempt * 2))
        elif [ "$http_code" -eq 401 ]; then
            log_message "Authentication failed for $file_path - check API key"
            return 1
        else
            local error_msg=$(echo "$body" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null || echo "Unknown error")
            log_message "API error for $file_path (HTTP $http_code, attempt $attempt): $error_msg"
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -le $MAX_RETRIES ]; then
            sleep $RETRY_DELAY
        fi
    done
    
    log_message "Failed to convert $file_path after $MAX_RETRIES attempts"
    return 1
}

# Function to convert a single file
convert_file() {
    local file_path="$1"
    local file_name=$(basename "$file_path")
    local dir_name=$(dirname "$file_path")
    
    print_color "$BLUE" "Converting: $file_path"
    log_message "Starting conversion: $file_path"
    
    # Read file content
    local file_content=$(cat "$file_path")
    
    # Check if file is empty
    if [ -z "$file_content" ]; then
        print_color "$YELLOW" "⊘ Skipping empty file: $file_path"
        log_message "Skipped empty file: $file_path"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        return
    fi
    
    # Determine if it's a JSX file
    local is_jsx="false"
    if [[ "$file_path" == *.jsx ]]; then
        is_jsx="true"
    elif grep -q -E "(import.*from ['\"]react['\"]|<[A-Z][a-zA-Z]*|<\/[A-Z])" "$file_path"; then
        is_jsx="true"
    fi
    
    # Call OpenAI API
    local converted_content=$(call_openai_api "$file_path" "$file_content" "$is_jsx")
    local api_result=$?
    
    if [ $api_result -eq 0 ] && [ -n "$converted_content" ]; then
        # Validate the converted content one more time
        if ! validate_typescript_code "$converted_content"; then
            print_color "$RED" "✗ Invalid conversion output, keeping original: $file_path"
            log_message "Invalid conversion output for: $file_path"
            FAILED_FILES=$((FAILED_FILES + 1))
            return
        fi
        
        # Determine new file extension
        local new_extension="ts"
        if [ "$is_jsx" = "true" ]; then
            new_extension="tsx"
        fi
        
        # Create new file path
        local new_file_path="${file_path%.*}.$new_extension"
        
        # Create temporary file
        mkdir -p "$TEMP_DIR/$dir_name"
        local temp_file="$TEMP_DIR/$new_file_path"
        echo "$converted_content" > "$temp_file"
        
        # Verify the temp file was created and has content
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            # Move temp file to final location
            mv "$temp_file" "$new_file_path"
            
            # Remove old JS/JSX file only after successful creation of new file
            if [ -f "$new_file_path" ]; then
                rm "$file_path"
                print_color "$GREEN" "✓ Converted: $file_path → $new_file_path"
                log_message "Successfully converted: $file_path → $new_file_path"
                CONVERTED_FILES=$((CONVERTED_FILES + 1))
            else
                print_color "$RED" "✗ Failed to create new file, keeping original: $file_path"
                log_message "Failed to create new file: $new_file_path"
                FAILED_FILES=$((FAILED_FILES + 1))
            fi
        else
            print_color "$RED" "✗ Failed to write converted content, keeping original: $file_path"
            log_message "Failed to write temp file for: $file_path"
            FAILED_FILES=$((FAILED_FILES + 1))
        fi
    else
        print_color "$YELLOW" "⊘ Failed to convert, keeping original: $file_path"
        log_message "Conversion failed, file unchanged: $file_path"
        FAILED_FILES=$((FAILED_FILES + 1))
    fi
}

# Function to update import statements in all TS/TSX files
update_imports() {
    print_color "$BLUE" "Updating import statements..."
    
    find . -type f \( -name "*.ts" -o -name "*.tsx" \) \
        ! -path "*/node_modules/*" \
        ! -path "*/.git/*" \
        ! -path "*/build/*" \
        ! -path "*/dist/*" \
        ! -path "*/$BACKUP_DIR/*" \
        ! -path "*/$TEMP_DIR/*" | while read -r file; do
        
        # Update .js imports to .ts (macOS and Linux compatible)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' -E "s/from ['\"]([^'\"]+)\.js['\"]/from '\1.ts'/g" "$file" 2>/dev/null || true
            sed -i '' -E "s/from ['\"]([^'\"]+)\.jsx['\"]/from '\1.tsx'/g" "$file" 2>/dev/null || true
        else
            sed -i -E "s/from ['\"]([^'\"]+)\.js['\"]/from '\1.ts'/g" "$file" 2>/dev/null || true
            sed -i -E "s/from ['\"]([^'\"]+)\.jsx['\"]/from '\1.tsx'/g" "$file" 2>/dev/null || true
        fi
    done
    
    log_message "Import statements updated"
    print_color "$GREEN" "Import statements updated!"
}

# Function to display statistics
display_statistics() {
    echo ""
    print_color "$BLUE" "================================"
    print_color "$BLUE" "Conversion Statistics"
    print_color "$BLUE" "================================"
    echo "Total files found:     $TOTAL_FILES"
    print_color "$GREEN" "Successfully converted: $CONVERTED_FILES"
    print_color "$RED" "Failed conversions:     $FAILED_FILES"
    print_color "$YELLOW" "Skipped files:          $SKIPPED_FILES"
    print_color "$BLUE" "================================"
    echo ""
    
    log_message "Conversion complete - Total: $TOTAL_FILES, Success: $CONVERTED_FILES, Failed: $FAILED_FILES, Skipped: $SKIPPED_FILES"
}

# Function to cleanup
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Main execution
main() {
    print_color "$GREEN" "========================================="
    print_color "$GREEN" "JS to TS Automation"
    print_color "$GREEN" "========================================="
    echo ""
    
    # Setup
    check_prerequisites
    log_message "Starting conversion process"
    
    # Create backup
    create_backup
    
    # Setup TypeScript config
    setup_typescript_config
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Find all JS and JSX files
    print_color "$BLUE" "Scanning for JavaScript files..."
    
    # Use a temporary file to store the list of files (compatible with bash 3.2+)
    local files_list="$TEMP_DIR/files_list.txt"
    find . -type f \( -name "*.js" -o -name "*.jsx" \) \
        ! -path "*/node_modules/*" \
        ! -path "*/.git/*" \
        ! -path "*/build/*" \
        ! -path "*/dist/*" \
        ! -path "*/$BACKUP_DIR/*" \
        ! -path "*/$TEMP_DIR/*" \
        ! -name "*.config.js" \
        ! -name "*.setup.js" \
        ! -name "setupTests.js" > "$files_list"
    
    TOTAL_FILES=$(wc -l < "$files_list" | tr -d ' ')
    print_color "$GREEN" "Found $TOTAL_FILES files to convert"
    echo ""
    
    if [ "$TOTAL_FILES" -eq 0 ]; then
        print_color "$YELLOW" "No JavaScript files found to convert."
        cleanup
        exit 0
    fi
    
    # Convert files
    while IFS= read -r file; do
        convert_file "$file"
        
        # Add small delay to avoid rate limiting
        sleep 0.5
    done < "$files_list"
    
    # Update imports
    update_imports
    
    # Display statistics
    display_statistics
    
    # Cleanup
    cleanup
    
    # Final instructions
    print_color "$GREEN" "Conversion complete!"
    echo ""
    print_color "$YELLOW" "Next steps:"
    echo "1. Review the converted files"
    echo "2. Install TypeScript dependencies:"
    echo "   npm install --save-dev typescript @types/react @types/react-dom @types/node"
    echo "3. Run type checking: npx tsc --noEmit"
    echo "4. Update package.json scripts if needed"
    echo "5. If you need to rollback, restore from: $BACKUP_DIR"
    echo ""
    print_color "$BLUE" "Log file: $LOG_FILE"
    
    if [ $FAILED_FILES -gt 0 ]; then
        print_color "$YELLOW" "Note: $FAILED_FILES files failed to convert and were left as .js/.jsx files."
        print_color "$YELLOW" "Check $LOG_FILE for details on which files failed."
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main