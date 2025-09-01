//
//  NotificationHandler.swift
//  UserKit
//
//  Created by 💻higuaifan on 2025/8/27.
//

import Foundation
import UserNotifications
import UIKit

/// 通知处理器，负责处理推送通知的接收、解析和响应
public class NotificationHandler: ObservableObject {
    
    public static let shared = NotificationHandler()
    
    // MARK: - Published Properties
    
    @Published public private(set) var badgeCount: Int = 0
    @Published public private(set) var notificationHistory: [NotificationData] = []
    
    // MARK: - Private Properties
    
    private let maxHistoryCount = 50
    private var notificationCategories: Set<UNNotificationCategory> = []
    
    private init() {
        loadBadgeCount()
        loadNotificationHistory()
        setupNotificationCategories()
    }
    
    // MARK: - Notification Categories Setup
    
    /// 设置通知类别和快捷操作
    private func setupNotificationCategories() {
        var categories: Set<UNNotificationCategory> = []
        
        // 约定通知类别
        let agreementAcceptAction = UNNotificationAction(
            identifier: NotificationAction.acceptAgreement.rawValue,
            title: "接受",
            options: []
        )
        let agreementRejectAction = UNNotificationAction(
            identifier: NotificationAction.rejectAgreement.rawValue,
            title: "拒绝",
            options: []
        )
        let agreementCategory = UNNotificationCategory(
            identifier: NotificationType.agreement.categoryIdentifier,
            actions: [agreementAcceptAction, agreementRejectAction],
            intentIdentifiers: []
        )
        categories.insert(agreementCategory)
        
        // 信标通知类别
        let beaconRespondAction = UNNotificationAction(
            identifier: NotificationAction.respondBeacon.rawValue,
            title: "回应",
            options: [.foreground]
        )
        let beaconCategory = UNNotificationCategory(
            identifier: NotificationType.beacon.categoryIdentifier,
            actions: [beaconRespondAction],
            intentIdentifiers: []
        )
        categories.insert(beaconCategory)
        
        // 好友通知类别
        let friendAcceptAction = UNNotificationAction(
            identifier: NotificationAction.acceptFriend.rawValue,
            title: "接受",
            options: []
        )
        let friendRejectAction = UNNotificationAction(
            identifier: NotificationAction.rejectFriend.rawValue,
            title: "拒绝",
            options: []
        )
        let friendCategory = UNNotificationCategory(
            identifier: NotificationType.friend.categoryIdentifier,
            actions: [friendAcceptAction, friendRejectAction],
            intentIdentifiers: []
        )
        categories.insert(friendCategory)
        
        // 计划通知类别（一般只需要查看）
        let planCategory = UNNotificationCategory(
            identifier: NotificationType.plan.categoryIdentifier,
            actions: [],
            intentIdentifiers: []
        )
        categories.insert(planCategory)
        
        // 注册所有类别
        notificationCategories = categories
        UNUserNotificationCenter.current().setNotificationCategories(categories)
        
        print("📋 通知类别已设置: \(categories.count)个类别")
    }
    
    // MARK: - Notification Handling
    
    /// 处理前台通知
    public func handleForegroundNotification(_ notification: UNNotification) {
        let notificationData = parseNotificationData(notification.request.content.userInfo)
        
        // 添加到历史记录
        addToHistory(notificationData)
        
        // 更新Badge数量
        incrementBadge()
        
        // 🆕 自动同步数据 - 无论用户是否点击都会执行
        Task {
            await syncDataFromNotification(notificationData)
        }
        
        print("📨 前台通知处理: \(notificationData.title ?? "无标题")")
    }
    
    /// 处理通知响应（用户点击或快捷操作）
    public func handleNotificationResponse(_ response: UNNotificationResponse) {
        let notificationData = parseNotificationData(response.notification.request.content.userInfo)
        let actionIdentifier = response.actionIdentifier
        
        print("👆 处理通知响应: \(actionIdentifier)")
        
        // 处理不同的操作
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            // 用户点击通知本身
            handleDefaultAction(notificationData)
        } else if let action = NotificationAction(rawValue: actionIdentifier) {
            // 用户点击快捷操作
            handleQuickAction(action, data: notificationData)
        }
        
