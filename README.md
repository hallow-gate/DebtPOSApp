# Marnie Store POS - Flutter Edition

A fully offline-capable Point of Sale system built with Flutter + Firebase.

## Features
- 📱 Mobile-first UI with bottom navigation
- 🔄 Full offline support with Hive local storage
- 🔄 Automatic sync when online
- 📷 Barcode scanner integration
- 📦 Product management with low-stock alerts
- 👥 Customer management with purchase history
- 📊 Dashboard with revenue and profit analytics
- 🖨 Receipt printing
- 📤 Data export/import (JSON)
- 🤖 GitHub Actions APK builds

## Firebase Setup

1. Create a Firebase project
2. Enable Email/Password authentication
3. Create Firestore collections: `products`, `customers`, `purchases`
4. Download `google-services.json` and place in `android/app/`
5. Add your Firebase config to GitHub Secrets for CI/CD

## Local Development

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build APK
flutter build apk --release