import SwiftUI
import AppKit
import Foundation

public struct GitHubReleaseInfo: Codable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String?
    public let assets: [GitHubReleaseAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}
