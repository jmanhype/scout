# Scout Dogfooding Report
**Generated**: 2025-12-06
**Status**: 🔴 **BLOCKING ISSUES FOUND**

## Executive Summary

Scout has several structural and compilation issues that need to be resolved before it can compile and run properly. The main issues stem from a confused project structure (umbrella vs. flat) and missing schema files.

---

## 🔴 Critical Issues

### Issue #1: Duplicate/Conflicting Umbrella Structure

**Severity**: HIGH
**Impact**: Confusing codebase, potential build errors

**Problem**:
Scout has TWO separate umbrella project structures:

1. **Active umbrella** at root (`mix.exs` → `apps/`):
   - `apps/scout_core/` (v0.3.0, fully configured)
   - `apps/scout_dashboard/` (v0.3.0, Phoenix LiveView)

2. **Legacy umbrella** in `scout_umbrella/`:
   - `scout_umbrella/apps/scout_core/` (v0.1.0, stub code)
   - Appears to be an abandoned/old version

**Additionally**: There's ALSO a `lib/` directory at the project root with core Scout modules, which conflicts with the umbrella pattern (umbrella projects shouldn't have a root `lib/`).

**Recommendation**:
```bash
# Option A: Clean umbrella structure (recommended)
rm -rf scout_umbrella/          # Remove legacy umbrella
rm -rf lib/                     # Remove root lib/ (conflicts with umbrella)
# Move all modules currently in lib/ into apps/scout_core/lib/

# Option B: Flat structure
rm -rf apps/                    # Remove umbrella apps
rm -rf scout_umbrella/          # Remove legacy umbrella
# Keep lib/ as the main source directory
# Update root mix.exs to remove apps_path
```

### Issue #2: Missing Schema Files (Compilation Blocker)

**Severity**: CRITICAL
**Impact**: **Project does not compile**

**Error**:
```
== Compilation error in file lib/scout/format.ex ==
** (File.Error) could not read file "/Users/speed/straughter/speckit/scout/_build/dev/lib/scout_core/priv/schema/study.schema.json": no such file or directory
```

**Problem**:
`apps/scout_core/lib/scout/format.ex` (lines 12-13) tries to load JSON schema files at compile time:

```elixir
@study_schema Path.join(:code.priv_dir(@app), "schema/study.schema.json") |> File.read!() |> Jason.decode!()
@trial_schema Path.join(:code.priv_dir(@app), "schema/trial.schema.json") |> File.read!() |> Jason.decode!()
```

But these files don't exist:
- ❌ `apps/scout_core/priv/schema/study.schema.json` - MISSING
- ❌ `apps/scout_core/priv/schema/trial.schema.json` - MISSING

**Current state**:
- `apps/scout_core/priv/` only contains `migrations/`
- No `schema/` directory exists

**Recommendation**:
```bash
# Create the schema directory
mkdir -p apps/scout_core/priv/schema/

# Create minimal schema files (or make validation optional)
```

**Quick Fix**: Make schema validation optional in dev/test:
```elixir
# In apps/scout_core/lib/scout/format.ex
@study_schema if File.exists?(Path.join(:code.priv_dir(@app), "schema/study.schema.json")) do
  Path.join(:code.priv_dir(@app), "schema/study.schema.json") |> File.read!() |> Jason.decode!()
else
  %{"required" => []}  # Minimal fallback
end
```

---

## ⚠️  Warnings Found (Non-blocking)

### 1. Unused Variables (23 warnings)

Multiple files have unused variables that should either be:
- Prefixed with `_` if intentionally unused
- Removed if truly unnecessary
- Used if they were meant to be used

**Examples**:
- `lib/sampler/multivariate_tpe.ex:60` - `bad_dist` unused
- `lib/sampler/tpe.ex:82,92,100` - `rng_state` shadowing
- `lib/sampler/warm_start_tpe.ex:207` - `study_id` unused

### 2. Deprecated Charlist Syntax (3 warnings)

Phoenix LiveView files use deprecated single-quote charlists:
```elixir
# Old (deprecated):
when char in '\s\t\r'

# New (should use):
when char in ~c"\s\t\r"
```

**Fix**: Run `mix format --migrate` in the Phoenix LiveView dependency

---

## 📁 Directory Structure Analysis

