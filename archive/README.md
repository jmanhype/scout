# ⚠️ ARCHIVE - DO NOT USE ⚠️

This directory contains legacy code and experiments that are **NOT** part of the main Scout codebase.

## WARNING

- **DO NOT** import or reference any code from this directory
- **DO NOT** copy-paste from these files without careful review
- **DO NOT** use these as examples - they may contain bugs or outdated patterns

## What's Here

- Old proof-of-concept scripts
- Experimental features that were rejected
- Legacy code from before architectural fixes
- Test scripts that may have security issues

## Credo Protection

The `.credo.exs` configuration blocks imports from this directory. Any attempt to use archive code will fail code review.

## If You Need Something From Here

1. Review the code carefully for bugs and security issues
2. Update it to match current architectural standards  
3. Move it to the proper location in `lib/` or `apps/scout_core/lib/`
4. Add proper tests
5. Get it reviewed

Remember: This code is archived for a reason. It likely has issues.