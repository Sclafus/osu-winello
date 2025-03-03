#!/usr/bin/env bash

#   =======================================
#   Welcome to Winello!
#   The whole script is divided in different
#   functions to make it easier to read.
#   Feel free to contribute!
#   =======================================

# Proton-osu current versions for update
MAJOR=9
MINOR=15
PATCH=1
PROTONVERSION=$MAJOR.$MINOR.$PATCH
LASTPROTONVERSION=0

# Proton-osu mirrors
PROTONLINK="https://github.com/whrvt/umubuilder/releases/download/proton-osu-$MAJOR-$MINOR/proton-osu-$MAJOR-$MINOR.tar.xz"


#   =====================================
#   =====================================
#           INSTALLER FUNCTIONS
#   =====================================
#   =====================================


# Simple echo function (but with cool text e.e)
function Info(){
    echo -e '\033[1;34m'"Winello:\033[0m $*";
}

function Warning(){
    echo -e '\033[0;33m'"Winello (WARNING):\033[0m $*";
}

# Function to quit the install but not revert it in some cases
function Quit(){
    echo -e '\033[1;31m'"Winello:\033[0m $*"; exit 1;
}

# Function to revert the install in case of any type of fail
function Revert(){
    echo -e '\033[1;31m'"Reverting install...:\033[0m"
    rm -f "$HOME/.local/share/icons/osu-wine.png"
    rm -f "$HOME/.local/share/applications/osu-wine.desktop"
    rm -f "$HOME/.local/bin/osu-wine"
    rm -rf "$HOME/.local/share/osuconfig"
    rm -f "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"
    rm -f "/tmp/osu-mime.tar.xz"
    rm -rf "/tmp/osu-mime"
    rm -f "$HOME/.local/share/mime/packages/osuwinello-file-extensions.xml"
    rm -f "$HOME/.local/share/applications/osuwinello-file-extensions-handler.desktop"
    rm -f "$HOME/.local/share/applications/osuwinello-url-handler.desktop"
    rm -f "/tmp/winestreamproxy-2.0.3-amd64.tar.xz"
    rm -rf "/tmp/winestreamproxy"
    echo -e '\033[1;31m'"Reverting done, try again with ./osu-winello.sh\033[0m"
}


# Error function pointing at Revert(), but with an appropriate message
function Error(){
    echo -e '\033[1;31m'"Script failed:\033[0m $*"; Revert ; exit 1;
}


# Function looking for basic stuff needed for installation
function InitialSetup(){

    # Better to not run the script as root, right?
    if [ "$USER" = "root" ] ; then Error "Please run the script without root" ; fi

    # Checking for previous versions of osu-wine (mine or DiamondBurned's)
    if [ -e /usr/bin/osu-wine ] ; then Quit "Please uninstall old osu-wine (/usr/bin/osu-wine) before installing!"; fi
    if [ -e "$HOME/.local/bin/osu-wine" ] ; then Quit "Please uninstall Winello (osu-wine --remove) before installing!" ; fi

    Info "Welcome to the script! Follow it to install osu! 8)"

    # Setting root perms. to either 'sudo' or 'doas'
    root_var="sudo"
    if command -v doas >/dev/null 2>&1 ; then
        doascheck=$(doas id -u)
        if [ "$doascheck" = "0" ] ; then 
            root_var="doas"
        fi
    fi

    # Checking if ~/.local/bin is in PATH:
    mkdir -p "$HOME/.local/bin"
    pathcheck=$(echo "$PATH" | grep -q "$HOME/.local/bin" && echo "y")

    # If ~/.local/bin is not in PATH:
    if [ "$pathcheck" != "y" ] ; then
        
        if grep -q "bash" "$SHELL" ; then
            touch -a "$HOME/.bashrc"
            echo "export PATH=$HOME/.local/bin:$PATH" >> "$HOME/.bashrc"
        fi

        if grep -q "zsh" "$SHELL" ; then
            touch -a "$HOME/.zshrc"
            echo "export PATH=$HOME/.local/bin:$PATH" >> "$HOME/.zshrc"
        fi

        if grep -q "fish" "$SHELL" ; then
            mkdir -p "$HOME/.config/fish" && touch -a "$HOME/.config/fish/config.fish"
            fish_add_path ~/.local/bin/
        fi
    fi

    # Well, we do need internet ig...
    Info "Checking for internet connection.."
    ! ping -c 1 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 google.com >/dev/null 2>&1 && Error "Please connect to internet before continuing xd. Run the script again"

    # Looking for dependencies..
    deps=(wget zenity unzip)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1 ; then
            Error "Please install $dep before continuing!"
        fi
    done

    # Ubuntu/Debian Hotfix: Install Steam as it is apparently needed from drivers to work with Proton
    if $root_var apt update; then
        Info "Ubuntu/Debian-based distro detected.."
        Info "Please insert your password to install dependencies!"
        $root_var dpkg --add-architecture i386
        $root_var apt install libgl1-mesa-dri libgl1-mesa-dri:i386 steam -y || Error "Dependencies install failed, check apt or your connection.."
    fi

    # Ubuntu 24.x hotfix: Workaround umu-run not working due to apparmor restrictions
    # for bwrap, you can read more at here: https://etbe.coker.com.au/2024/04/24/ubuntu-24-04-bubblewrap/
    if grep -q '^NAME="Ubuntu"$' /etc/os-release && grep -q '^VERSION_ID="24\.' /etc/os-release && [ ! -f /etc/apparmor.d/bwrap ] ; then
        Info "Ubuntu 24 detected: due to apparmor restrictions, osu! (umu-run) needs a workaround to launch properly.."
        Info "Please enter your password if prompted if you need to fix it!"
        read -r -p "$(Info "Do you want to enable it? (y/N): ")" apparmorx

        if [ "$apparmorx" = 'y' ] || [ "$apparmorx" = 'Y' ]; then

echo "abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,

  # Site-specific additions and overrides. See local/README for details.
  include if exists <local/bwrap>
}" | $root_var tee /etc/apparmor.d/bwrap > /dev/null
            
            $root_var systemctl reload apparmor
            Info "umu-run workaround now applied!"

        else        
            Info "Skipping.."
        fi
    fi
}

