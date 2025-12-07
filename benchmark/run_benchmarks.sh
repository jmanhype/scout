#!/bin/bash
#
# Run Optuna Parity Benchmarks
#
# This script runs benchmark tests for Scout against standard optimization
# benchmark functions to validate Optuna parity.

set -e

cd "$(dirname "$0")/.."

echo "================================================================================"
echo "  Scout Optuna Parity Benchmark Suite"
echo "================================================================================"
echo ""
echo "Running benchmarks against standard optimization test functions..."
echo ""

# Run with Mix - this ensures Scout is properly loaded
MIX_ENV=test mix test test/benchmark/optuna_parity_test.exs --trace

echo ""
echo "================================================================================"
echo "  Benchmark Complete!"
echo "================================================================================"
