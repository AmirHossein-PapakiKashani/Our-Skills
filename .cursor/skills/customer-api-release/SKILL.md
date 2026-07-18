---
name: customer-api-release
description: Publish and package the Elay Customer API for release. Use when the user asks in Persian or English to publish, build a release, package, archive, or create a RAR for the Customer API, including requests such as "پابلیش بگیر" or "release بگیر".
---

# Customer API Release

Read `Customer/Api/Docs/CustomerApiPublishAndPackage.md` before acting.

Follow this sequence exactly:

1. Confirm that the request authorizes clearing `D:\Release`; preserve the folder itself.
2. Resolve and verify both `D:\Release` and `Customer/Api` before deletion.
3. Clear only the contents of `D:\Release`.
4. Run the Customer API publish command with `-c Release`, `-o D:\Release`, and `--no-self-contained`.
5. Verify that `D:\Release\Api.dll` and `D:\Release\Api.exe` exist.
6. Use WinRAR to create the archive outside Release, then move it to `D:\Release\Release.rar`; this prevents the archive from containing itself.
7. Run `WinRAR t` on the final archive and report its path and result.

Use RTK for every shell command in this repository. Do not delete release contents without explicit user authorization. Do not publish to another folder unless the user explicitly changes the destination.
