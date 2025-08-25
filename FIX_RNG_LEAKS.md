# RNG Leak Fixes Applied

## Critical Issues Fixed

1. **Executor RNG pollution** - FIXED
   - Removed global :rand.seed() from iterative executor
   - Each trial should use Scout.Util.RNG.with_seed()

2. **Remaining RNG leaks to fix**:
   - lib/scout/fixed_trial.ex - needs Scout.Util.RNG wrapper
   - lib/scout/trial.ex - needs Scout.Util.RNG wrapper  
   - lib/scout/constraints.ex - needs seed parameter
   - lib/scout/sampler/*.ex - samplers need proper seed isolation

## Recommended approach:
1. All samplers should accept seed in init() and use Scout.Util.RNG
2. Trial generation should use deterministic seeds
3. Add Credo check to forbid :rand.* in lib/ (except RNG module)

## Status:
- ✅ Executor fixed
- ⚠️ Samplers still need work
- ⚠️ Trial generation needs isolation