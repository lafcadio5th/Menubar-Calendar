# Changelog

All notable changes to MenuBarCalendar will be documented in this file.

## [2.0.0] - 2026-01-08

### 🎉 Major Features

#### WeatherKit Integration
- Migrated from Open-Meteo API to Apple's official WeatherKit framework
- Native Apple weather data with improved accuracy and reliability
- Animated weather backgrounds supporting 20+ weather conditions:
  - Clear skies, clouds, rain, snow, storms, fog, and more
  - Dynamic animations that respond to real-time weather
- Intelligent header color adaptation based on weather conditions
- Seamless dark/light mode integration
- Weather display toggle in Settings with location permission management

### 🎨 UI/UX Improvements

#### Redesigned About Page
- Modern gradient app icon with shadow effects
- Cleaner layout with GitHub and issue reporting links
- Version badge display with capsule design

#### Enhanced Settings Layout
- Tab-based organization: General, Calendar, Notifications, Integrations, About
- Improved visual hierarchy and spacing
- Consistent form styling across all tabs

#### Calendar Customization
- Color picker for event date indicators
- Customizable event appearance
- Removed visual clutter from date grid for cleaner look

### 📅 Calendar Enhancements

#### Advanced Event Management
- Full event details overlay with comprehensive information display
- Event editing capabilities with calendar selection
- Improved event creation flow

#### Calendar Filtering
- Show/hide specific calendars
- Visual calendar list with color indicators
- Persistent calendar visibility preferences

### 🔗 Integrations

#### Todoist Integration
- Full API token management with secure storage
- Connection testing functionality
- Auto-refresh intervals: 1min, 5min, 15min, 30min, 1hour
- Manual refresh option
- Integration status indicators

### ⚙️ Settings & Preferences

#### General Settings
- Launch at login support (macOS 13+)
- Theme switching: System, Light, Dark modes
- Menu bar display format options:
  - Date only
  - Date + day of week
  - Full date with year

#### Calendar Settings
- Week start day preference (Monday/Sunday)
- Week number display toggle
- Lunar calendar support
- Calendar visibility management

### 🔐 Security & Permissions

- Added WeatherKit entitlement for official Apple weather service
- Proper location permission handling and user prompts
- Calendar access permission management
- Notification permission configuration
- Sandbox compliance with minimal required permissions

### 🐛 Bug Fixes

- Fixed calendar layout alignment issues
- Resolved header content visibility in all lighting conditions
- Improved provisioning profile synchronization
- Fixed weather animation display toggle behavior

### 🏗️ Technical Improvements

- Refactored weather service architecture for WeatherKit
- Implemented WMO weather code mapping for animation compatibility
- Enhanced error handling for API failures
- Improved settings persistence with AppStorage
- Optimized Metal rendering for weather animations

---

## [1.0.0] - 2026-01-01

### Initial Release

- Basic calendar display in menu bar
- Event management with system calendar integration
- Settings panel with essential preferences
- macOS menu bar integration
- Theme support (light/dark)