# Function to install script files, umu-launcher and Proton-osu
function InstallProton(){
    
    Info "Installing game script:"
    cp ./osu-wine "$HOME/.local/bin/osu-wine" && chmod +x "$HOME/.local/bin/osu-wine"

    Info "Installing icons:"
    mkdir -p "$HOME/.local/share/icons"    
    cp "./stuff/osu-wine.png" "$HOME/.local/share/icons/osu-wine.png" && chmod 644 "$HOME/.local/share/icons/osu-wine.png"

    Info "Installing .desktop:"
    mkdir -p "$HOME/.local/share/applications"
    echo "[Desktop Entry]
Name=osu!
Comment=osu! - Rhythm is just a *click* away!
Type=Application
Exec=$HOME/.local/bin/osu-wine %U
Icon=$HOME/.local/share/icons/osu-wine.png
Terminal=false
Categories=Wine;Game;" | tee "$HOME/.local/share/applications/osu-wine.desktop" >/dev/null
    chmod +x "$HOME/.local/share/applications/osu-wine.desktop"

    if [ -d "$HOME/.local/share/osuconfig" ]; then
        Info "Skipping osuconfig.."
    else
        mkdir "$HOME/.local/share/osuconfig"
    fi

    Info "Installing Proton-osu:"
    # Downloading Proton..
    wget -O "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz" "$PROTONLINK" && chk="$?"
    if [ ! "$chk" = 0 ] ; then
        Info "wget failed; trying with --no-check-certificate.."
        wget --no-check-certificate -O "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz" "$PROTONLINK" || Error "Download failed, check your connection" 
    fi

    # This will extract Proton-osu and set last version to the one downloaded
    tar -xf "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz" -C "$HOME/.local/share/osuconfig"
    LASTPROTONVERSION="$PROTONVERSION"
    rm -f "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"

    # The update function works under this folder: it compares variables from files stored in osuconfig 
    # with latest values from GitHub and check whether to update or not
    Info "Installing script copy for updates.."
    mkdir -p "$HOME/.local/share/osuconfig/update"
    git clone https://github.com/NelloKudo/osu-winello.git "$HOME/.local/share/osuconfig/update" || Error "Git failed, check your connection.."
    echo "$LASTPROTONVERSION" >> "$HOME/.local/share/osuconfig/protonverupdate"

    ## Setting up umu-launcher from the Proton package
    Info "Setting up umu-launcher.."
    UMU_RUN="$HOME/.local/share/osuconfig/proton-osu/umu-run"
    export GAMEID="umu-727"
}

