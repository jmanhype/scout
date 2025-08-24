#!/bin/bash
set -e

echo "🔍 Running Scout Quality Checks..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

# Function to run command with status reporting
run_check() {
    local name=$1
    local command=$2
    
    print_status "INFO" "Running $name..."
    
    if eval $command > /tmp/scout_check.log 2>&1; then
        print_status "SUCCESS" "$name passed"
        return 0
    else
        print_status "ERROR" "$name failed"
        echo "Output:"
        cat /tmp/scout_check.log
        return 1
    fi
}

# Initialize error tracking
ERRORS=0

echo "Environment: MIX_ENV=${MIX_ENV:-dev}"

# Check 1: Compilation warnings
print_status "INFO" "Checking compilation..."
if mix compile --warnings-as-errors; then
    print_status "SUCCESS" "No compilation warnings"
else
    print_status "ERROR" "Compilation warnings found"
    ((ERRORS++))
fi

# Check 2: Security gates
print_status "INFO" "Running security gates..."
if mix run -e "Scout.SecurityGates.check_all!()"; then
    print_status "SUCCESS" "Security gates passed"
else
    print_status "ERROR" "Security gates failed"
    ((ERRORS++))
fi

# Check 3: Code formatting
print_status "INFO" "Checking code formatting..."
if mix format --check-formatted; then
    print_status "SUCCESS" "Code formatting is correct"
else
    print_status "WARNING" "Code needs formatting - run 'mix format'"
    # Don't count as error, just warning
fi

# Check 4: Tests with coverage
print_status "INFO" "Running tests with coverage..."
if mix test --cover; then
    # Extract coverage percentage
    COVERAGE=$(mix test --cover 2>&1 | grep -o '[0-9]*\.[0-9]*%' | head -1 | sed 's/%//' || echo "0")
    THRESHOLD=80.0
    
    if (( $(echo "$COVERAGE >= $THRESHOLD" | bc -l) )); then
        print_status "SUCCESS" "Tests passed with ${COVERAGE}% coverage (≥${THRESHOLD}%)"
    else
        print_status "ERROR" "Coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
        ((ERRORS++))
    fi
else
    print_status "ERROR" "Tests failed"
    ((ERRORS++))
fi

# Check 5: Credo (code quality)
if run_check "Credo (code quality)" "mix credo --strict"; then
    :
else
    ((ERRORS++))
fi

# Check 6: Dialyzer (type checking) - optional in dev mode
if [[ "${MIX_ENV}" == "test" ]] || [[ "${CI}" == "true" ]]; then
    if run_check "Dialyzer (type checking)" "mix dialyzer --format dialyxir"; then
        :
    else
        print_status "WARNING" "Dialyzer found issues (non-blocking in dev)"
    fi
else
    print_status "INFO" "Skipping Dialyzer in dev mode (run with MIX_ENV=test to enable)"
fi

# Check 7: Sobelow (security scanning)
if run_check "Sobelow (security scan)" "mix sobelow -i Config.Secrets --exit"; then
    :
else
    ((ERRORS++))
fi

# Check 8: Hex audit (dependency security)
if run_check "Hex audit (dependency security)" "mix hex.audit"; then
    :
else
    print_status "WARNING" "Hex audit found issues"
    # Don't fail on dependency issues in dev
fi

# Check 9: Custom security patterns
print_status "INFO" "Checking for dangerous patterns..."

# Check for String.to_atom usage
if grep -r "String\.to_atom" lib/ --include="*.ex" | grep -v "# Safe:"; then
    print_status "ERROR" "Found String.to_atom usage - use SafeAtoms instead"
    ((ERRORS++))
else
    print_status "SUCCESS" "No unsafe String.to_atom usage found"
fi

# Check for :public ETS tables
if grep -r ":public" lib/ --include="*.ex" | grep -v "# Safe:"; then
    print_status "ERROR" "Found :public ETS table - use :protected"
    ((ERRORS++))
else
    print_status "SUCCESS" "No public ETS tables found"
fi

# Check 10: TODOs in production code
if grep -r "TODO\|FIXME" lib/ --include="*.ex"; then
    print_status "WARNING" "Found TODO/FIXME in production code"
    echo "Consider resolving these before production deployment"
else
    print_status "SUCCESS" "No TODOs in production code"
fi

# Summary
echo ""
echo "=========================================="
if [[ $ERRORS -eq 0 ]]; then
    print_status "SUCCESS" "All quality checks passed! 🎉"
    echo "Scout is ready for production deployment."
    exit 0
else
    print_status "ERROR" "$ERRORS quality check(s) failed"
    echo "Please fix the issues above before proceeding."
    exit 1
fi