# Guide: Bundling Models with Your App

This guide shows you how to bundle AI models directly with your Flutter app instead of downloading them at runtime.

## 📦 Why Bundle Models?

**Advantages:**
- ✅ App works offline immediately after installation
- ✅ No download wait time on first launch
- ✅ Guaranteed model availability
- ✅ Better user experience

**Disadvantages:**
- ❌ Larger app size (models can be 500MB-4GB)
- ❌ Harder to update models (requires app update)
- ❌ May exceed app store size limits for single download

## 🚀 Quick Start

### Step 1: Add Model to Assets

1. **Add your model file to your app's assets folder:**
   ```
   your_app/
   ├── assets/
   │   └── models/
   │       └── gemma-2b-it.bin  # Your model file (e.g., 1.5GB)
   └── pubspec.yaml
   ```

2. **Declare asset in `pubspec.yaml`:**
   ```yaml
   flutter:
     assets:
       - assets/models/gemma-2b-it.bin
   ```

   **Note:** Flutter has asset size limits per file. For models > 100MB, see Platform-Specific Bundling below.

### Step 2: Install Model on First Launch

In your app's initialization code (e.g., `main.dart` or splash screen):

```dart
import 'package:flutter_gemma/flutter_gemma.dart';

Future<void> initializeBundledModel() async {
  // Create model specification
  final modelSpec = InferenceModelSpec(
    name: 'gemma-2b-bundled',
    modelUrl: 'asset://assets/models/gemma-2b-it.bin',
    replacePolicy: ModelReplacePolicy.keep,
  );

  // Install only if not already present (efficient!)
  await BundledModelInstaller.installIfNeeded(modelSpec);
  
  print('Bundled model ready!');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Install bundled model on first launch
  await initializeBundledModel();
  
  runApp(MyApp());
}
```

### Step 3: Use the Model

After installation, use it normally:

```dart
final inferenceModel = await FlutterGemmaPlugin.instance.createModel(
  modelType: ModelType.gemmaIt,
  preferredBackend: PreferredBackend.gpu,
  maxTokens: 512,
);

final session = inferenceModel.createSession();
final response = await session.getResponse(
  message: Message.user(text: 'Hello!'),
);
print(response);
```

---

## 📱 Platform-Specific Bundling

For large models (>100MB), you should use platform-specific asset bundling:

### Android: Use Native Assets

**Better for large files** - bypasses Flutter asset limitations.

1. **Place model in Android assets:**
   ```
   android/
   ├── app/
   │   └── src/
   │       └── main/
   │           └── assets/
   │               └── models/
   │                   └── gemma-2b-it.bin
   ```

2. **Create a platform channel to copy from native assets:**

   **Android (Kotlin):**
   ```kotlin
   // android/app/src/main/kotlin/.../MainActivity.kt
   private fun copyModelFromAssets(assetFileName: String): String {
       val outputFile = File(context.filesDir, assetFileName)
       
       // Only copy if not already present
       if (outputFile.exists()) {
           return outputFile.absolutePath
       }
       
       assets.open("models/$assetFileName").use { input ->
           outputFile.outputStream().use { output ->
               input.copyTo(output)
           }
       }
       
       return outputFile.absolutePath
   }
   ```

3. **Call from Dart and register:**
   ```dart
   // Get the model path from native
   final modelPath = await platform.invokeMethod('copyModelFromAssets', {
     'fileName': 'gemma-2b-it.bin',
   });
   
   // Register it directly using file:// scheme
   final modelSpec = InferenceModelSpec(
     name: 'gemma-2b-bundled',
     modelUrl: 'file://$modelPath',
   );
   
   await FlutterGemmaPlugin.instance.modelManager.ensureModelReady(
     modelSpec.name, 
     modelSpec.modelUrl,
   );
   ```

### iOS: Use App Bundle Resources

1. **Add model to Xcode project:**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Drag model file into Runner target
   - Ensure "Copy items if needed" is checked
   - Add to target: Runner

2. **Copy from bundle on launch:**
   ```swift
   // ios/Runner/AppDelegate.swift
   func copyModelFromBundle(fileName: String) -> String? {
       let fileManager = FileManager.default
       let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
       let destURL = documentsURL.appendingPathComponent(fileName)
       
       // Only copy if not already present
       if fileManager.fileExists(atPath: destURL.path) {
           return destURL.path
       }
       
       guard let sourceURL = Bundle.main.url(forResource: fileName, withExtension: nil) else {
           return nil
       }
       
       try? fileManager.copyItem(at: sourceURL, to: destURL)
       return destURL.path
   }
   ```

3. **Register from Dart** (same as Android example above)

---

## 🎯 Advanced Usage

### Multiple Bundled Models

Bundle and install multiple models:

```dart
Future<void> initializeAllBundledModels() async {
  final models = [
    InferenceModelSpec(
      name: 'gemma-2b',
      modelUrl: 'asset://assets/models/gemma-2b-it.bin',
    ),
    InferenceModelSpec(
      name: 'gemma-7b',
      modelUrl: 'asset://assets/models/gemma-7b-it.bin',
    ),
  ];

  for (final model in models) {
    await BundledModelInstaller.installIfNeeded(model);
  }
}
```

### Show Installation Progress

For better UX, show progress during first-launch installation:

