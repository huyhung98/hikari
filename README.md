# Hikari (光) - Display Manager for macOS

**Hikari** is a lightweight, premium macOS menu bar application designed for advanced display control, specifically optimized for Apple Silicon (M1/M2/M3) and modern Intel Macs.

<p align="center">
  <img src="https://i.ibb.co/3YyV3BhH/Screenshot-2026-01-17-at-21-00-33.png" alt="Hikari Preview" width="600">
</p>

## Key Features

-   **Native Hardware Brightness**: Controls actual hardware brightness for internal displays using private APIs (no more "soft" filters for your main screen).
-   **Software DDC/CI Overlay**: Smooth software-based dimming for external displays where hardware DDC is unavailable or unreliable.
-   **Software Clamshell Mode**: Logically disable your internal display without closing the lid. Windows automatically migrate to external monitors, just like a real clamshell.
-   **Safety Recovery**: Automatically re-enable the built-in display if you unplug all external monitors, ensuring you're never caught with a black screen.
-   **Modern Resolution Control**: Switch resolutions and refresh rates directly from the menu bar.
-   **Launch at Login**: Simple toggle to stay running across reboots (macOS 13+).
-   **Premium UI**: A sleek, card-based interface with native SF Symbols and green-tinted active states.

## System Requirements

-   **OS**: macOS 13.0 (Ventura) or later.
-   **Architecture**: Universal (Apple Silicon & Intel).

## Installation

1.  Go to the [Releases](https://github.com/huyhung98/hikari/releases) page.
2.  Download the latest `Hikari.zip` (or `.dmg` if available).
3.  Drag `Hikari.app` to your `/Applications` folder.
4.  Open `Hikari.app`.

## Build from Source

If you prefer to build Hikari yourself:

1.  Clone the repository.
2.  Open Terminal in the project folder.
3.  Run the build and bundle command:
    ```bash
    swift build && ./bundle.sh
    ```
4.  Copy the generated `Hikari.app` to your `/Applications` folder.

## Implementation Details

-   **Private Frameworks**: Utilizes `DisplayServices` and `SkyLight` for deep integration with macOS display management.
-   **IOKit**: Used for DDC/CI communication on M1 and legacy Intel brightness control.
-   **SwiftUI**: Modern, declarative UI used for the menu bar popover.

## License

MIT - See [LICENSE](LICENSE) for details. (Note: Please add a LICENSE file if desired.)
