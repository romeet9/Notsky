import Foundation
import SwiftUI
import Observation

public struct WorkspaceData: Codable {
    public var notes: [NoteCard]
    public var folders: [NoteFolder]?
    
    public init(notes: [NoteCard], folders: [NoteFolder]?) {
        self.notes = notes
        self.folders = folders
    }
}