```dart
Future<void> installWithProgress() async {
  final modelSpec = InferenceModelSpec(
    name: 'gemma-2b',
    modelUrl: 'asset://assets/models/gemma-2b-it.bin',
  );

  // Check if already installed
  if (await BundledModelInstaller.isInstalled(modelSpec)) {
    print('Model already installed');
    return;
  }

  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Setting up AI model...\nThis only happens once.'),
        ],
      ),
    ),
  );

  // Install (this happens in background)
  await BundledModelInstaller.installIfNeeded(modelSpec);

  // Hide loading indicator
  Navigator.of(context).pop();
}
```

### Force Reinstall (After App Update)

If you update the bundled model in a new app version:

```dart
Future<void> reinstallUpdatedModel() async {
  final modelSpec = InferenceModelSpec(
    name: 'gemma-2b-v2',  // New version
    modelUrl: 'asset://assets/models/gemma-2b-it-v2.bin',
  );

  // Force reinstall even if old version exists
  await BundledModelInstaller.reinstall(modelSpec);
}
```

### Hybrid Approach: Bundled + Downloadable

Bundle a small model, allow downloading larger ones:

```dart
class ModelManager {
  Future<void> initialize() async {
    // Always bundle and install small model (e.g., 500MB)
    final smallModel = InferenceModelSpec(
      name: 'gemma-2b',
      modelUrl: 'asset://assets/models/gemma-2b-it.bin',
    );
    await BundledModelInstaller.installIfNeeded(smallModel);
  }

  Future<void> downloadLargeModel() async {
    // Optionally download larger model (e.g., 4GB)
    final largeModel = InferenceModelSpec(
      name: 'gemma-7b',
      modelUrl: 'https://example.com/gemma-7b-it.bin',
    );
    
    await FlutterGemmaPlugin.instance.modelManager
        .ensureModelReady(largeModel.name, largeModel.modelUrl);
  }
}
```

---

## 📊 How It Works Internally

```
App Installation
       ↓
[Model in app bundle]
       ↓
First Launch → BundledModelInstaller.installIfNeeded()
       ↓
Check SharedPreferences: "Is model registered?"
       ↓
   NO → Copy asset to /data/data/[package]/files/
       ↓
       Register in SharedPreferences
       ↓
  YES → Skip (already installed)
       ↓
[Model ready for use]
```

**Key Benefits:**
- ✅ Copy happens **only once** (checked via SharedPreferences)
- ✅ Subsequent app launches are instant
- ✅ Model survives app restarts
- ✅ Standard model management APIs work normally

---

## ⚠️ Important Considerations

### App Size Impact

| Model Size | Impact |
|------------|--------|
| 500MB - 1GB | Acceptable for most apps |
| 1GB - 2GB | Warning from Play Store/App Store |
| 2GB+ | May require app bundle optimization |

**Recommendation:** Use **App Bundles** (Android) and **On-Demand Resources** (iOS) for large models.

### Storage Duplication

After installation, the model exists in two places:
1. **App bundle** (read-only, in app package)
2. **Documents directory** (writable, used by MediaPipe)

This is **necessary** because MediaPipe requires file system access. The bundle copy is never used after initial installation.

### Asset Loading Limitations

Flutter's `rootBundle.load()` loads entire file into memory. For models > 500MB:
- Use platform-specific native asset copying (shown above)
- Or download on first launch instead of bundling

---

## 🧪 Testing

Test both scenarios:

```dart
void main() {
  testWidgets('Bundled model installs on first launch', (tester) async {
    final spec = InferenceModelSpec(
      name: 'test-model',
      modelUrl: 'asset://assets/test-model.bin',
    );

    // Should not be installed initially
    expect(await BundledModelInstaller.isInstalled(spec), false);

    // Install
    await BundledModelInstaller.installIfNeeded(spec);

    // Should now be installed
    expect(await BundledModelInstaller.isInstalled(spec), true);

    // Second call should skip (efficiency test)
    await BundledModelInstaller.installIfNeeded(spec);
    // Should still be installed
    expect(await BundledModelInstaller.isInstalled(spec), true);
  });
}
```

---

## 📚 API Reference

### `BundledModelInstaller`

#### `installIfNeeded(ModelSpec spec)`
Installs model only if not already present. **Most efficient for normal use.**

#### `isInstalled(ModelSpec spec)`
Checks if model is already installed.

#### `reinstall(ModelSpec spec)`
Forces reinstallation. Use after app updates with new model version.

---

## 🎓 Best Practices

1. **✅ DO** use `installIfNeeded()` - it's smart and efficient
2. **✅ DO** show a one-time setup screen on first launch for UX
3. **✅ DO** use platform-specific bundling for models > 500MB
4. **✅ DO** consider bundling small models, downloading large ones
5. **❌ DON'T** reinstall on every app launch - it wastes time and storage
6. **❌ DON'T** forget to declare assets in `pubspec.yaml`
7. **❌ DON'T** bundle models > 2GB without app bundle optimization

---

## 🐛 Troubleshooting

**Problem:** "Unable to load asset"
- **Solution:** Ensure asset is declared in `pubspec.yaml` and run `flutter clean`

**Problem:** "Model not found at path"
- **Solution:** Ensure `installIfNeeded()` completed before calling `createModel()`

**Problem:** App size too large
- **Solution:** Use platform-specific bundling or hybrid approach

**Problem:** Installation takes too long
- **Solution:** Show loading indicator and use `Isolate` for large copies

---

Need help? Check the example app or open an issue on GitHub!