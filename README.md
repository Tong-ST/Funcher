# FUNCHER - App launcher that also FUN!

What it does, It just simple script that call [mpv](mpv.io) media playback to play custom video and run in background..

So my concept here to make it work with others app launcher that already great like `wofi`, or you can set to run your others fav app as well

![Funcher Demo](assets/funcher_demo.gif)

## Current Stage
This is very first prototype build that just using `Shell script` as main program, also with help of `libinput` code in `C` that track user input and play different section of vdo

As of current build only work well on `Wayland` i build on sway/debian 13, try to expand to hyprland but not tested yet..
if you know how to deal with hyprland just look into main script and change WM related command for your setup and maybe share with others

So, it's first prototype release expect some thing to break

## Before install

Make sure your system have all dependencies needed

Part A: Main Application Dependencies
The main funcher.sh requires the following command-line tools to be installed:
- mpv: For video playback
- bc: For basic calculations
- jq: For JSON processing
- socat: For IPC/socket communication

Apps You can use others app but here just quick example to get you started
- wofi: For application launching / menus (works on Wayland)
- alacritty: For run terminal base app

Installation Instructions:

- For Debian / Ubuntu / Mint: 
    ```
    sudo apt-get update
    sudo apt-get install mpv bc jq socat wofi alacritty
    ```

- For Fedora / CentOS / RHEL: 
    ```
    sudo dnf install mpv bc jq socat wofi alacritty
    ```

- For Arch Linux:
    ```
    sudo pacman -S mpv bc jq socat wofi alacritty
    ```

Part B: Input Listener Compilation Dependencies
- libinput
- libudev

Installation Instructions:

- For Debian / Ubuntu / Mint: 
    ```
    sudo apt-get install build-essential libinput-dev libudev-dev
    ```

- For Fedora / CentOS / RHEL: 
    ```
    sudo dnf groupinstall "Development Tools"
    sudo dnf install libinput-devel systemd-devel
    ```
    (Note: libudev development files are included in systemd-devel on these systems)

- For Arch Linux:
    ```
    sudo pacman -S base-devel libinput
    ```

## Installation & Setup

For ready to use, I install in $HOME directory if you want to changes, You may need to adjust path in config files

1. **Git clone & Build**
    ```
    cd $HOME
    git clone https://github.com/Tong-ST/Funcher.git
    cd Funcher
    chmod +x funcher.sh mpv_startup.sh
    cd scripts
    make keyboard_listener
    ```

2. **Setup Config**
- In [Releases](https://github.com/Tong-ST/Funcher/releases/) you'll see pip_1080p.tar.xz grab and put it on Funcher/assets
    
    ``` 
    tar xfv pip_1080p.tar.xz
    cp pip_1080p.mov $HOME/Funcher/assets/
    ```
- Setup your config files This setup is for `sway` only others wayland you may need different config that do the same thing

    - In your sway .config you should look like these

        ```
        ### mpv setup
        for_window [title="mpv_preload"] floating enable, border none, resize set 1920 1080

        ### Please Enter the exact path of where you clone to..
        exec $HOME/Funcher/mpv_startup.sh # This can be disable I didn't notice much performance gain for the system startup, You can try it yourself

        ### Your app setup
        for_window [app_id="wofi"] floating enable, border none, move position 750 240
        for_window [app_id="calcurseTerm"] floating enable, border none, move position 630 115, resize set 600 380
        for_window [app_id="rangerTerm"] floating enable, border none, move position 630 115, resize set 600 380

        ### Funcher Key-Binding
        bindsym $mod+d exec $HOME/Funcher/funcher.sh
        bindsym $mod+shift+d exec $HOME/Funcher/funcher.sh -c $HOME/Funcher/config/wofi-run.json
        bindsym $mod+shift+x exec $HOME/Funcher/funcher.sh -c $HOME/Funcher/config/calcurse.json
        bindsym $mod+shift+t exec $HOME/Funcher/funcher.sh -c $HOME/Funcher/config/ranger.json
        ```
        These are example config and it should be self explain and look into Funcher/config/ as well

3. **Set up others app config** like wofi, alacritty
    ```
    cp -r $HOME/Funcher/test_config/wofi $HOME/.config/
    cp -r $HOME/Funcher/test_config/alacritty $HOME/.config/
    ```
4. **Add input to user group** for input base video you just need to do it one time
    ``` 
    sudo usermod -aG input $USER 
    ``` 
    Than logout and login back see that now mpv change video segment base on your input

- In some cases you might need to make funcher.sh executable `sudo chmod +x funcher.sh` But most case clone from git don't need this

## Usage
For normal use case just set keybinding for each app point those config file like you see in sway .config example 
- **Or to test/debug** in Funcher directory use for example
    - ./funcher.sh -c /config/config.json # To run main conifg with wofi
    - ./funcher.sh -k # To get input keycode to use on custom VDO segment

- **Know your config** for each app should have they own .json file in Funcher/config folder you'll see you can set your own VDO, Input, What WMs you using 
- **IT'S IMPORTANT** to check in .json file like in vdo path make sure is correct, Your **CURRENT_WM : sway or hyprland** in config file comment should be explain the concept of each


## Limitation
- mpv, So this app is just command mpv playing in background It not a lightweight build yet as i tested if you got wrong Video codec that not support ` Hardware Acceleration ` It going to tank your CPU quite a lot
- As am i develop I found out that the reliable VDO format that play in mpv natively with transparency background right now ` .mov ` is the way to go The file are quite big but it work, I also try like .webm that really small size but can't get trans bg to work with mpv, So if i found the better way in the future will be updated
- Still figure how to make mpv able to run --background=none on x11, If solving this problem we should be integrate to WMs like i3wm easily...If you know how please give me a sign
- Also if we can reduce VDO size and able to keep basic need like BG transparency, HW accel, Quality Please let me know, Right now just have to trade-off with bigger VDO files but it's no lag using it realtime

## Contribution
In this project I consider 2 main roles of contribute to community
1. **Creator** - This project is mainly on creativity side, For example VDO editing as you can see, it's just pure video editing skill, you can craft your own VIDEO what ever you want, No coding experience are required, just tinker with config file should be enough  

2. **Developer** - This very early build is just shell script, I think there are a ton of room to improve like moving to others language like `C` or `lua` I don't know yet in C maybe you can communicate seamless with input listener, or lua maybe it can improve more playback performance with mpv
also expand to different WMs / Distro as possible

Have to admit i really new to programming, As well as VDO editing just know about chroma-key in this project :)

So, If you guy interested to contribute in this project i think you already has better skill than me really.

> To contribute send me an email goodywolf101@gmail.com

Any recommend would be golden!

## Goal
In this very first stage i just want to expand to be reliable on others WMs currently on Sway/Wayland maybe others wayland > Than tackle with x11 if we can make mpv play transparent background on x11

## Support 
- If you like this project consider support at [Ko-fi](https://www.ko-fi.com/goodywolf) a cup of coffees it's already whole days for me in Thailand :) haha

    <a href='https://ko-fi.com/Y8Y11LPTAB' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi5.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

## Thanks & Credit
- [mpv media player](https://mpv.io) is heart of this project
- [libinput](https://wiki.archlinux.org/title/Libinput) For easy to integrate input listening tool

Special thanks to creator of Fallout mods
- [Pipboy animation mod](www.nexusmods.com/newvegas/mods/91200)
- [Pipboy skin mod](www.nexusmods.com/newvegas/mods/91369)