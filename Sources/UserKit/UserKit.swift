// UserKit - Main Export File
// This file re-exports all public APIs from the UserKit package

import Foundation

// MARK: - Foundation Re-export
@_exported import Foundation

// MARK: - Data Models
// Re-export all data models
// (Models are exported directly from their individual files)

// MARK: - Network Layer
// Re-export network components
// (Network components are exported directly from their individual files)

// MARK: - Services
// Re-export service components
// (Services are exported directly from their individual files)

// MARK: - Version Information
public struct UserKitVersion {
    public static let version = "2.0.0"
    public static let buildNumber = "1"
}