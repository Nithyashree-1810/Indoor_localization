# 📡 Lost Item Finder

A Flutter + ESP32 project that helps you locate a lost item by measuring WiFi signal strength between your phone and an ESP32 attached to the item.

---

## 🔧 How It Works

The ESP32 acts as a WiFi Access Point. Your phone connects to it and continuously pings the ESP32. The response time is used to estimate proximity — the faster the response, the closer you are to the item.

```
[Phone]  ──── WiFi ping ────►  [ESP32 on lost item]
         ◄─── response ──────
         measures time → shows proximity
```

---

## 🛠️ Hardware Required

| Component | Details |
|---|---|
| ESP32 Dev Board | Any standard ESP32 |
| Buzzer | Connected to GPIO 25 |
| LED | Connected to GPIO 26 |
| Power source | USB power bank or battery |

### Wiring

```
ESP32 GPIO 25  ──►  Buzzer (+)  ──►  GND
ESP32 GPIO 26  ──►  LED (+)  ──►  330Ω resistor  ──►  GND
```

---

## 📂 Project Structure

```
lost_item_finder/
├── lib/
│   └── main.dart          # Flutter app (UI + ping logic)
├── arduino/
│   └── esp32_firmware.ino # ESP32 firmware
└── README.md
```

---

## ⚡ ESP32 Setup

### 1. Install Dependencies (Arduino IDE)

- **ESP32 Board Package** — add this URL in Arduino IDE > Preferences > Board Manager URLs:
  ```
  https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
  ```
- **ESPAsyncWebServer** — install via Library Manager or GitHub:
  ```
  https://github.com/me-no-dev/ESPAsyncWebServer
  ```
- **AsyncTCP** — required by ESPAsyncWebServer:
  ```
  https://github.com/me-no-dev/AsyncTCP
  ```

### 2. Flash the Firmware

Open `arduino/esp32_firmware.ino` in Arduino IDE, select your ESP32 board, and upload.

### 3. Default Configuration

| Setting | Value |
|---|---|
| WiFi SSID | `ESP32_LostItemFinder` |
| WiFi Password | `123456789` |
| IP Address | `192.168.4.1` |
| Buzzer Pin | GPIO 25 |
| LED Pin | GPIO 26 |

### 4. API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/ping` | GET | Returns `OK` — used to measure response time |
| `/trigger` | GET | Activates buzzer and LED for 1.5 seconds |
| `/` | GET | Health check |

---

## 📱 Flutter App Setup

### 1. Requirements

- Flutter SDK 3.0+
- Dart 3.0+
- Android or iOS device

### 2. Install Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
```

Then run:

```bash
flutter pub get
```

### 3. Run the App

```bash
flutter run
```

---

## 🚀 Usage

1. **Power on** the ESP32 (attach it to the item you want to track)
2. On your phone, go to **WiFi Settings** and connect to:
   - Network: `ESP32_LostItemFinder`
   - Password: `123456789`
3. Open the app
4. Tap **SCAN ITEM** to start scanning
5. Walk around — the proximity updates every second
6. Tap **🔔 BUZZ** to trigger the buzzer when you're close

---

## 📶 Proximity Reference

| Response Time | Proximity | Typical Distance |
|---|---|---|
| < 30ms | Very Close | ~1–2 meters |
| < 80ms | Nearby | ~3–5 meters |
| < 200ms | Far Away | ~6–10 meters |
| 200ms+ | Very Far | 10+ meters or obstructed |

> **Note:** Response times can vary based on walls, interference, and network congestion. Use the trend (getting faster/slower) rather than exact values to navigate.

---

## 🐛 Troubleshooting

| Problem | Solution |
|---|---|
| "Connection Failed" | Make sure phone is connected to `ESP32_LostItemFinder` WiFi |
| "Connection Timed Out" | ESP32 may be out of range or powered off |
| Buzzer not working | Check GPIO 25 wiring and power supply |
| App shows wrong proximity | Ping times vary — walk slowly and watch the trend |
| Can't upload firmware | Hold BOOT button on ESP32 while uploading |

---

## 📄 License

MIT License — free to use and modify.

---

## 👤 Author

Built with Flutter & ESP32.
