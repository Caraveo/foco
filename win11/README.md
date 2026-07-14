# Foco View for Windows 11

This is the native, read-only Windows 11 reader for Foco `.bulb` documents. It uses WinUI 3 and the Windows App SDK, keeps every document local, and never writes to the source bulb.

## Features

- Opens `.bulb` files from the picker or a command-line/file-association argument
- Loads the manifest and selected page lazily
- Renders headings, paragraphs, quotes, prompts, lists, tasks, dividers, code, tables, and inline attachments
- Displays images and plays local video/audio with native controls
- Extracts attachments into an isolated temporary folder and removes them when the window closes
- Supports Windows light/dark themes and x64/ARM64

## Build

Requirements: Windows 11, Visual Studio 2022 with **.NET desktop development** and **Windows application development**, and the .NET 8 SDK.

1. Open `FocoView.Win11.sln` in Visual Studio.
2. Select `x64` or `ARM64`.
3. Build and run `FocoView.Win11`.

The project is unpackaged and self-contained for straightforward local testing. To make `.bulb` files open on double-click, package the app as MSIX and declare a `windows.fileTypeAssociation` for `.bulb`, or associate `.bulb` with the built executable in Windows Settings. The app accepts a bulb path as its first command-line argument.

PDF and arbitrary file attachments are opened with the user's default Windows application; images, video, and audio render inline.