# Function configuring folders to install the game
function ConfigurePath(){
    
    Info "Configuring osu! folder:"
    Info "Where do you want to install the game?: 
          1 - Default path (~/.local/share/osu-wine)
          2 - Custom path"
    read -r -p "$(Info "Choose your option: ")" installpath
    
    if [ "$installpath" = 1 ] || [ "$installpath" = 2 ] ; then  
    
        case "$installpath" in
        
        '1')  
            
            mkdir -p "$HOME/.local/share/osu-wine"
            GAMEDIR="$HOME/.local/share/osu-wine"
            
            if [ -d "$GAMEDIR/OSU" ]; then
                OSUPATH="$GAMEDIR/OSU"
                echo "$OSUPATH" > "$HOME/.local/share/osuconfig/osupath"
            else
                mkdir -p "$GAMEDIR/osu!"
                OSUPATH="$GAMEDIR/osu!"
                echo "$OSUPATH" > "$HOME/.local/share/osuconfig/osupath"
            fi
        ;;
        
        '2')
        
            Info "Choose your directory: "
            GAMEDIR="$(zenity --file-selection --directory)"
        
            if [ -e "$GAMEDIR/osu!.exe" ]; then
                OSUPATH="$GAMEDIR"
                echo "$OSUPATH" > "$HOME/.local/share/osuconfig/osupath" 
            else
                mkdir -p "$GAMEDIR/osu!"
                OSUPATH="$GAMEDIR/osu!"
                echo "$OSUPATH" > "$HOME/.local/share/osuconfig/osupath"
            fi
        ;;
     
        esac

    else
    
        Info "No option chosen, installing to default.. (~/.local/share/osu-wine)"

        mkdir -p "$HOME/.local/share/osu-wine"
        GAMEDIR="$HOME/.local/share/osu-wine"
        
        if [ -d "$GAMEDIR/OSU" ]; then
            OSUPATH="$GAMEDIR/OSU"
            echo "$OSUPATH" > "$HOME/.local/share/osuconfig/osupath"
        else
            mkdir -p "$GAMEDIR/osu!"
            OSUPATH="$GAMEDIR/osu!"
            echo "$OSUPATH" > "$HOME/.local/share/osuconfig/osupath"
        fi

    fi
}

# Here comes the real Winello 8)
# What the script will install, in order, is:
# - osu!mime and osu!handler to properly import skins and maps
# - Wineprefix
# - Regedit keys to integrate native file manager with Wine
# - rpc-bridge for Discord RPC (flatpak users, google "flatpak discord rpc")