### Current Structure (Confusing!)
```
scout/
├── mix.exs                    # Umbrella config (points to apps/)
├── lib/                       # ❌ CONFLICTING - shouldn't exist in umbrella
│   ├── application.ex
│   ├── scout.ex
│   ├── sampler/
│   ├── pruner/
│   └── ... (lots of modules)
├── apps/                      # ✅ Active umbrella structure
│   ├── scout_core/
│   │   ├── mix.exs (v0.3.0)
│   │   ├── lib/
│   │   │   ├── application.ex
│   │   │   └── scout/
│   │   └── priv/
│   │       └── migrations/
│   └── scout_dashboard/
│       ├── mix.exs (v0.3.0)
│       └── lib/
│           └── scout_dashboard/
├── scout_umbrella/            # ❌ Legacy/abandoned umbrella
│   ├── mix.exs (v0.1.0)
│   └── apps/
│       └── scout_core/ (stub)
├── test/
├── config/
├── priv/
│   └── repo/
├── examples/
├── docs/
└── ... (Docker, K8s, etc.)
```

### Recommended Structure (Option A: Clean Umbrella)
```
scout/
├── mix.exs                    # Umbrella config
├── apps/
│   ├── scout_core/            # Core optimization logic
│   │   ├── mix.exs
│   │   ├── lib/
│   │   │   ├── scout.ex
│   │   │   ├── application.ex
│   │   │   ├── sampler/
│   │   │   ├── pruner/
│   │   │   └── ...
│   │   ├── priv/
│   │   │   ├── migrations/
│   │   │   └── schema/       # CREATE THIS!
│   │   └── test/
│   └── scout_dashboard/       # Phoenix LiveView UI
│       ├── mix.exs
│       ├── lib/
│       ├── assets/
│       └── test/
├── config/                    # Shared umbrella config
├── examples/
├── docs/
├── docker-compose.yml
└── k8s/
```

---

## ✅ What's Working

1. **Dependencies**: All Hex packages resolved correctly
   - Phoenix 1.7.7, LiveView 0.19.0, Ecto, Oban all fetched successfully

2. **Docker & K8s Config**: Present and appears complete
   - `docker-compose.yml`
   - `k8s/` directory with manifests

3. **Documentation**: Comprehensive README with examples
   - Installation instructions
   - Quick start examples
   - Deployment guides

4. **Examples**: Rich example directory
   - `examples/` directory exists
   - Multiple proof scripts present

---

## 🛠️  Recommended Action Plan

### Phase 1: Immediate Fixes (Unblock Compilation)

1. **Create missing schema files**:
   ```bash
   mkdir -p apps/scout_core/priv/schema

   # Minimal study.schema.json
   echo '{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","required":["id","goal"]}' > apps/scout_core/priv/schema/study.schema.json

   # Minimal trial.schema.json
   echo '{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","required":["id","params"]}' > apps/scout_core/priv/schema/trial.schema.json
   ```

2. **Fix format.ex** to handle missing schemas gracefully (optional)

### Phase 2: Structural Cleanup

3. **Choose structure** (umbrella vs flat) and commit to it:

   **Recommended: Umbrella** (better separation of concerns)
   ```bash
   # Move all root lib/ modules into apps/scout_core/lib/
   # Verify no file conflicts
   # Delete root lib/ directory
   # Delete scout_umbrella/ directory
   ```

4. **Clean up unused variables**:
   ```bash
   # Prefix unused vars with underscore
   # Run Credo to find issues
   mix credo --strict
   ```

### Phase 3: Validation

5. **Compile and test**:
   ```bash
   mix deps.get
   mix compile
   mix test
   ```

6. **Run examples**:
   ```bash
   # Test one of the proof scripts
   elixir examples/proof_scripts/test_tpe.exs
   ```

7. **Verify dashboard**:
   ```bash
   mix phx.server
   # Visit http://localhost:4050
   ```

---

## 📊 File Organization Issues

### Duplicate Modules (Need Investigation)

Some modules appear in multiple places:
- `lib/application.ex` vs `apps/scout_core/lib/application.ex`
- `lib/pruner.ex` vs `apps/scout_core/lib/scout/pruner/` directory

**Need to verify**:
- Which version is canonical?
- Are they identical or different?
- Should one be deleted?

---

## 🔍 Still To Validate

These items need checking once compilation is fixed:

- [ ] Test suite execution (`mix test`)
- [ ] Example scripts (`elixir examples/*.exs`)
- [ ] Proof scripts (`elixir PROOF_*.exs`)
- [ ] Docker build (`docker-compose build`)
- [ ] Phoenix dashboard (`mix phx.server`)
- [ ] Database migrations (`mix ecto.migrate`)
- [ ] Kubernetes manifests validity

---

## 📝 Summary

**Current State**: 🔴 **Does not compile**

**Blockers**:
1. Missing schema JSON files (CRITICAL)
2. Confused project structure (HIGH)

**Time to Fix**: ~30 minutes for quick fixes, 2-3 hours for proper cleanup

**Next Steps**:
1. Create schema files to unblock compilation
2. Decide on umbrella vs flat structure
3. Consolidate duplicate code
4. Fix warnings
5. Run full test suite
6. Validate examples and proof scripts

---

**Would you like me to proceed with implementing these fixes?**
