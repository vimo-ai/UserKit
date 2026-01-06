//
//  MemberTier.swift
//  UserKit
//
//  会员等级定义
//

import Foundation

/// 会员等级枚举
public enum MemberTier: String, Codable, CaseIterable {
    case free = "FREE"
    case basic = "BASIC"
    case premium = "PREMIUM"

    public var displayName: String {
        switch self {
        case .free: return "免费版"
        case .basic: return "基础会员"
        case .premium: return "高级会员"
        }
    }

    /// 每日配额
    public var dailyQuota: Int {
        switch self {
        case .free: return 3
        case .basic: return 10
        case .premium: return 50
        }
    }

    /// 单日程最大查看次数（首次 + 再生）
    public var maxViewsPerSchedule: Int {
        switch self {
        case .free: return 1
        case .basic: return 4
        case .premium: return 11
        }
    }

    /// 运势版本
    public var fortuneVersion: String {
        self == .free ? "BRIEF" : "DETAILED"
    }
}