function FullInstall(){

    Info "Configuring osu-mime and osu-handler:"

    # Installing osu-mime from https://aur.archlinux.org/packages/osu-mime
    wget -O "/tmp/osu-mime.tar.gz" "https://aur.archlinux.org/cgit/aur.git/snapshot/osu-mime.tar.gz" && chk="$?"
    
    if [ ! "$chk" = 0 ] ; then
        Info "wget failed; trying with --no-check-certificate.."
        wget --no-check-certificate -O "/tmp/osu-mime.tar.gz" "https://aur.archlinux.org/cgit/aur.git/snapshot/osu-mime.tar.gz" || Error "Download failed, check your connection or open an issue here: https://github.com/NelloKudo/osu-winello/issues"
    fi
    
    tar -xf "/tmp/osu-mime.tar.gz" -C "/tmp"
    mkdir -p "$HOME/.local/share/mime/packages"
    cp "/tmp/osu-mime/osu-file-extensions.xml" "$HOME/.local/share/mime/packages/osuwinello-file-extensions.xml"
    update-mime-database "$HOME/.local/share/mime"
    rm -f "/tmp/osu-mime.tar.gz"
    rm -rf "/tmp/osu-mime"
    
    # Installing osu-handler from https://github.com/openglfreak/osu-handler-wine / https://aur.archlinux.org/packages/osu-handler
    # Binary was compiled from source on Ubuntu 18.04
    wget -O "$HOME/.local/share/osuconfig/osu-handler-wine" "https://github.com/NelloKudo/osu-winello/raw/main/stuff/osu-handler-wine" && chk="$?"
    
    if [ ! "$chk" = 0 ] ; then
        Info "wget failed; trying with --no-check-certificate.."
        wget --no-check-certificate -O "$HOME/.local/share/osuconfig/osu-handler-wine" "https://github.com/NelloKudo/osu-winello/raw/main/stuff/osu-handler-wine" || Error "Download failed, check your connection or open an issue here: https://github.com/NelloKudo/osu-winello/issues"
    fi
    
    chmod +x "$HOME/.local/share/osuconfig/osu-handler-wine"

    # Creating entries for those two
    echo "[Desktop Entry]
Type=Application
Name=osu!
MimeType=application/x-osu-skin-archive;application/x-osu-replay;application/x-osu-beatmap-archive;
Exec=$HOME/.local/bin/osu-wine --osuhandler %f
NoDisplay=true
StartupNotify=true
Icon=$HOME/.local/share/icons/osu-wine.png" | tee "$HOME/.local/share/applications/osuwinello-file-extensions-handler.desktop"
    chmod +x "$HOME/.local/share/applications/osuwinello-file-extensions-handler.desktop" >/dev/null

    echo "[Desktop Entry]
Type=Application
Name=osu!
MimeType=x-scheme-handler/osu;
Exec=$HOME/.local/bin/osu-wine --osuhandler %u
NoDisplay=true
StartupNotify=true
Icon=$HOME/.local/share/icons/osu-wine.png" | tee "$HOME/.local/share/applications/osuwinello-url-handler.desktop"
    chmod +x "$HOME/.local/share/applications/osuwinello-url-handler.desktop" >/dev/null
    update-desktop-database "$HOME/.local/share/applications"


    # Time to install my prepackaged Wineprefix, which works in most cases
    # The script is still bundled with osu-wine --fixprefix, which should do the job for me as well

    PREFIXLINK="https://gitlab.com/NelloKudo/osu-winello-prefix/-/raw/master/osu-winello-prefix.tar.xz"
    export PROTONPATH="$HOME/.local/share/osuconfig/proton-osu"

    Info "Configuring Wineprefix:"

    # Variable to check if download finished properly
    failprefix="false"

    mkdir -p "$HOME/.local/share/wineprefixes"
    if [ -d "$HOME/.local/share/wineprefixes/osu-wineprefix" ] ; then
        
        Info "Wineprefix already exists; do you want to reinstall it?"
        read -r -p "$(Info "Choose: (y/N)")" prefchoice
            
        if [ "$prefchoice" = 'y' ] || [ "$prefchoice" = 'Y' ]; then
            rm -rf "$HOME/.local/share/wineprefixes/osu-wineprefix"
        fi
    fi

    # So if there's no prefix (or the user wants to reinstall):
    if [ ! -d "$HOME/.local/share/wineprefixes/osu-wineprefix" ] ; then

        # Downloading prefix in temporary ~/.winellotmp folder
        # to make up for this issue: https://github.com/NelloKudo/osu-winello/issues/36
        mkdir -p "$HOME/.winellotmp"
        wget -O "$HOME/.winellotmp/osu-winello-prefix-umu.tar.xz" "$PREFIXLINK" && chk="$?"
    
        # If download failed:
        if [ ! "$chk" = 0 ] ; then
            Info "wget failed; trying with --no-check-certificate.."
            wget --no-check-certificate -O "$HOME/.winellotmp/osu-winello-prefix-umu.tar.xz" "$PREFIXLINK" || failprefix="true"
        fi     

        # Checking whether to create prefix manually or install it from repos
        if [ "$failprefix" = "true" ]; then
            WINEPREFIX="$HOME/.local/share/wineprefixes/osu-wineprefix" "$UMU_RUN" winetricks dotnet20 dotnet48 gdiplus_winxp win2k3
        else
            tar -xf "$HOME/.winellotmp/osu-winello-prefix-umu.tar.xz" -C "$HOME/.local/share/wineprefixes"
            mv "$HOME/.local/share/wineprefixes/osu-umu" "$HOME/.local/share/wineprefixes/osu-wineprefix" 
        fi 

        # Cleaning..
        rm -rf "$HOME/.winellotmp"

        # We're now gonna refer to this as Wineprefix
        export WINEPREFIX="$HOME/.local/share/wineprefixes/osu-wineprefix"

        # Time to debloat the prefix a bit and make necessary symlinks (drag and drop, long name maps/paths..)
        rm -rf "$WINEPREFIX/dosdevices"
        rm -rf "$WINEPREFIX/drive_c/users/nellokudo"
        mkdir -p "$WINEPREFIX/dosdevices"
        ln -s "$WINEPREFIX/drive_c/" "$WINEPREFIX/dosdevices/c:"
	    ln -s / "$WINEPREFIX/dosdevices/z:"
        ln -s "$OSUPATH" "$WINEPREFIX/dosdevices/d:"

        # Fix to importing maps/skins/osu links after Stable update 20250122.1: https://osu.ppy.sh/home/changelog/stable40/20250122.1
        # This assumes the osu! folder is mounted at the D: drive (which Winello does just a line above)
        REGFILE="$HOME/.local/share/osuconfig/osu-handler.reg"

cat > "${REGFILE}" << 'EOF'
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\osu]
@="URL:osu!"
"URL Protocol"=""

