# 📺 Deploying NesCaster to Apple TV 4K (3rd Gen)

This guide will help you install and test NesCaster on your physical Apple TV 4K 3rd generation device.

## Prerequisites

- ✅ **macOS** Sonoma 14+ (you're on macOS 25.2.0)
- ✅ **Xcode** 15+ installed
- ✅ **Apple Developer Account** (free account works for personal development)
- ✅ **Apple TV 4K 3rd Gen** connected to the same Wi-Fi network as your Mac
- ✅ **USB-C cable** (for initial pairing, if needed)

## Step-by-Step Instructions

### 1. Enable Developer Mode on Apple TV

1. On your Apple TV, go to **Settings** → **Privacy and Security**
2. Scroll down and enable **Developer Mode**
3. Your Apple TV will restart
4. After restart, you'll see a warning about Developer Mode - acknowledge it

### 2. Connect Apple TV to Xcode

#### Option A: Automatic Discovery (Recommended)
1. Make sure your Apple TV and Mac are on the **same Wi-Fi network**
2. Open **Xcode** → **Window** → **Devices and Simulators** (⇧⌘2)
3. Your Apple TV should appear in the left sidebar under "tvOS Devices"
4. If it doesn't appear, click the **"+"** button and select "Add Device via Network"
5. Enter your Apple TV's IP address (found in Settings → Network)

#### Option B: USB Connection (If Wi-Fi doesn't work)
1. Connect your Apple TV to your Mac using a USB-C cable
2. On Apple TV, go to **Settings** → **Remotes and Devices** → **Bluetooth**
3. Your Apple TV should appear in Xcode's Devices window

### 3. Trust the Developer Certificate

1. In Xcode's **Devices and Simulators** window, select your Apple TV
2. You may see a message asking to "Trust" the device - click **Trust**
3. On your Apple TV, you may see a prompt asking to trust the computer - select **Trust**

### 4. Configure Code Signing in Xcode

1. Open the project in Xcode:
   ```bash
   open "Apple TV/NesCaster.xcodeproj"
   ```

2. Select the **NesCaster** project in the navigator (top item)

3. Select the **NesCaster** target

4. Go to the **Signing & Capabilities** tab

5. Make sure:
   - ✅ **Automatically manage signing** is checked
   - ✅ **Team** is set to your Apple Developer account (or select it from the dropdown)
   - ✅ **Bundle Identifier** is `com.nescaster.app` (should already be set)

6. If you see any errors, click **"Try Again"** or **"Add Account"** to sign in with your Apple ID

### 5. Select Your Apple TV as the Build Destination

1. In Xcode's toolbar, click the device selector (next to the Play/Stop buttons)
2. Select your Apple TV from the list (it should show as "Apple TV" or your custom name)
3. If your Apple TV doesn't appear:
   - Make sure it's powered on and connected
   - Check that Developer Mode is enabled
   - Try disconnecting and reconnecting

### 6. Build and Run

1. Press **⌘R** (or click the Play button) to build and run
2. Xcode will:
   - Build the app
   - Install it on your Apple TV
   - Launch it automatically

3. The first time you install, you may see a prompt on your Apple TV asking to trust the developer - select **Trust**

### 7. Trust the Developer Profile on Apple TV

After the first installation:

1. On your Apple TV, go to **Settings** → **General** → **Profiles and Device Management**
2. You should see your developer profile listed
3. Select it and choose **Trust**
4. Enter your Apple TV passcode if prompted

## Troubleshooting

### Apple TV Not Appearing in Xcode

- **Check Wi-Fi**: Ensure both devices are on the same network
- **Restart Apple TV**: Power cycle your Apple TV
- **Restart Xcode**: Quit and reopen Xcode
- **Check Developer Mode**: Verify it's enabled in Settings → Privacy and Security
- **Try USB**: Use USB-C cable as a fallback

### Code Signing Errors

- **No Team Selected**: 
  - Go to Xcode → Settings → Accounts
  - Add your Apple ID if not already added
  - Select your team in the project settings

- **Bundle Identifier Conflict**:
  - The bundle ID `com.nescaster.app` might already be in use
  - Change it to something unique like `com.yourname.nescaster.app`

- **Provisioning Profile Issues**:
  - With automatic signing, Xcode should handle this
  - If errors persist, try cleaning the build folder (⇧⌘K) and rebuilding

### App Crashes on Launch

- **Check Console**: View logs in Xcode's Console (⇧⌘C)
- **Check Deployment Target**: Your Apple TV must be running tvOS 17.0 or later
- **Check Build Settings**: Ensure the correct SDK is selected

### App Installs But Doesn't Launch

- **Check Home Screen**: The app should appear on your Apple TV home screen
- **Launch Manually**: Navigate to the app and launch it from the home screen
- **Check Trust Settings**: Make sure you've trusted the developer profile

## Running Without Xcode (After Initial Install)

Once the app is installed, you can launch it directly from your Apple TV home screen without needing Xcode running.

## Updating the App

To update the app with new code:

1. Make your code changes
2. In Xcode, select your Apple TV as the destination
3. Press **⌘R** to build and run
4. The app will be updated automatically

## Removing the App

To uninstall the app from your Apple TV:

1. Navigate to the app on the home screen
2. Press and hold the touch surface on the Siri Remote
3. Select **Delete** from the menu

Or:

1. In Xcode → Devices and Simulators
2. Select your Apple TV
3. Find NesCaster in the "Installed Apps" section
4. Click the **"-"** button to remove it

## Notes

- **Free Apple Developer Account**: Works for 7 days, then you'll need to reinstall
- **Paid Apple Developer Account ($99/year)**: Apps stay installed for 1 year
- **Network Deployment**: After initial setup, you can deploy over Wi-Fi without USB
- **Debugging**: You can debug the app in real-time using Xcode's debugger

## Quick Reference

| Action | Shortcut |
|--------|----------|
| Open Devices Window | ⇧⌘2 |
| Build and Run | ⌘R |
| Clean Build Folder | ⇧⌘K |
| Show Console | ⇧⌘C |
| Stop Running App | ⌘. |

---

**Need Help?** Check the Xcode console for detailed error messages, or refer to Apple's [tvOS Development Documentation](https://developer.apple.com/tvos/).

