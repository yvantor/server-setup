#!/bin/bash

HomeAccessGroup="homeaccess"
Admin="admin"
UsersDir="/home/admin/users"
DesktopEnv="xfce"
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
    echo "Dopo l'accesso via SSH, eseguire i seguenti comandi:" >> "$CredFile"
    echo "  vncserver -geometry $Geometry" >> "$CredFile"
    echo "Per fermare la sessione:" >> "$CredFile"
    echo "  vncserver -kill :X  (sostituisci X con il display id)" >> "$CredFile"
    echo "" >> "$CredFile"
    echo "⚠️ Consigliato: usa -localhost e un tunnel SSH per sicurezza:" >> "$CredFile"
    echo "  vncserver -localhost -geometry $Geometry" >> "$CredFile"
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

#########################
# Old version following #
#########################

# #!/bin/bash
# 
# HomeAccessGroup="homeaccess"
# Admin="admin"
# UsersDir="/home/admin/users"
# DesktopEnv="xfce"
# Geometry="1920x1080"
# 
# if ! getent group "$HomeAccessGroup" > /dev/null; then
#     groupadd "$HomeAccessGroup"
#     echo "Created group $HomeAccessGroup"
# fi
# 
# usermod -aG "$HomeAccessGroup" "$Admin"
# 
# find_free_vnc_display() {
#     for d in $(seq 2 99); do
#         if [ ! -e "/tmp/.X${d}-lock" ] && [ ! -f "/etc/systemd/system/vncserver@:${d}.service" ]; then
#             echo "$d"
#             return 0
#         fi
#     done
#     echo "No VNC displays available" >&2
#     return 1
# }
# 
# create() {
#     local NewUser="$1"
# 
#     if [ -z "$NewUser" ]; then
#         echo "Error: no user provided."
#         echo "Usage: sudo $0 create nome_utente"
#         return 1
#     fi
# 
#     if id "$NewUser" &>/dev/null; then
#         echo "User '$NewUser' already exists."
#         return 1
#     fi
# 
#     local NewUserDir="$UsersDir/$NewUser"
#     local Password
#     Password=$(openssl rand -base64 12)
# 
#     mkdir -p "$NewUserDir"
#     useradd -m -s /bin/bash "$NewUser"
#     echo "$NewUser:$Password" | chpasswd
# 
#     cp /home/"$Admin"/.bashrc /home/"$NewUser"/.bashrc
#     chown "$NewUser:$NewUser" /home/"$NewUser"/.bashrc
#     chmod 644 /home/"$NewUser"/.bashrc
# 
#     usermod -aG "$HomeAccessGroup" "$NewUser"
#     chmod 750 /home/"$NewUser"
#     setfacl -m g:"$HomeAccessGroup":rx /home/"$NewUser"
# 
#     local CredFile="${NewUserDir}/${NewUser}.txt"
#     echo "Username: $NewUser" > "$CredFile"
#     echo "Password: $Password" >> "$CredFile"
#     chmod 700 "$CredFile"
#     chown admin:admin "$CredFile"
# 
#     echo "User '$NewUser' created. Access credentials saved into '$CredFile'."
# 
#     local VncDisplay
#     VncDisplay=$(find_free_vnc_display) || return 1
#     local VncPort=$((5900 + VncDisplay))
#     local ServiceFile="/etc/systemd/system/vncserver@:${VncDisplay}.service"
# 
#     su - "$NewUser" -c "mkdir -p ~/.vnc ~/.config/tigervnc"
#     su - "$NewUser" -c "echo '$Password' | vncpasswd -f > ~/.config/tigervnc/passwd"
#     chmod 600 "/home/$NewUser/.config/tigervnc/passwd"
# 
#     if [ "$DesktopEnv" == "xfce" ]; then
#         echo '#!/bin/sh' > "/home/$NewUser/.vnc/xstartup"
#         echo 'unset SESSION_MANAGER' >> "/home/$NewUser/.vnc/xstartup"
#         echo 'unset DBUS_SESSION_BUS_ADDRESS' >> "/home/$NewUser/.vnc/xstartup"
#         echo 'dbus-launch startxfce4 &' >> "/home/$NewUser/.vnc/xstartup"
#     elif [ "$DesktopEnv" == "gnome" ]; then
#         echo '#!/bin/sh' > "/home/$NewUser/.vnc/xstartup"
#         echo 'exec gnome-session' >> "/home/$NewUser/.vnc/xstartup"
#     fi
#     chown "$NewUser:$NewUser" "/home/$NewUser/.vnc/xstartup"
#     chmod +x "/home/$NewUser/.vnc/xstartup"
# 
#     cat <<EOF > "$ServiceFile"
# [Unit]
# Description=Remote desktop VNC server for $NewUser on display :$VncDisplay
# After=syslog.target network.target
# 
# [Service]
# Type=simple
# User=$NewUser
# ExecStart=/usr/bin/vncserver :$VncDisplay -geometry $Geometry -depth 24 -rfbauth /home/$NewUser/.config/tigervnc/passwd
# ExecStop=/usr/bin/vncserver -kill :$VncDisplay
# 
# [Install]
# WantedBy=multi-user.target
# EOF
# 
#     systemctl daemon-reload
#     systemctl enable "vncserver@:${VncDisplay}.service"
#     systemctl start  "vncserver@:${VncDisplay}.service"
# 
#     echo "VNC configurato per $NewUser su display :$VncDisplay (porta $VncPort)"
#     echo "VNC Display: :$VncDisplay" >> "$CredFile"
#     echo "VNC Port: $VncPort" >> "$CredFile"
# }
# 
# delete() {
#     local TargetUser="$1"
# 
#     if [ -z "$TargetUser" ]; then
#         echo "Error: no user provided."
#         echo "Usage: sudo $0 delete nome_utente"
#         return 1
#     fi
# 
#     if ! id "$TargetUser" &>/dev/null; then
#         echo "User '$TargetUser' does not exist."
#         return 1
#     fi
# 
#     echo "Terminating sessions for $TargetUser..."
#     loginctl terminate-user "$TargetUser" 2>/dev/null
#     sleep 2
#     pkill -9 -u "$TargetUser"
# 
#     local VncDisplay=$(($(id -u "$TargetUser") % 100))
#     systemctl stop "vncserver@:${VncDisplay}.service"
#     systemctl disable "vncserver@:${VncDisplay}.service"
#     rm -f "/etc/systemd/system/vncserver@:${VncDisplay}.service"
# 
#     GVFS_DIR="/home/$TargetUser/.cache/gvfs"
#     fusermount -u "$GVFS_DIR" 2>/dev/null
# 
#     echo "Deleting user and home directory..."
#     userdel -r "$TargetUser" || rm -rf "/home/$TargetUser"
# 
#     local NewUserDir="${UsersDir}/${TargetUser}"
#     [ -d "$NewUserDir" ] && rm -rf "$NewUserDir" && echo "Deleted credential directory: $NewUserDir"
# }
# 
# case "$1" in
#     create)
#         create "$2"
#         ;;
#     delete)
#         delete "$2"
#         ;;
#     *)
#         echo "Usage:"
#         echo "  sudo $0 create nome_utente"
#         echo "  sudo $0 delete nome_utente"
#         exit 1
#         ;;
# esac