[HKEY_CLASSES_ROOT\osustable.File.osk]
@="osu! Skin"

[HKEY_CLASSES_ROOT\osustable.File.osk\DefaultIcon]
@="\"D:\\osu!.exe\",1"

[HKEY_CLASSES_ROOT\osustable.File.osk\Shell]

[HKEY_CLASSES_ROOT\osustable.File.osk\Shell\Open]

[HKEY_CLASSES_ROOT\osustable.File.osk\Shell\Open\Command]
@="\"D:\\osu!.exe\" \"%1\""

[HKEY_CLASSES_ROOT\osustable.File.osr]
@="osu! Replay"

[HKEY_CLASSES_ROOT\osustable.File.osr\DefaultIcon]
@="\"D:\\osu!.exe\",1"

[HKEY_CLASSES_ROOT\osustable.File.osr\Shell]

[HKEY_CLASSES_ROOT\osustable.File.osr\Shell\Open]

[HKEY_CLASSES_ROOT\osustable.File.osr\Shell\Open\Command]
@="\"D:\\osu!.exe\" \"%1\""

[HKEY_CLASSES_ROOT\osustable.File.osz]
@="osu! Beatmap"

[HKEY_CLASSES_ROOT\osustable.File.osz\DefaultIcon]
@="\"D:\\osu!.exe\",1"

[HKEY_CLASSES_ROOT\osustable.File.osz\Shell]

[HKEY_CLASSES_ROOT\osustable.File.osz\Shell\Open]

[HKEY_CLASSES_ROOT\osustable.File.osz\Shell\Open\Command]
@="\"D:\\osu!.exe\" \"%1\""

[HKEY_CLASSES_ROOT\osustable.File.osz2]
@="osu! Beatmap"

[HKEY_CLASSES_ROOT\osustable.File.osz2\DefaultIcon]
@="\"D:\\osu!.exe\",1"

[HKEY_CLASSES_ROOT\osustable.File.osz2\Shell]

[HKEY_CLASSES_ROOT\osustable.File.osz2\Shell\Open]

[HKEY_CLASSES_ROOT\osustable.File.osz2\Shell\Open\Command]
@="\"D:\\osu!.exe\" \"%1\""

[HKEY_CLASSES_ROOT\osustable.Uri.osu]

[HKEY_CLASSES_ROOT\osustable.Uri.osu\DefaultIcon]
@="\"D:\\osu!.exe\",1"

[HKEY_CLASSES_ROOT\osustable.Uri.osu\Shell]

[HKEY_CLASSES_ROOT\osustable.Uri.osu\Shell\Open]

[HKEY_CLASSES_ROOT\osustable.Uri.osu\Shell\Open\Command]
@="\"D:\\osu!.exe\" \"%1\""

[HKEY_CLASSES_ROOT\.osk]

[HKEY_CLASSES_ROOT\.osk\OpenWithProgIds]
"osustable.File.osk"=""

[HKEY_CLASSES_ROOT\.osr]

[HKEY_CLASSES_ROOT\.osr\OpenWithProgIds]
"osustable.File.osr"=""

[HKEY_CLASSES_ROOT\.osz]

[HKEY_CLASSES_ROOT\.osz\OpenWithProgIds]
"osustable.File.osz"=""

[HKEY_CLASSES_ROOT\.osz2]

[HKEY_CLASSES_ROOT\.osz2\OpenWithProgIds]
"osustable.File.osz2"=""

[HKEY_CLASSES_ROOT\osu]
@=-
"URL Protocol"=""

