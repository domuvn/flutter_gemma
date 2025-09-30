# Bundling Large Models (>2GB)

Android has a 2GB limit for individual asset files. For models larger than this limit, flutter_gemma supports automatic multi-part file assembly.

## Overview

When bundling a large model (e.g., Gemma 7B), you need to:
1. Split the model file into parts smaller than 2GB
2. Add all parts to your Flutter assets
3. Reference the base filename in your code
4. The installer automatically detects and assembles parts

## Quick Start

### Step 1: Split Your Model

Use the provided script to split your model file:

```bash
./scripts/split_model.sh path/to/gemma-7b-it.bin 1900
```

This creates:
- `gemma-7b-it.bin.part1` (1900 MB)
- `gemma-7b-it.bin.part2` (1900 MB)
- `gemma-7b-it.bin.part3` (remaining)
- etc.

**Arguments:**
- First argument: Path to your model file
- Second argument (optional): Chunk size in MB (default: 1900 MB)

### Step 2: Add Parts to Assets

In your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/models/gemma-7b-it.bin.part1
    - assets/models/gemma-7b-it.bin.part2
    - assets/models/gemma-7b-it.bin.part3
```

**Important:** Add ALL parts to the assets list.

### Step 3: Use in Your Code

Reference the **base filename** (without `.part1`, `.part2`, etc.):

```dart
await BundledModelInstaller.installIfNeeded(
  InferenceModelSpec(
    name: 'gemma-7b',
    modelUrl: 'asset://assets/models/gemma-7b-it.bin',  // Base filename only!
  ),
);
```

The installer will:
1. Auto-detect all part files (`.part1`, `.part2`, etc.)
2. Copy each part from assets
3. Assemble them in order into the final model file
4. Verify the assembled file size

## How It Works

### Auto-Detection

The installer looks for files matching the pattern:
- `{base_path}.part1`
- `{base_path}.part2`
- `{base_path}.part3`
- ...

If `.part1` exists, it assumes multi-part mode. If not, it falls back to single-file mode.

### Assembly Process

1. Creates target directory
2. Opens output file for streaming write
3. For each part (in order):
   - Loads from assets
   - Appends to output file
   - Tracks total bytes
4. Verifies final file size matches sum of parts

### Backward Compatibility

Single files still work normally:

```dart
// This still works for models < 2GB
await BundledModelInstaller.installIfNeeded(
  InferenceModelSpec(
    name: 'gemma-2b',
    modelUrl: 'asset://assets/models/gemma-2b-it.bin',
  ),
);
```

## Manual Splitting (Alternative)

If you prefer not to use the script, you can split manually:

### macOS/Linux

```bash
# Split into 1900 MB chunks
split -b 1900M gemma-7b-it.bin gemma-7b-it.bin.part

# Rename parts
mv gemma-7b-it.bin.partaa gemma-7b-it.bin.part1
mv gemma-7b-it.bin.partab gemma-7b-it.bin.part2
# etc.
```

### Windows (PowerShell)

```powershell
# Split into 1900 MB chunks
$inputFile = "gemma-7b-it.bin"
$chunkSize = 1900MB
$reader = [System.IO.File]::OpenRead($inputFile)
$buffer = New-Object byte[] $chunkSize
$part = 1

while ($bytesRead = $reader.Read($buffer, 0, $buffer.Length)) {
    $outputFile = "$inputFile.part$part"
    [System.IO.File]::WriteAllBytes($outputFile, $buffer[0..($bytesRead-1)])
    $part++
}

$reader.Close()
```

## Best Practices

### Chunk Size

- **Recommended:** 1900 MB per part
- Stays safely under 2GB Android limit
- Leaves headroom for filesystem overhead
- Balance between number of parts and part size

### Asset Organization

Keep model files organized:

```
assets/
  models/
    gemma-2b-it.bin              # Small model (single file)
    gemma-7b-it.bin.part1        # Large model (multi-part)
    gemma-7b-it.bin.part2
    gemma-7b-it.bin.part3
```

### Testing

1. **Test on Android device/emulator** - The 2GB limit is Android-specific
2. **Verify installation logs** - Check debug output for part detection
3. **Check final file size** - Ensure it matches original model

### Debugging

Enable debug prints to see the assembly process:

```dart
// Look for these debug messages:
// - "Detected X parts for {filename}"
// - "Copying part X/Y: {path}"
// - "Successfully assembled {filename} from X parts"
// - "Total size: X bytes"
```

## Example: Complete Workflow

```bash
# 1. Split your model
./scripts/split_model.sh ~/Downloads/gemma-7b-it.bin 1900

# Output:
# Created: gemma-7b-it.bin.part1 (1.9G)
# Created: gemma-7b-it.bin.part2 (1.9G)
# Created: gemma-7b-it.bin.part3 (650M)

# 2. Copy parts to your Flutter project
cp ~/Downloads/gemma-7b-it.bin.part* your_app/assets/models/

# 3. Update pubspec.yaml
# (Add all .part files to assets)

# 4. Use in your app
```

```dart
// your_app/lib/main.dart
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/mobile/flutter_gemma_mobile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Install large model (auto-detects and assembles parts)
  await BundledModelInstaller.installIfNeeded(
    InferenceModelSpec(
      name: 'gemma-7b',
      modelUrl: 'asset://assets/models/gemma-7b-it.bin',
    ),
  );
  
  // Create model and use normally
  final model = await FlutterGemmaPlugin.instance.createModel(
    modelType: ModelType.gemmaIt,
    maxTokens: 2048,
  );
  
  runApp(MyApp());
}
```

## Troubleshooting

### "Failed to copy asset" error

- Ensure all `.part` files are in pubspec.yaml assets
- Check file naming: must be `.part1`, `.part2`, etc. (sequential)
- Verify files are in the correct directory

### File size mismatch

- Re-split the model file
- Ensure all parts were copied correctly
- Check for corruption during split/copy

### Parts not detected

- Verify parts exist in assets with correct naming
- Check debug logs for detection attempts
- Ensure you're using the base filename (without `.part1`)

## Performance

### Installation Time

- First install: Copies and assembles all parts (slower)
- Subsequent launches: Skips installation (fast)
- Time depends on: model size, device storage speed

### Storage

- Temporary: Parts in app bundle (APK/IPA)
- Permanent: Assembled model in app documents directory
- Total storage: ~2x model size during installation, ~1x after

### Memory

- Streaming assembly: Low memory usage
- Processes one part at a time
- Suitable for devices with limited RAM

## See Also

- [BundledModelInstaller API Documentation](../lib/core/model_management/managers/bundled_model_installer.dart)
- [Example: Bundled Model Usage](../example/lib/bundled_model_example.dart)
- [Flutter Assets Guide](https://docs.flutter.dev/development/ui/assets-and-images)