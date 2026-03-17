#!/usr/bin/env bash

set -uE -o pipefail

SSH_DIR="${HOME}/.ssh"
GITHUB_KEY="${SSH_DIR}/id_ed25519"
GITLAB_KEY="${SSH_DIR}/id_ed25519_gitlab"
SSH_CONFIG="${SSH_DIR}/config"

ensure_ssh_dir() {
	mkdir -p "$SSH_DIR"
	chmod 700 "$SSH_DIR"
}

generate_key_if_missing() {
	local key_path="$1"
	local comment="$2"

	if [[ -f "$key_path" ]]; then
		echo "==> Key exists, keeping it: $key_path"
		return 0
	fi

	echo "==> Generating SSH key: $key_path"
	ssh-keygen -t ed25519 -C "$comment" -f "$key_path" -N ""
}

write_ssh_config() {
	cat > "$SSH_CONFIG" <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes

Host gitlab.com
  HostName gitlab.com
  User git
  IdentityFile ~/.ssh/id_ed25519_gitlab
  AddKeysToAgent yes
EOF

	chmod 600 "$SSH_CONFIG"
}

show_public_keys() {
	echo ""
	echo "==> GitHub public key (add this to GitHub SSH keys):"
	cat "${GITHUB_KEY}.pub"

	echo ""
	echo "==> GitLab public key (add this to GitLab SSH keys):"
	cat "${GITLAB_KEY}.pub"
	echo ""
}

confirm_keys_added() {
	local answer
	while true; do
		read -r -p "Have you added BOTH keys to GitHub and GitLab? [y/N]: " answer
		case "${answer,,}" in
			y|yes)
				return 0
				;;
			n|no|"")
				echo "Please add both keys first. This script will wait here until you confirm with 'y'."
				;;
			*)
				echo "Please answer yes or no."
				;;
		esac
	done
}

main() {
	ensure_ssh_dir
	generate_key_if_missing "$GITHUB_KEY" "github"
	generate_key_if_missing "$GITLAB_KEY" "gitlab"
	write_ssh_config
	show_public_keys
	confirm_keys_added

	echo "==> GitHub/GitLab SSH setup complete."
}

main "$@"
