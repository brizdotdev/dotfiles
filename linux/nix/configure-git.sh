# Prompt whether to configure git
echo -e "\033[32m Configuring git \033[0m"
read -p "Configure git commit signing? (y/n) " -n 1 -r configGitSigning
echo "[user]" > "$HOME/.gitconfig.local"
echo "  name = TODO" >> "$HOME/.gitconfig.local"
echo "  email = TODO" >> "$HOME/.gitconfig.local"

if [[ $configGitSigning =~ ^[Yy]$ ]]
then
  echo "  signingKey = ~/.ssh/id_ed25519_sk_rk_Default" >> "$HOME/.gitconfig.local"
  echo "[gpg]" >> "$HOME/.gitconfig.local"
  echo "  format = ssh" >> "$HOME/.gitconfig.local"
  echo "[commit]" >> "$HOME/.gitconfig.local"
  echo "  gpgsign = true" >> "$HOME/.gitconfig.local"
fi

$EDITOR "$HOME/.gitconfig.local"