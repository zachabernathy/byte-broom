public enum FileCategory: String, CaseIterable, Sendable, Hashable {
    case documents = "Documents"
    case videos = "Videos"
    case images = "Images"
    case audio = "Audio"
    case installers = "Installers"
    case archives = "Archives"
    case apps = "Apps"
    case other = "Other"
}

private let table: [FileCategory: String] = [
    .documents: "pdf doc docx txt rtf rtfd md pages numbers key xls xlsx csv ppt pptx odt ods odp epub",
    .videos: "mp4 mov m4v avi mkv webm wmv flv mpg mpeg mxf braw fcpbundle imovielibrary",
    .images: "jpg jpeg png gif heic heif webp tif tiff bmp svg dng cr2 cr3 nef arw psd ai photoslibrary",
    .audio: "mp3 wav aac m4a flac aif aiff ogg musiclibrary logicx band",
    .installers: "dmg pkg mpkg iso",
    .archives: "zip tar gz tgz bz2 xz 7z rar",
    .apps: "app",
]

private let categoryByExtension: [String: FileCategory] = table.reduce(into: [:]) { result, entry in
    for ext in entry.value.split(separator: " ") { result[String(ext)] = entry.key }
}

private let bundleExtensions: Set<String> = [
    "app", "photoslibrary", "musiclibrary", "fcpbundle", "imovielibrary",
    "logicx", "band", "pages", "numbers", "key", "rtfd",
]

/// Lowercased final extension, matching Python's `os.path.splitext`: leading dots don't start one.
private func fileExtension(_ name: String) -> String {
    let stem = name.drop(while: { $0 == "." })
    guard let dot = stem.lastIndex(of: ".") else { return "" }
    return stem[stem.index(after: dot)...].lowercased()
}

public func category(forName name: String) -> FileCategory {
    categoryByExtension[fileExtension(name)] ?? .other
}

public func isBundle(name: String) -> Bool {
    bundleExtensions.contains(fileExtension(name))
}
