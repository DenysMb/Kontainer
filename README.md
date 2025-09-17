# Kontainer
A simple Kirigami GUI for Distrobox

![Kontainer](https://github.com/user-attachments/assets/1273dade-5026-4ffb-b5d1-4f5a332ba0af)

### Installation:

<a href='https://flathub.org/apps/io.github.DenysMb.Kontainer'><img width='240' alt='Download on Flathub' src='https://flathub.org/assets/badges/flathub-badge-en.png'/></a>

### Build instructions

Debug (recommended for development):

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j
```

Run:

```bash
./build/bin/kontainer
```

Release (optional):

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build
```

### Requirements:
Those are required even for Flatpak version:
- Distrobox
- A terminal emulator

### Functionalities:
- Create, delete and upgrade distroboxes;
- Open terminal inside distroboxes;
- Create shortcut for distroboxes;
- Install files inside distroboxes.


### Screenshots

![Screenshot_20250508_193522](https://github.com/user-attachments/assets/3d1204d9-18e0-4c0d-a188-cf8eb1c3adfd)
![Screenshot_20250508_193559](https://github.com/user-attachments/assets/61d1deb0-2ee8-47d4-b059-bbf301749e91)
![Screenshot_20250508_193616](https://github.com/user-attachments/assets/f5eb2268-ceba-451c-abe5-f6794de70ee0)
![Screenshot_20250508_193644](https://github.com/user-attachments/assets/2fe98ce4-8898-4d3e-a793-021a4af1db4b)


> Icon by [@Micro856](https://github.com/Micro856). Thank you for the contribution!