[HKEY_CLASSES_ROOT\osu\shell]

[HKEY_CLASSES_ROOT\osu\shell\open]

[HKEY_CLASSES_ROOT\osu\shell\open\command]
@="\"D:\\osu!.exe\" \"%1\""
EOF

        # Adding the osu-handler.reg file to registry
        "$UMU_RUN" regedit /s "${REGFILE}"

        # Integrating native file explorer by Maot: https://gist.github.com/maotovisk/1bf3a7c9054890f91b9234c3663c03a2
        # This only involves regedit keys.

        cp "./stuff/folderfixosu" "$HOME/.local/share/osuconfig/folderfixosu" && chmod +x "$HOME/.local/share/osuconfig/folderfixosu"
        "$UMU_RUN" reg add "HKEY_CLASSES_ROOT\folder\shell\open\command"
        "$UMU_RUN" reg delete "HKEY_CLASSES_ROOT\folder\shell\open\ddeexec" /f
        "$UMU_RUN" reg add "HKEY_CLASSES_ROOT\folder\shell\open\command" /f /ve /t REG_SZ /d "$HOME/.local/share/osuconfig/folderfixosu xdg-open \"%1\""

    fi

    # Installing rpc-bridge for Discord RPC (https://github.com/EnderIce2/rpc-bridge)

    if [ ! -d "$HOME/.local/share/wineprefixes/osu-wineprefix/drive_c/windows/bridge.exe" ] ; then
        Info "Configuring rpc-bridge (Discord RPC)"
        wget -O "/tmp/bridge.zip" "https://github.com/EnderIce2/rpc-bridge/releases/download/v1.2/bridge.zip" && chk="$?"
    
        if [ ! "$chk" = 0 ] ; then
            Info "wget failed; trying with --no-check-certificate.."
            wget --no-check-certificate -O "/tmp/bridge.zip" "https://github.com/EnderIce2/rpc-bridge/releases/download/v1.2/bridge.zip" || Error "Download failed, check your connection or open an issue here: https://github.com/NelloKudo/osu-winello/issues" 
        fi  

        mkdir -p /tmp/rpc-bridge
        unzip -d /tmp/rpc-bridge -q "/tmp/bridge.zip"
        "$UMU_RUN" /tmp/rpc-bridge/bridge.exe --install
        rm -f "/tmp/bridge.zip"
        rm -rf "/tmp/rpc-bridge"
    fi

    # Well...
    Info "Downloading osu!"
    if [ ! -s "$OSUPATH/osu!.exe" ]; then
        wget -O "$OSUPATH/osu!.exe" "http://m1.ppy.sh/r/osu!install.exe" && chk="$?"

        if [ ! "$chk" = 0 ] ; then
            Info "wget failed; trying with --no-check-certificate.."
            wget --no-check-certificate -O "$OSUPATH/osu!.exe" "http://m1.ppy.sh/r/osu!install.exe" || Error "Download failed, check your connection or open an issue here: https://github.com/NelloKudo/osu-winello/issues" 
        fi
    fi

    Check32

    Info "Installation is completed! Run 'osu-wine' to play osu!"
    Warning "If 'osu-wine' doesn't work, just close and relaunch your terminal."
    exit 0
}


#   =====================================
#   =====================================
#          POST-INSTALL FUNCTIONS
#   =====================================
#   =====================================

