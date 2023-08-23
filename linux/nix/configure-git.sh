# Prompt whether to configure git
read -p "Configure git? (y/n) " -n 1 -r configGit
if [[ $configGit =~ ^[Yy]$ ]]
then
  echo -e "\033[32m Configuring git \033[0m"
  read -p "Enter git user.name: " gitName
  read -p "Enter git user.email: " gitEmail
  read -p "Configure git commit signing? (y/n) " -n 1 -r configGitSigning
  echo "[user]" > "$HOME/.gitconfig.local"
  echo "  name = $gitName" >> "$HOME/.gitconfig.local"
  echo "  email = $gitEmail" >> "$HOME/.gitconfig.local"
  if [[ $configGitSigning =~ ^[Yy]$ ]]
  then
    echo "[gpg]" >> "$HOME/.gitconfig.local"
    echo "  format = ssh" >> "$HOME/.gitconfig.local"
    echo "[commit]" >> "$HOME/.gitconfig.local"
    echo "  gpgsign = true" >> "$HOME/.gitconfig.local"
    echo "[user]" >> "$HOME/.gitconfig.local"
    echo "  signingKey = signingkey = ~/.ssh/id_ed25519_sk_rk_Default" >> "$HOME/.gitconfig.local"
  fi
  $EDITOR "$HOME/.gitconfig.local"
fi