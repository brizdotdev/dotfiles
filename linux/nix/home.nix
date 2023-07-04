{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "{{USERNAME}}";
  home.homeDirectory = "{{HOME_PATH}}";


  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # Dev utils
    pkgs.bat
    pkgs.git
    pkgs.fzf
    pkgs.delta
    pkgs.exa
    pkgs.less
    pkgs.gnused
    pkgs.gnugrep
    pkgs.starship
    pkgs.zoxide
    pkgs.jq
    pkgs.yq-go
    pkgs.fd
    pkgs.glab
    pkgs.ripgrep
    pkgs.lazygit
    pkgs.lf
    pkgs.glow
    pkgs.xsv
    pkgs.sd
    pkgs.duf
    pkgs.fx
    pkgs.tmux

    # Basic CLI Utils
    pkgs.p7zip
    pkgs.gnutar
    pkgs.unzip
    pkgs.zip

    # Useful utils
    pkgs.ffmpeg_6
    pkgs.yt-dlp
    pkgs.htop
    pkgs.bottom
    pkgs.dig
    pkgs.gnupg

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
    ".bashrc".source = "${config.home.homeDirectory}/.dotfiles/linux/config/bash/bashrc";
    ".config/lazygit/config.yml".source = "${config.home.homeDirectory}/.dotfiles/common/config/lazygit/config.yml";
    ".config/nvim".source = "${config.home.homeDirectory}/.dotfiles/common/config/nvim";
    ".config/starship.toml".source = "${config.home.homeDirectory}/.dotfiles/common/config/starship/starship.toml";
    ".vimrc".source = "${config.home.homeDirectory}/.dotfiles/common/config/vim/.vimrc";
    ".tmux.conf".source = "${config.home.homeDirectory}/.dotfiles/linux/config/tmux/.tmux.conf";
    ".tmux/plugins/tpm".source = "${config.home.homeDirectory}/.dotfiles/linux/config/tmux/tpm";

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/vscode/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };
}