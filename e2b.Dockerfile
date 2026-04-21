# MirXa Kali — custom e2b desktop template
#
# Build & register this template with the e2b CLI:
#
#   npm i -g @e2b/cli
#   e2b template build --name mirxa-kali
#
# Then put the returned template id into your .env as E2B_TEMPLATE_ID.
#
# This image starts from kali-rolling, installs the lightweight XFCE desktop
# (the only DE that the e2b desktop runtime currently supports), the standard
# Kali offensive-security metapackages the agent will reach for, and the
# helper utilities (xdotool, scrot, ffmpeg) that @e2b/desktop uses for screen
# capture and input synthesis.
FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        # Display server + minimal XFCE (e2b desktop spawns Xvfb + xfce4)
        xfce4 xfce4-terminal xvfb dbus-x11 \
        # Input + screen capture used by @e2b/desktop
        xdotool scrot ffmpeg imagemagick \
        # Browsers
        firefox-esr \
        # Core CLI the agent uses
        sudo curl wget git ca-certificates jq ripgrep unzip xz-utils \
        python3 python3-pip python3-venv \
        nodejs npm \
        # Kali default toolset (lightweight subset — full kali-linux-default is huge)
        nmap whatweb nikto sqlmap hydra dirb gobuster netcat-openbsd \
        # File manager
        thunar \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Allow passwordless sudo inside the sandbox so the agent can install packages.
RUN echo 'user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-mirxa-kali \
 && chmod 0440 /etc/sudoers.d/99-mirxa-kali

# A welcome banner shown if the user opens xfce4-terminal.
RUN printf '\n\033[1;31mMirXa Kali\033[0m — AI-driven Kali Linux desktop.\n\n' \
        > /etc/motd

# e2b's desktop runtime starts Xvfb + xfce4 itself; no CMD/ENTRYPOINT needed.