        // 添加到历史记录（如果还没有）
        addToHistory(notificationData)
    }
    
    /// 处理默认动作（点击通知）
    private func handleDefaultAction(_ data: NotificationData) {
        // 发送导航事件
        let navigationInfo: [String: Any] = [
            "type": data.type.rawValue,
            "messageId": data.messageId ?? 0,
            "customData": data.customData
        ]
        
        NotificationCenter.default.post(
            name: .navigateFromNotification,
            object: nil,
            userInfo: navigationInfo
        )
        
        // 减少Badge数量（用户已查看）
        decrementBadge()
    }
    
    /// 处理快捷操作
    private func handleQuickAction(_ action: NotificationAction, data: NotificationData) {
        Task {
            do {
                switch action {
                case .acceptAgreement, .rejectAgreement:
                    try await handleAgreementAction(action, data: data)
                case .acceptFriend, .rejectFriend:
                    try await handleFriendAction(action, data: data)
                case .respondBeacon:
                    handleBeaconAction(data)
                }
                
                // 操作成功，减少Badge数量
                await MainActor.run {
                    decrementBadge()
                }
                
            } catch {
                print("❌ 快捷操作处理失败: \(error.localizedDescription)")
                // 可以显示错误提示
            }
        }
    }
    
    // MARK: - Quick Action Handlers
    
    /// 处理约定相关操作
    private func handleAgreementAction(_ action: NotificationAction, data: NotificationData) async throws {
        guard let messageId = data.messageId else {
            throw NotificationError.missingMessageId
        }
        
        let accepted = (action == .acceptAgreement)
        print("📋 \(accepted ? "接受" : "拒绝")约定: \(messageId)")
        
        // 这里应该调用业务API
        // try await AgreementService.respond(messageId: messageId, accepted: accepted)
        
        // 暂时只打印日志
        print("✅ 约定操作完成: \(accepted ? "已接受" : "已拒绝")")
    }
    
    /// 处理好友相关操作
    private func handleFriendAction(_ action: NotificationAction, data: NotificationData) async throws {
        guard let messageId = data.messageId else {
            throw NotificationError.missingMessageId
        }
        
        let accepted = (action == .acceptFriend)
        print("👥 \(accepted ? "接受" : "拒绝")好友请求: \(messageId)")
        
        // 这里应该调用业务API
        // try await FriendService.respond(messageId: messageId, accepted: accepted)
        
        // 暂时只打印日志
        print("✅ 好友操作完成: \(accepted ? "已接受" : "已拒绝")")
    }
    
    /// 处理信标操作
    private func handleBeaconAction(_ data: NotificationData) {
        print("🔥 回应信标: \(data.messageId ?? 0)")
        
        // 导航到信标详情页面
        let navigationInfo: [String: Any] = [
            "type": NotificationType.beacon.rawValue,
            "messageId": data.messageId ?? 0,
            "action": "respond"
        ]
        
        NotificationCenter.default.post(
            name: .navigateFromNotification,
            object: nil,
            userInfo: navigationInfo
        )
    }
    
    // MARK: - Data Parsing
    
    /// 解析通知数据
    private func parseNotificationData(_ userInfo: [AnyHashable: Any]) -> NotificationData {
        let messageType = userInfo["messageType"] as? String ?? "unknown"
        let type = NotificationType(rawValue: messageType) ?? .plan
        
        return NotificationData(
            type: type,
            messageId: userInfo["messageId"] as? Int,
            title: userInfo["title"] as? String,
            content: userInfo["content"] as? String,
            senderNickname: userInfo["senderNickname"] as? String,
            customData: userInfo,
            receivedAt: Date()
        )
    }
    
    // MARK: - Badge Management
    
    /// 增加Badge数量
    private func incrementBadge() {
        badgeCount += 1
        updateApplicationBadge()
        saveBadgeCount()
    }
    
    /// 减少Badge数量
    private func decrementBadge() {
        badgeCount = max(0, badgeCount - 1)
        updateApplicationBadge()
        saveBadgeCount()
    }
    
    /// 清除所有Badge
    public func clearBadge() {
        badgeCount = 0
        updateApplicationBadge()
        saveBadgeCount()
    }
    
    /// 更新应用Badge
    private func updateApplicationBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = self.badgeCount
        }
    }
    
    /// 保存Badge数量
    private func saveBadgeCount() {
        UserDefaults.standard.set(badgeCount, forKey: "notificationBadgeCount")
    }
    
    /// 加载Badge数量
    private func loadBadgeCount() {
        badgeCount = UserDefaults.standard.integer(forKey: "notificationBadgeCount")
        updateApplicationBadge()
    }
    
    // MARK: - History Management
    
    /// 添加到历史记录
    private func addToHistory(_ data: NotificationData) {
        // 检查是否已存在
        if !notificationHistory.contains(where: { $0.id == data.id }) {
            notificationHistory.insert(data, at: 0)
            
            // 限制历史记录数量
            if notificationHistory.count > maxHistoryCount {
                notificationHistory.removeLast()
            }
            
            saveNotificationHistory()
        }
    }
    
    /// 清除历史记录
    public func clearHistory() {
        notificationHistory.removeAll()
        saveNotificationHistory()
    }
    
    /// 清除通知历史 (UI兼容方法)
    public func clearNotificationHistory() {
        clearHistory()
    }
    
    /// 移除特定通知记录 (UI兼容方法)
    /// - Parameter recordId: 要移除的记录ID
    public func removeNotificationRecord(_ recordId: UUID) {
        notificationHistory.removeAll { $0.id == recordId }
        saveNotificationHistory()
        print("🗑️ 已移除通知记录: \(recordId)")
    }
    
    /// 保存通知历史记录
    private func saveNotificationHistory() {
        if let encoded = try? JSONEncoder().encode(notificationHistory) {
            UserDefaults.standard.set(encoded, forKey: "notificationHistory")
        }
    }
    
    /// 加载通知历史记录
    private func loadNotificationHistory() {
        guard let data = UserDefaults.standard.data(forKey: "notificationHistory"),
              let history = try? JSONDecoder().decode([NotificationData].self, from: data) else {
            return
        }
        notificationHistory = history
    }
    
    // MARK: - Data Synchronization
    
    /// 根据推送通知同步相关数据
    /// - Parameter data: 通知数据
    private func syncDataFromNotification(_ data: NotificationData) async {
        guard let messageId = data.messageId else {
            print("⚠️ 推送缺少messageId，跳过数据同步")
            return
        }
        
        print("🔄 开始同步推送数据: \(data.type.displayName)(\(messageId))")
        
        do {
            switch data.type {
            case .beacon, .plan, .agreement:
                // 同步活动数据
                try await syncActivityData(activityId: messageId)
                
            case .friend:
                // 同步好友数据
                try await syncFriendData()
            }
            
            // 🆕 通知APP内部页面数据已更新
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .dataUpdatedFromPush,
                    object: data
                )
            }
            
            print("✅ 推送数据同步完成: \(data.type.displayName)(\(messageId))")
            
        } catch {
            print("❌ 推送数据同步失败: \(error.localizedDescription)")
        }
    }
    
    /// 同步活动数据
    private func syncActivityData(activityId: Int) async throws {
        // TODO: 这里需要调用ActivityClient或ActivityService
        // 由于NotificationHandler在UserKit中，需要通过协议或通知机制与业务层通信
        print("🔄 同步活动数据: \(activityId)")
        
        // 方案：通过NotificationCenter通知业务层同步数据
        await MainActor.run {
            NotificationCenter.default.post(
                name: .syncActivityData,
                object: nil,
                userInfo: ["activityId": activityId]
            )
        }
    }
    
    /// 同步好友数据
    private func syncFriendData() async throws {
        print("🔄 同步好友数据")
        
        // 方案：通过NotificationCenter通知业务层同步数据
        await MainActor.run {
            NotificationCenter.default.post(
                name: .syncFriendData,
                object: nil
            )
        }
    }
}

