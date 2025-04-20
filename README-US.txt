CustomWindowsISO.ps1
====================

Description:
------------
This PowerShell script allows you to create a customized Windows ISO image.
It automates tasks such as integrating updates and drivers, removing unnecessary components, and applying system customizations.

Features:
---------
- Mount a Windows image (WIM)
- Integrate files or scripts into the image
- Clean up unwanted components
- Build a new bootable ISO image

Requirements:
-------------
- Windows 10 or newer
- PowerShell (run as Administrator)
- DISM and oscdimg must be available on the system

Usage:
------
1. Place the original Windows ISO in the folder specified by the script.
2. Run the PowerShell script as administrator:
   `.\CustomWindowsISO.ps1`
3. Follow the instructions displayed in the terminal.

Notes:
------
- It is recommended to test the customized ISO in a virtual machine before using it on a physical device.
- You can modify the script to include custom files, registry tweaks, or applications according to your needs.

Author:
-------
Silenty - 2025
