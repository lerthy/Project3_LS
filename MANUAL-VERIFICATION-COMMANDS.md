# Manual Verification Commands

## Quick Commands to Verify Go/Terratest Removal

### 1. Check for Go Files
```bash
find . -name "*.go" -type f
# Should return nothing if Go files are removed
```

### 2. Check for Go Module Files
```bash
find . -name "go.mod" -o -name "go.sum" -type f
# Should return nothing if Go modules are removed
```

### 3. Check if infra/tests Directory Exists
```bash
ls -la infra/tests 2>/dev/null && echo "❌ Tests dir exists" || echo "✅ Tests dir removed"
```

### 4. Check Buildspec Files for Go References
```bash
grep -r "golang\|go -C\|go mod" buildspec*.yml
# Should return nothing if Go references are removed
```

### 5. Check for Runtime References
```bash
grep -A 5 "runtime-versions:" buildspec*.yml
# Should not show golang runtime
```

### 6. Search All Config Files for Active References
```bash
grep -r "terratest\|TestInfra" --include="*.yml" --include="*.tf" --include="*.sh" \
  --exclude-dir=docs --exclude-dir=node_modules .
# Should return nothing or only documentation references
```

### 7. Verify Buildspec Structure
```bash
cat buildspec-infra.yml | grep -A 10 "install:"
# Should show clean install phase without golang runtime
```

## ✅ Expected Results for Clean Removal:

- **No .go files**: `find . -name "*.go"` returns empty
- **No Go modules**: `find . -name "go.*"` returns empty  
- **No tests dir**: `ls infra/tests` shows "No such file or directory"
- **Clean buildspecs**: No golang/terratest references
- **Only docs**: Any remaining references should be in documentation files only

## 🎯 One-Liner Full Check:
```bash
echo "Files:" && find . -name "*.go" -o -name "go.*" | wc -l && \
echo "Buildspec refs:" && grep -c "golang\|terratest" buildspec*.yml 2>/dev/null | wc -l && \
echo "Tests dir:" && ls infra/tests 2>/dev/null | wc -l
```

If all return `0`, you're completely Go-free! 🎉
