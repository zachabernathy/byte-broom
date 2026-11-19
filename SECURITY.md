# Security Policy

## Supported versions

Only the latest release gets security fixes.

| Version | Supported |
| --- | --- |
| Latest release | Yes |
| Older releases | No |

## Reporting a vulnerability

Please report security problems privately through GitHub's [Report a vulnerability](https://github.com/zachabernathy/byte-broom/security/advisories/new) form. Don't open a public issue.

Include:

- What the problem is and what someone could do with it.
- Steps to reproduce, or a proof of concept.
- Your Byte Broom version (Byte Broom > About Byte Broom) and macOS version.

Byte Broom is maintained by one person in their spare time, so responses are best effort, usually within a week. I'll let you know when a fix is released and credit you in the release notes if you'd like.

## Scope

Byte Broom only reads file names, sizes, and dates in the Desktop, Documents, Downloads, Movies, Music, and Pictures folders, and it only moves files to the Trash when you select them and confirm. It never deletes files permanently. It only connects to the internet when you choose Byte Broom > Check for Updates, which sends one request to the GitHub API.
