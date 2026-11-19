import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Getting started", "sparkles") {
                        Text("Byte Broom looks through the Desktop, Documents, Downloads, Movies, Music, and Pictures folders in your home folder and lists the files it finds, biggest first. It scans when it opens. To scan again, click Rescan in the toolbar or choose File > Rescan (⌘R).")
                        Text("Hidden files are skipped. Apps, Photos and Music libraries, and some other packages, such as Pages documents and Final Cut libraries, are listed as one item with their total size.")
                    }
                    section("Finding files", "magnifyingglass") {
                        Text("The sidebar groups files by type: Documents, Videos, Images, Audio, Installers, Archives, Apps, and Other. Choose All to see every file. Each type shows how many files match and their total size.")
                        Text("Click a column header to sort by name, size, date created, date modified, or folder. Click it again to reverse the order.")
                        Text("Use the menus in the toolbar to show only one folder, files over a minimum size, or files created more than a set time ago. The search field matches file names.")
                        Text("Double-click a file, or right-click it and choose Show in Finder, to see it in Finder.")
                    }
                    section("Moving files to the Trash", "trash") {
                        Text("Tick the box next to each file you want to remove. You can also select rows and choose Mark from the right-click menu. Mark all shown ticks every file in the list, and Clear marks unticks all of them. Marks stay when you change the type, filters, or search.")
                        Text("Click Move to Trash at the bottom of the window, then confirm. Byte Broom never deletes files permanently. It moves them to the Trash, and they stay there until you empty it.")
                        Text("To get a file back, open the Trash in Finder, select the file, and choose File > Put Back.")
                    }
                    section("Folder access", "lock") {
                        Text("macOS asks before an app can read some folders, such as Desktop, Documents, and Downloads. Click Allow when Byte Broom asks.")
                        Text("If you clicked Don't Allow, Byte Broom shows which folders it couldn't read. Open System Settings > Privacy & Security > Files and Folders, turn on those folders for Byte Broom, then click Rescan (⌘R).")
                    }
                    section("Photos library size", "photo.on.rectangle") {
                        Text("Your Photos library is listed as one item under Images. macOS protects what's inside it, so without Full Disk Access Byte Broom shows a smaller size than the real one.")
                        Text("To see the real size, turn on Byte Broom in System Settings > Privacy & Security > Full Disk Access, then quit and reopen Byte Broom. Moving the Photos library to the Trash moves your whole library, so only do it if you mean to.")
                    }
                    section("Opening Byte Broom the first time", "checkmark.shield") {
                        Text("Byte Broom doesn't come from the Mac App Store, so the first time you open it macOS may refuse to open it. Close the message, then open System Settings > Privacy & Security, scroll down, and click Open Anyway next to the note about Byte Broom. Confirm, and macOS remembers your choice.")
                        Text("Or, in Terminal, run:")
                        Text(#"xattr -dr com.apple.quarantine "/Applications/Byte Broom.app""#)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                    section("Privacy", "hand.raised") {
                        Text("Byte Broom has no analytics and no accounts. It reads file names, sizes, and dates, and that list never leaves your Mac.")
                        Text("It only connects to the internet when you choose Byte Broom > Check for Updates, which asks GitHub for the latest version number. Links in this window and in the Help menu open in your browser.")
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button("Report an Issue") { Links.open(Links.newIssue) }
                Button("View on GitHub") { Links.open(Links.repo) }
                Spacer()
            }
            .padding(12)
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    private func section(_ title: String, _ symbol: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline).accessibilityAddTraits(.isHeader)
            content().fixedSize(horizontal: false, vertical: true)
        }
    }
}