# Sanity check to make sure we can run 32-bit GLX apps inside the steam runtime
function Check32(){
    local temp_out; local tail_pid; local umu_pid; local _timeout
    Info "Checking to make sure we can run 32-bit OpenGL apps..."
    Info "If all is well, a window should pop up with some spinning gears. Just close it."
    Info "(Window will automatically close after 15 seconds anyways)"

    chmod +x "./stuff/glxgears32"
    UMU_RUN="$HOME/.local/share/osuconfig/proton-osu/umu-run"

    temp_out=$(mktemp)

    tail -f "$temp_out" | grep -i --line-buffered "explicit\|X_GLXSwapBuffers" > "$temp_out.success" &
    tail_pid=$!

    GAMEID="umu-727" UMU_NO_PROTON=1 "$UMU_RUN" "./stuff/glxgears32" > "$temp_out" 2>&1 &
    umu_pid=$!

    _timeout=15
    while [ $_timeout -gt 0 ]; do
        # Check for "explicit kill or shutdown" (Xwayland) or "GLXBadDrawable -> X_GLXSwapBuffers" (X11)
        if [ -s "$temp_out.success" ]; then
            kill $tail_pid 2>/dev/null
            rm -f "$temp_out" "$temp_out.success"
            Info "Success!" && return 0
        fi
        if ! ps -p $umu_pid >/dev/null 2>&1; then
            break
        fi
        sleep 1
        _timeout=$((_timeout - 1))
    done

    # Clean up and fall back to manual confirmation otherwise
    kill $tail_pid 2>/dev/null
    rm -f "$temp_out" "$temp_out.success"

    if ps -p $umu_pid >/dev/null 2>&1; then
        Info "Closing window for you now..."
        pkill -f "glxgears32"
        sleep 0.5
        pkill -9 -f "glxgears32" 2>/dev/null
        kill $umu_pid 2>/dev/null
        sleep 0.5
        kill -9 $umu_pid 2>/dev/null
    fi

    read -r -p "$(Info "Did you see a window with the spinning gears? (y/N) ")" glx32worked
    if [ "$glx32worked" = 'y' ] || [ "$glx32worked" = 'Y' ]; then
        Info "Success!" && return 0
    fi

    # Failed
    Warning "It looks like we can't run 32-bit OpenGL apps, osu! probably won't work!"
    Warning "Please read the documentation on how to install 32-bit graphics drivers for your distro."
    Warning "Here is a good starting point: https://github.com/lutris/docs/blob/master/InstallingDrivers.md"
    return 1
}

# This function reads files located in ~/.local/share/osuconfig
# to see whether a new wine-osu version has been released.
function Update(){

    # Checking for old installs with Wine
    if [ -d "$HOME/.local/share/osuconfig/wine-osu" ]; then
        Quit "wine-osu detected and already up-to-date; please reinstall Winello if you want to use proton-osu!"
    fi

    # Reading the last version installed
    LASTPROTONVERSION=$(</"$HOME/.local/share/osuconfig/protonverupdate")

    if [ "$LASTPROTONVERSION" \!= "$PROTONVERSION" ]; then
        wget -O "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz" "$PROTONLINK" && chk="$?"

        if [ ! "$chk" = 0 ] ; then
            Info "wget failed; trying with --no-check-certificate.."
            wget --no-check-certificate -O "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz" "$PROTONLINK" || Error "Download failed, check your connection or open an issue here: https://github.com/NelloKudo/osu-winello/issues"
        fi
        Info "Updating Proton-osu"...

        rm -rf "$HOME/.local/share/osuconfig/proton-osu"
        tar -xf "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz" -C "$HOME/.local/share/osuconfig"
        rm -f "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"
        LASTPROTONVERSION="$PROTONVERSION"
        rm -f "$HOME/.local/share/osuconfig/protonverupdate"
        echo "$LASTPROTONVERSION" >> "$HOME/.local/share/osuconfig/protonverupdate"
        Info "Update is completed!"

    else
        Info "Your Proton-osu is already up-to-date!"
    fi
}


# Well, simple function to install the game (also implement in osu-wine --remove)
function Uninstall(){

    Info "Uninstalling icons:"
    rm -f "$HOME/.local/share/icons/osu-wine.png"
    
    Info "Uninstalling .desktop:"
    rm -f "$HOME/.local/share/applications/osu-wine.desktop"
    
    Info "Uninstalling game script, utilities & folderfix:"
    rm -f "$HOME/.local/bin/osu-wine"
    rm -f "$HOME/.local/bin/folderfixosu"
    rm -f "$HOME/.local/share/mime/packages/osuwinello-file-extensions.xml"
    rm -f "$HOME/.local/share/applications/osuwinello-file-extensions-handler.desktop"
    rm -f "$HOME/.local/share/applications/osuwinello-url-handler.desktop"

    Info "Uninstalling proton-osu:"
    rm -rf "$HOME/.local/share/osuconfig/proton-osu"
    
    read -r -p "$(Info "Do you want to uninstall Wineprefix? (y/N)")" wineprch

    if [ "$wineprch" = 'y' ] || [ "$wineprch" = 'Y' ]; then
        rm -rf "$HOME/.local/share/wineprefixes/osu-wineprefix"
    else
        Info "Skipping.." ; fi

    read -r -p "$(Info "Do you want to uninstall game files? (y/N)")" choice
    
    if [ "$choice" = 'y' ] || [ "$choice" = 'Y' ]; then
        read -r -p "$(Info "Are you sure? This will delete your files! (y/N)")" choice2
        
        if [ "$choice2" = 'y' ] || [ "$choice2" = 'Y' ]; then
		    
            Info "Uninstalling game:"
            if [ -e "$HOME/.local/share/osuconfig/osupath" ]; then
                OSUUNINSTALLPATH=$(<"$HOME/.local/share/osuconfig/osupath")
		        rm -rf "$OSUUNINSTALLPATH"
                rm -rf "$HOME/.local/share/osuconfig"
            else
                rm -rf "$HOME/.local/share/osuconfig"
            fi

        else
            rm -rf "$HOME/.local/share/osuconfig"
            Info "Exiting.."
        fi
    
    else
        rm -rf "$HOME/.local/share/osuconfig"
    fi
    
    Info "Uninstallation completed!"
}