// MARK: - Data Models

/// 通知类型
public enum NotificationType: String, CaseIterable, Codable {
    case plan = "plan"
    case beacon = "beacon" 
    case agreement = "agreement"
    case friend = "friend"
    
    var categoryIdentifier: String {
        return "BEACONFLOW_\(rawValue.uppercased())"
    }
    
    var displayName: String {
        switch self {
        case .plan: return "计划"
        case .beacon: return "信标"
        case .agreement: return "约定"
        case .friend: return "好友"
        }
    }
}

/// 通知快捷操作
public enum NotificationAction: String, CaseIterable {
    case acceptAgreement = "ACCEPT_AGREEMENT"
    case rejectAgreement = "REJECT_AGREEMENT"
    case acceptFriend = "ACCEPT_FRIEND"
    case rejectFriend = "REJECT_FRIEND"
    case respondBeacon = "RESPOND_BEACON"
}

/// 通知数据模型
public struct NotificationData: Identifiable, Codable {
    public let id = UUID()
    public let type: NotificationType
    public let messageId: Int?
    public let title: String?
    public let content: String?
    public let senderNickname: String?
    public let customData: [AnyHashable: Any]
    public let receivedAt: Date
    
    // Codable支持
    private enum CodingKeys: String, CodingKey {
        case type, messageId, title, content, senderNickname, receivedAt
    }
    
    public init(type: NotificationType, messageId: Int?, title: String?, content: String?, senderNickname: String?, customData: [AnyHashable: Any], receivedAt: Date) {
        self.type = type
        self.messageId = messageId
        self.title = title
        self.content = content
        self.senderNickname = senderNickname
        self.customData = customData
        self.receivedAt = receivedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(NotificationType.self, forKey: .type)
        messageId = try container.decodeIfPresent(Int.self, forKey: .messageId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        senderNickname = try container.decodeIfPresent(String.self, forKey: .senderNickname)
        receivedAt = try container.decode(Date.self, forKey: .receivedAt)
        customData = [:] // 解码时不包含customData
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(messageId, forKey: .messageId)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(senderNickname, forKey: .senderNickname)
        try container.encode(receivedAt, forKey: .receivedAt)
    }
}

/// 通知错误类型
public enum NotificationError: LocalizedError {
    case missingMessageId
    case invalidNotificationData
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .missingMessageId:
            return "通知缺少消息ID"
        case .invalidNotificationData:
            return "通知数据格式无效"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 从通知导航事件
    public static let navigateFromNotification = Notification.Name("NavigateFromNotification")
    
    /// 推送数据更新完成事件
    public static let dataUpdatedFromPush = Notification.Name("DataUpdatedFromPush")
    
    /// 同步活动数据请求
    public static let syncActivityData = Notification.Name("SyncActivityData")
    
    /// 同步好友数据请求
    public static let syncFriendData = Notification.Name("SyncFriendData")
}