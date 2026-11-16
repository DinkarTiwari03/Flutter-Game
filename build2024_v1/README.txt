======================================================================
City Builder 2040 - Release Package (build2024_v1)
======================================================================

Directory Location:
c:\Flutter_Game\build2024_v1\

Package Contents:
1. CityBuilder2040-v1.0.apk (24.3 MB)
   - Fully compiled standalone release APK for Android.
   - Installable on Android phones, tablets, or emulators.

2. build_windows_app.bat
   - One-click script to build and place the native Windows executable into this folder.

----------------------------------------------------------------------
HOW TO FINISH WINDOWS APP INSTALLATION
----------------------------------------------------------------------
Flutter requires Microsoft Visual Studio with the "Desktop development with C++" workload
to compile the native Windows .exe runner.

Currently on your system:
- Visual Studio Installer is present at:
  C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe
- A previous installation of Visual Studio Build Tools 2019 was interrupted/incomplete.

Steps to enable Windows compilation:
1. Open the Start Menu and search for "Visual Studio Installer".
2. On your installed instance (Visual Studio Build Tools or Community), click "Modify".
3. Under the "Workloads" tab, check:
   [x] Desktop development with C++
   (Ensure MSVC v142/v143, Windows 10/11 SDK, and C++ CMake tools are selected)
4. Click "Install" / "Modify" and let it finish.
5. Double-click "build_windows_app.bat" in this folder (or run `flutter build windows --release`).

The standalone `city_builder_2040.exe` and its dependencies will be compiled
and saved directly inside this `build2024_v1` folder!
======================================================================
