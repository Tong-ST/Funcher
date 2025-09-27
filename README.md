# FUNCHER/x11 - App launcher that also FUN!

What it does, It just simple script that call [mpv](mpv.io) media playback to play custom video and run in background..

So my concept here to make it work with others app launcher that already great like `rofi` or you can set to run your others fav app as well

<https://github.com/user-attachments/assets/806ea769-bd2c-4454-89eb-c70d1a8de421>

## Current Stage
FOR Wayland go to [main branch](https://www.github.com/Tong-ST/Funcher)

***Git history rewritten, who clone before 27 sep 2025, Please re-clone for update***

This is very first prototype build that just using `Shell script` as main program, also with help of `libinput` code in `C` that track user input and play different section of vdo

As of current build/test on my i3/x11 and sway/wayland in main branch
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
- rofi: For application launching / menus (works on x11)
- alacritty: For run terminal base app

Installation Instructions:

- For Debian / Ubuntu / Mint: 
    ```
    sudo apt-get update
    sudo apt-get install mpv bc jq socat rofi alacritty
    ```

- For Fedora / CentOS / RHEL: 
    ```
    sudo dnf install mpv bc jq socat rofi alacritty
    ```

- For Arch Linux:
    ```
    sudo pacman -S mpv bc jq socat rofi alacritty
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
    git switch Funcher/x11
    chmod +x funcher.sh mpv_startup.sh
    cd scripts
    make keyboard_listener
    ```

2. **Setup Config**
- In [Releases](https://github.com/Tong-ST/Funcher/releases/) you'll see pip-boy-vdo.tar.xz grab and put it on Funcher/assets
    
    ``` 
    tar xfv pip-boy-vdo.tar.xz
    mkdir $HOME/Funcher/assets/
    cp pip_1080p.mov $HOME/Funcher/assets/
    ```
- Setup your config files This setup is for `i3` only others WMs you may need different config that do the same thing

    - In your i3 .config you should look like these

        ```
        # Setup Window
        for_window [title="mpv_preload"] floating enable, border pixel 0, resize set 1920 1080 
        for_window [class="Rofi"] floating enable, border pixel 0, move scratchpad # some app like Rofi need to move scratchpad first, Others don't 
        for_window [class="calcurseTerm"] floating enable, border pixel 0
        for_window [class="rangerTerm"] floating enable, border pixel 0

        # Keybind for Program
        bindsym $mod+d exec ~/Funcher/funcher.sh
        bindsym $alt+Tab exec $HOME/Funcher/funcher.sh -c $HOME/Funcher/config/rofi-window.json
        bindsym $mod+shift+x exec $HOME/Funcher/funcher.sh -c $HOME/Funcher/config/calcurse.json
        bindsym $mod+shift+t exec $HOME/Funcher/funcher.sh -c $HOME/Funcher/config/ranger.json
        ```
        These are example config and it should be self explain and look into Funcher/config/ as well

3. **Set up others app config** like rofi, alacritty
    ```
    cp -r $HOME/Funcher/test_config/rofi $HOME/.config/
    cp -r $HOME/Funcher/test_config/alacritty $HOME/.config/
    ```
4. **Add input to user group** for input base video you just need to do it one time
    ``` 
    sudo usermod -aG input $USER 
    ``` 
    Than logout and login back see that now mpv change video segment base on your input

- In some cases you might need to make funcher.sh executable `chmod +x funcher.sh` But most case clone from git don't need this

## Usage
For normal use case just set keybinding for each app point those config file like you see in i3 .config example 
- **Or to test/debug** in Funcher directory use for example
    - ./funcher.sh -c /config/config.json # To run main conifg with rofi
    - ./funcher.sh -k # To get input keycode to use on custom VDO segment

- **Know your config** for each app should have they own .json file in Funcher/config folder you'll see you can set your own VDO, Input, What WMs you using 
- **IT'S IMPORTANT** to check in .json file like in vdo path make sure is correct, Your **CURRENT_WM : i3 or others in config file comment should be explain the concept of each


## Limitation
- mpv, So this app is just command mpv playing in background It not a lightweight build yet as i tested if you got wrong Video codec that not support ` Hardware Acceleration ` It going to tank your CPU quite a lot
- As am i develop I found out that the reliable VDO format that play in mpv natively with transparency background right now ` .mov ` is the way to go The file are quite big but it work, I also try like .webm that really small size but can't get trans bg to work with mpv, So if i found the better way in the future will be updated
- Also if we can reduce VDO size and able to keep basic need like BG transparency, HW accel, Quality Please let me know, Right now just have to trade-off with bigger VDO files but it's no lag using it realtime

## Contribution
In this project I consider 2 main roles of contribute to community
1. **Creator** - This project is mainly on creativity side, For example VDO editing as you can see, it's just pure video editing skill, you can craft your own VIDEO what ever you want, No coding experience are required, just tinker with config file should be enough  
    - Some tips I've learn, For new video edit, If one time animation like click down do gear spin, I use base clip that about to go idle loop, And edit edit from that so when this anim done it trasit smoothly to idle
    - Background remover mostly use chroma-key, But if background are not separate, You might need to hand cut with Rotoscoping or use object-detection

2. **Developer** - This very early build is just shell script, I think there are a ton of room to improve like moving to others language like `C` or `lua` I don't know yet in C maybe you can communicate seamless with input listener, or lua maybe it can improve more playback performance with mpv
also expand to different WMs / Distro as possible

Have to admit i really new to programming, As well as VDO editing just know about chroma-key in this project :)

So, If you guy interested to contribute in this project i think you already has better skill than me really.

> To contribute send me an email goodywolf101@gmail.com

Any recommend would be golden!

## Goal
In this very first stage i just want to expand to be reliable on others WMs currently on i3/x11 and Sway/Wayland plan to move port to others WMs as soon as possible

## Support 
- If you like this project consider support at [Ko-fi](https://www.ko-fi.com/goodywolf) a cup of coffees it's already whole days for me in Thailand :) haha

    <a href='https://ko-fi.com/Y8Y11LPTAB' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi5.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

## Thanks & Credit
- [mpv media player](https://mpv.io) is heart of this project
- [libinput](https://wiki.archlinux.org/title/Libinput) For easy to integrate input listening tool
- [bucklespring](https://github.com/zevv/bucklespring) For the amazing keyboard sound effect, Also inspiration for input listening base video playback
- [my own i3 .config](https://www.github.com/Tong-ST/pip-boy-i3) In case you want to see my whole setup

Special thanks to creator of Fallout mods
- [Pipboy animation mod](https://www.nexusmods.com/newvegas/mods/91200)
- [Pipboy skin mod](https://www.nexusmods.com/newvegas/mods/91369)
