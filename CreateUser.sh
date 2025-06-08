#!/bin/bash

HomeAccessGroup="homeaccess"
Admin="admin"
UsersDir="/home/admin/users"
DesktopEnv="gnome"
Geometry="1920x1080"

if ! getent group "$HomeAccessGroup" > /dev/null; then
    groupadd "$HomeAccessGroup"
    echo "Created group $HomeAccessGroup"
fi

usermod -aG "$HomeAccessGroup" "$Admin"

create() {
    local NewUser="$1"

    if [ -z "$NewUser" ]; then
        echo "Error: no user provided."
        echo "Usage: sudo $0 create nome_utente"
        return 1
    fi

    if id "$NewUser" &>/dev/null; then
        echo "User '$NewUser' already exists."
        return 1
    fi

    local NewUserDir="$UsersDir/$NewUser"
    local Password
    Password=$(openssl rand -base64 12)

    mkdir -p "$NewUserDir"
    useradd -m -s /bin/bash "$NewUser"
    echo "$NewUser:$Password" | chpasswd

    cp /home/"$Admin"/.bashrc /home/"$NewUser"/.bashrc
    cp /home/"$Admin"/.bash_profile /home/"$NewUser"/.bash_profile
    chown "$NewUser:$NewUser" /home/"$NewUser"/.bashrc
    chmod 644 /home/"$NewUser"/.bashrc

    usermod -aG "$HomeAccessGroup" "$NewUser"
    chmod 750 /home/"$NewUser"
    setfacl -m g:"$HomeAccessGroup":rx /home/"$NewUser"

    local CredFile="${NewUserDir}/${NewUser}.txt"
    echo "Username: $NewUser" > "$CredFile"
    echo "Password: $Password" >> "$CredFile"
    echo "" >> "$CredFile"
    chmod 700 "$CredFile"
    chown admin:admin "$CredFile"

    echo "User '$NewUser' created. Access credentials saved into '$CredFile'."

    su - "$NewUser" -c "mkdir -p ~/.vnc ~/.config/tigervnc"
    su - "$NewUser" -c "echo '$Password' | vncpasswd -f > ~/.config/tigervnc/passwd"
    chmod 600 "/home/$NewUser/.config/tigervnc/passwd"

    if [ "$DesktopEnv" == "xfce" ]; then
        echo '#!/bin/sh' > "/home/$NewUser/.vnc/xstartup"
        echo 'unset SESSION_MANAGER' >> "/home/$NewUser/.vnc/xstartup"
        echo 'unset DBUS_SESSION_BUS_ADDRESS' >> "/home/$NewUser/.vnc/xstartup"
        echo 'dbus-launch startxfce4 &' >> "/home/$NewUser/.vnc/xstartup"
    elif [ "$DesktopEnv" == "gnome" ]; then
        echo '#!/bin/sh' > "/home/$NewUser/.vnc/xstartup"
        echo 'exec gnome-session' >> "/home/$NewUser/.vnc/xstartup"
    fi
    chown "$NewUser:$NewUser" "/home/$NewUser/.vnc/xstartup"
    chmod +x "/home/$NewUser/.vnc/xstartup"
}

delete() {
    local TargetUser="$1"

    if [ -z "$TargetUser" ]; then
        echo "Error: no user provided."
        echo "Usage: sudo $0 delete nome_utente"
        return 1
    fi

    if ! id "$TargetUser" &>/dev/null; then
        echo "User '$TargetUser' does not exist."
        return 1
    fi

    echo "Terminating sessions for $TargetUser..."
    loginctl terminate-user "$TargetUser" 2>/dev/null
    sleep 2
    pkill -9 -u "$TargetUser"

    GVFS_DIR="/home/$TargetUser/.cache/gvfs"
    fusermount -u "$GVFS_DIR" 2>/dev/null

    echo "Deleting user and home directory..."
    userdel -r "$TargetUser" || rm -rf "/home/$TargetUser"

    local NewUserDir="${UsersDir}/${TargetUser}"
    [ -d "$NewUserDir" ] && rm -rf "$NewUserDir" && echo "Deleted credential directory: $NewUserDir"
}

case "$1" in
    create)
        create "$2"
        ;;
    delete)
        delete "$2"
        ;;
    *)
        echo "Usage:"
        echo "  sudo $0 create nome_utente"
        echo "  sudo $0 delete nome_utente"
        exit 1
        ;;
esac
