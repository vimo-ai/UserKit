# UserKit

User management and authentication SDK for iOS applications.

## Features

- User authentication and session management
- Secure token storage and refresh
- User profile management
- Built on CoreNetworkKit for robust networking

## Installation

Add this package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vimo-ai/UserKit.git", from: "1.0.0")
]
```

## Requirements

- iOS 15.0+
- Swift 5.9+

## Usage

```swift
import UserKit

// Basic usage example
let userManager = UserManager()
try await userManager.signIn(email: email, password: password)
```

## License

Private - VIMO Organization