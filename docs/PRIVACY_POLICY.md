**Last Updated: 2026-01-20**

BakaBox is a third-party Counter-Strike 2 launcher tool and is not affiliated with Valve Corporation in any way. We take your privacy very seriously.

## 1. Information Collection

### 1.1 Information We Collect

**Account Information** (Optional, only when you choose to log in):
- Forum username and UID
- Avatar image URL
- Steam ID (If bound in the forum)
- Forum points and zombie coin data

**Usage Data** (Stored locally, not uploaded to the server):
- Server favorites list
- App settings and preferences
- Game path configuration (Used only for one-click join feature)
- Key binding configurations
- Image cache

**Technical Information** (Anonymous statistics):
- App version number
- OS type and version
- Device architecture (x86_64/arm64)
- App startup time (Used for performance optimization)

### 1.2 Information We Do Not Collect

- ❌ Your forum password (Only used for one-time verification, will not be saved)
- ❌ QQ Number (QQ login only retrieves forum Cookie)
- ❌ In-game chat logs or game data
- ❌ Real name, address, phone number
- ❌ Payment information (The app is completely free, no in-app purchases)
- ❌ Precise location information

## 2. Information Usage

### 2.1 Purpose of Use

**Core Features**:
- Quick launch and join CS2 community servers
- Browse server lists and detailed information
- One-click join servers (via Steam protocol)
- View Steam Workshop update logs

**Account Management** (Optional):
- Maintain your login status (JWT Token, valid for 7 days)
- Display user information and map info contribution records
- Forum daily sign-in and shake features

**Community Features** (Optional):
- Submit map name translations
- Upload map background images
- Vote on map information
- Submit feedback and suggestions

**Desktop Enhancements** (Optional):
- Auto-start game
- Monitor game status
- Auto-queue (Queue to join full servers)
- Map change monitoring and notifications

### 2.2 Data Storage

**Local Storage** (Accounts for the majority):
- **Windows**: %USERPROFILE%\Documents\BakaBox\
  - storage/ - App settings and data
  - cache/ - Image cache
  - logs/ - App logs
- **iOS**: App sandbox Documents directory
- **Android**: App private storage directory

**Server Storage** (Located in China):
- Basic user info (Username, UID, Avatar)
- Map information content (Map translations, background images)
- Voting records
- Login session Token (Valid for 7 days)

### 2.3 Data Transmission

All network requests are transmitted securely via HTTPS:
- API Requests: https://api.aishia.cc
- Forum Login: https://bbs.zombieden.cn
- Server List: https://s.zombieden.cn

## 3. Third-Party Services

### 3.1 Services We Use

**Forum Login** (bbs.zombieden.cn):
- Purpose: Account verification and user info retrieval
- Data: Username, UID, Avatar, Steam ID
- Note: Passwords are only used for one-time verification and are not saved

**QQ Login** (Optional, Desktop only):
- Purpose: Quick login to forum account
- Data: QQ authorization Cookie (Does not save QQ number)

**Steam Protocol**:
- Purpose: Invoke Steam client to start the game
- Data: Server IP address
- Note: This is a standard Steam feature

**Game File Access** (Optional, Desktop only):
- Read: game/csgo/console.log (Game logs)
- Read/Write: game/csgo/cfg/ (Configuration files)
- Note: Only read/write locally, not uploaded to servers

### 3.2 Services We Do Not Use

- ❌ Third-party ad networks (App is ad-free)
- ❌ Third-party analytics tools (e.g., Google Analytics)
- ❌ Data brokers or marketing agencies

## 4. Data Security

### 4.1 Security Measures

- ✅ HTTPS/TLS 1.2+ encrypted transmission
- ✅ JWT Token authentication (Valid for 7 days)
- ✅ Passwords are not saved locally or on the server
- ✅ Local data is protected by OS permissions
- ✅ Token refresh mechanism to prevent concurrent attacks

### 4.2 Data Retention

**Local Data**:
- Kept permanently until you uninstall the app or manually clear it
- Caches and logs can be cleared in settings

**Server Data**:
- Login Sessions: JWT Token expires automatically after 7 days
- Basic User Info: Retained until you request deletion (Contact us)
- Map Info Content: Retained permanently (Community shared resources)
- Voting Records: Retained permanently (To prevent duplicate voting)
- Anonymous Statistics: Automatically deleted after 90 days

## 5. Your Rights

### 5.1 Access and Control

- View your account information and map info contribution records
- Modify your account profile on the forum
- Delete local data (Uninstall app or clear cache)
- Log out (Clears local session info)
- Request deletion of server data (Contact us)
- Export map information data you provided (Contact us)

### 5.2 Opting Out

You can at any time:
- Log out within the app
- Uninstall the app
- Contact us to delete server data

## 6. Children's Privacy

BakaBox is intended for Counter-Strike 2 players (16 years and older). We do not knowingly collect personal information from children under 16. If you are a parent and find that your child has provided us with personal information, please contact us, and we will delete it immediately.

## 7. Privacy Policy Updates

We may update this Privacy Policy from time to time. For significant changes, we will:
- Display a notification within the app
- Update the "Last Updated" date
- Require you to re-agree to the new privacy policy

Continued use of the app signifies your acceptance of the updated privacy policy.

## 8. Disclaimer

**IMPORTANT:**
- BakaBox is an independently developed third-party tool.
- It has no official affiliation with Valve Corporation, Steam, or Counter-Strike 2.
- Counter-Strike and Steam are registered trademarks of Valve Corporation.
- We are not responsible for the content, availability, or security of game servers.
- Use of this app to join third-party servers is at your own risk.

## 9. Contact Us

For any questions, comments, or requests, please contact:
- **Developer Email**: aishia@zohomail.cn
- **In-App Feedback**: Use the "Feedback" feature
- **Community Forum**: bbs.zombieden.cn

We will respond to your requests within 7 business days. For urgent security issues, we will respond within 48 hours.

**Note**: BakaBox is an independently developed third-party tool, and the developer is not affiliated with the forum operators.

## 10. Governing Law

This privacy policy is governed by the laws of the People's Republic of China. In the event of a dispute, both parties shall negotiate amicably; if negotiation fails, either party may file a lawsuit in the People's Court at the developer's location.