# Simple function that downloads Gosumemory!
function Gosumemory(){
    GOSUMEMORY_LINK="https://github.com/l3lackShark/gosumemory/releases/download/1.3.9/gosumemory_windows_amd64.zip"

    if [ ! -d "$HOME/.local/share/osuconfig/gosumemory" ]; then
        Info "Installing gosumemory.."
        mkdir -p "$HOME/.local/share/osuconfig/gosumemory"
        wget -O "/tmp/gosumemory.zip" "$GOSUMEMORY_LINK" || Error "Download failed, check your connection.."
        unzip -d "$HOME/.local/share/osuconfig/gosumemory" -q "/tmp/gosumemory.zip"
        rm "/tmp/gosumemory.zip"
    fi
}

function tosu(){
    TOSU_LINK="https://github.com/KotRikD/tosu/releases/download/v3.3.1/tosu-windows-v3.3.1.zip"
    
    if [ ! -d "$HOME/.local/share/osuconfig/tosu" ]; then
        Info "Installing tosu.."
        mkdir -p "$HOME/.local/share/osuconfig/tosu"
        wget -O "/tmp/tosu.zip" "$TOSU_LINK" || Error "Download failed, check your connection.."
        unzip -d "$HOME/.local/share/osuconfig/tosu" -q "/tmp/tosu.zip"
        rm "/tmp/tosu.zip"
    fi
}

function FixUmu(){
    UMU_RUN="${UMU_RUN:-"$HOME/.local/share/osuconfig/proton-osu/umu-run"}"
    if [ ! -f "$HOME/.local/bin/osu-wine" ]; then
        Info "Looks like you haven't installed osu-winello yet, so you should run ./osu-winello.sh first."
        return
    elif [ ! -f "${UMU_RUN}" ]; then
        Info "umu-launcher comes with Proton, so you should run ./osu-winello.sh first."
        return
    fi

    Info "Removing umu-launcher..."
    rm -rf "${HOME}/.local/share/umu" "${HOME}/.local/share/pybstrap"

    Info "Reinstalling umu-launcher..."
    UMU_NO_PROTON=1 GAMEID="umu-727" "$UMU_RUN" true && chk="$?"
    if [ "${chk}" != 0 ]; then
        Info "That didn't seem to work... try again?"
    else
        Info "umu-launcher should be good to go now."
    fi
}

# Help!
function Help(){
    Info "To install the game, run ./osu-winello.sh
          To uninstall the game, run ./osu-winello.sh uninstall
          To retry installing umu-launcher-related files, run ./osu-winello.sh fixumu
          You can read more at README.md or https://github.com/NelloKudo/osu-winello"
}


#   =====================================
#   =====================================
#            MAIN SCRIPT
#   =====================================
#   =====================================


case "$1" in

    '')
    InitialSetup
    InstallProton
    ConfigurePath
    FullInstall
    ;;

    'uninstall')
    Uninstall
    ;;

    'gosumemory')
    Gosumemory
    ;;

    'tosu')
    tosu
    ;;

    'update')
    Update
    ;;

    *umu*)
    FixUmu
    ;;

    *help*|'-h')
    Help
    ;;

    *)
    Info "Unknown argument, see ./osu-winello.sh help or ./osu-winello.sh -h"
    ;;
esac

# Congrats for reading it all! Have fun playing osu!
# (and if you wanna improve the script, PRs are always open :3)
