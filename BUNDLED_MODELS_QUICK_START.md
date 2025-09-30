# Bundled Models - Quick Start

## ✅ YES, You Can Bundle Models Directly!

While you **cannot skip copying to the filesystem** (MediaPipe requires it), you **can** make it efficient by:
1. Copying **only once** on first launch
2. Checking SharedPreferences before copying
3. Registering the model path after copying

## 🚀 3-Step Setup

### 1. Add Model to Assets
```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/models/your-model.bin
```

### 2. Install on First Launch
```dart
import 'package:flutter_gemma/flutter_gemma.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Install bundled model (only copies if not already present)
  await BundledModelInstaller.installIfNeeded(
    InferenceModelSpec(
      name: 'my-model',
      modelUrl: 'asset://assets/models/your-model.bin',
    ),
  );
  
  runApp(MyApp());
}
```

### 3. Use Normally
```dart
final model = await FlutterGemmaPlugin.instance.createModel(
  modelType: ModelType.gemmaIt,
  preferredBackend: PreferredBackend.gpu,
);

final session = model.createSession();
final response = await session.getResponse(
  message: Message.user(text: 'Hello!'),
);
```

## 📊 What Happens Under the Hood

```
App Launch
    ↓
BundledModelInstaller.installIfNeeded()
    ↓
Check SharedPreferences: "Is model registered?"
    ↓
NO → Copy from assets to /data/data/[package]/files/
   → Register in SharedPreferences
    ↓
YES → Skip (already installed)
    ↓
Model ready!
```

## ⚡ Key Points

✅ **Efficient**: Copy happens only once
✅ **Fast**: Subsequent launches skip the copy
✅ **Registered**: Model path stored in SharedPreferences
✅ **Works Offline**: No network required
✅ **Standard API**: Use normal `createModel()` afterwards

❌ **Cannot**: Skip copying entirely (MediaPipe needs filesystem access)
❌ **Cannot**: Use asset:// URLs directly with native APIs

## 🎯 Why Copy is Necessary

**MediaPipe requires:**
- Real file system paths (not `asset://` URLs)
- Files accessible via standard File I/O
- Read/write access for model loading

**Flutter assets are:**
- Embedded in app bundle
- Not directly accessible to native code
- Must be extracted to filesystem first

## 📝 Full Documentation

See `BUNDLED_MODELS_GUIDE.md` for:
- Platform-specific bundling (for large models)
- Advanced usage patterns
- Troubleshooting
- Best practices

## 🔧 API Reference

```dart
class BundledModelInstaller {
  // Install only if not already present (recommended)
  static Future<void> installIfNeeded(ModelSpec spec);
  
  // Check installation status
  static Future<bool> isInstalled(ModelSpec spec);
  
  // Force reinstall (for updates)
  static Future<void> reinstall(ModelSpec spec);
}
```

## 💡 Example

See `example/lib/bundled_model_example.dart` for a complete working example.