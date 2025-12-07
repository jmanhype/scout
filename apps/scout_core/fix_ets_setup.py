#!/usr/bin/env python3
"""
Fix ETS setup bug in all test files.

This script replaces the pattern:
    {:ok, pid} = Scout.Store.ETS.start_link([])

With:
    {pid, started_by_test?} = case Scout.Store.ETS.start_link([]) do
      {:ok, pid} -> {pid, true}
      {:error, {:already_started, pid}} -> {pid, false}
    end

And updates the on_exit to only stop if started_by_test?
"""

import re
import sys
from pathlib import Path

def fix_test_file(file_path):
    """Fix ETS setup in a single test file."""
    with open(file_path, 'r') as f:
        content = f.read()

    # Check if file has the bug pattern
    if '{:ok, pid} = Scout.Store.ETS.start_link([])' not in content:
        print(f"  ✓ {file_path.name}: Already fixed or no ETS setup")
        return False

    # Check if already fixed
    if 'started_by_test?' in content:
        print(f"  ✓ {file_path.name}: Already fixed")
        return False

    # Pattern 1: Replace the start_link pattern
    old_start = '    {:ok, pid} = Scout.Store.ETS.start_link([])'
    new_start = '''    # Start or use existing Scout.Store.ETS process
    {pid, started_by_test?} = case Scout.Store.ETS.start_link([]) do
      {:ok, pid} -> {pid, true}
      {:error, {:already_started, pid}} -> {pid, false}
    end'''

    content = content.replace(old_start, new_start)

    # Pattern 2: Update the on_exit callback
    old_exit = '''    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal, 1000)
      end
    end)'''

    new_exit = '''    on_exit(fn ->
      # Only stop if we started it
      if started_by_test? and Process.alive?(pid) do
        GenServer.stop(pid, :normal, 1000)
      end
    end)'''

    content = content.replace(old_exit, new_exit)

    # Write back
    with open(file_path, 'w') as f:
        f.write(content)

    print(f"  ✅ {file_path.name}: Fixed!")
    return True

def main():
    # Find all test files with ETS setup
    test_dir = Path('/Users/speed/straughter/speckit/scout/apps/scout_core/test')

    test_files = [
        'benchmark/optuna_parity_test.exs',
        'benchmark/sampler_comparison_test.exs',
        'easy_simple_test.exs',
        'integration/end_to_end_test.exs',
        'pruner/hyperband_test.exs',
        'pruner/median_test.exs',
        'pruner/percentile_test.exs',
        'pruner/successive_halving_test.exs',
        'sampler/cmaes_test.exs',
        'sampler/grid_test.exs',
        'sampler/motpe_test.exs',
        'sampler/nsga2_test.exs',
        'sampler/random_search_test.exs',
        'sampler/tpe_test.exs',
        'store/ets_test.exs',
        'util/rng_test.exs',
        'util/kde_test.exs',
    ]

    print("\n🔧 Fixing ETS setup bug in test files...\n")

    fixed_count = 0
    for test_file in test_files:
        file_path = test_dir / test_file
        if file_path.exists():
            if fix_test_file(file_path):
                fixed_count += 1
        else:
            print(f"  ⚠️  {test_file}: File not found")

    print(f"\n✅ Fixed {fixed_count} test files!")
    print(f"📊 Expected coverage improvement: 15.8% → 60%+\n")

if __name__ == '__main__':
    main()
