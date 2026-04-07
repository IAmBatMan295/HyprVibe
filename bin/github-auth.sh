#!/usr/bin/env bash

set -uE -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="${SCRIPT_DIR}/lib/common.sh"

if [[ ! -r "$COMMON_LIB" ]]; then
	echo "Error: Missing common helper library: $COMMON_LIB" >&2
	exit 1
fi

# shellcheck disable=SC1090
source "$COMMON_LIB"

SSH_DIR="${HOME}/.ssh"
GITHUB_KEY="${SSH_DIR}/id_ed25519"
GITLAB_KEY="${SSH_DIR}/id_ed25519_gitlab"
SSH_CONFIG="${SSH_DIR}/config"

ensure_ssh_dir() {
	mkdir -p "$SSH_DIR"
	chmod 700 "$SSH_DIR"
}

require_command() {
	local cmd="$1"
	if ! command -v "$cmd" >/dev/null 2>&1; then
		log_error "Required command not found: $cmd"
		return 1
	fi
}

regenerate_key() {
	local key_path="$1"
	local comment="$2"

	if [[ -f "$key_path" || -f "${key_path}.pub" ]]; then
		log_warn "Replacing existing SSH key: $key_path"
		rm -f "$key_path" "${key_path}.pub"
	fi

	log_info "Generating SSH key: $key_path"
	ssh-keygen -q -t ed25519 -C "$comment" -f "$key_path" -N ""
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
	if [[ ! -f "${GITHUB_KEY}.pub" || ! -f "${GITLAB_KEY}.pub" ]]; then
		log_error "Could not find one or both generated public keys."
		return 1
	fi

	log_phase "GitHub Public Key"
	log_info "Add this key in GitHub SSH keys"
	echo "----- BEGIN GITHUB PUBLIC KEY -----"
	cat "${GITHUB_KEY}.pub"
	echo "----- END GITHUB PUBLIC KEY -----"

	log_phase "GitLab Public Key"
	log_info "Add this key in GitLab SSH keys"
	echo "----- BEGIN GITLAB PUBLIC KEY -----"
	cat "${GITLAB_KEY}.pub"
	echo "----- END GITLAB PUBLIC KEY -----"
	echo ""
}

confirm_keys_added() {
	local answer
	while true; do
		if ! read_from_tty "Have you added BOTH keys to GitHub and GitLab? [y/N]: " answer; then
			log_error "Interactive input is required to confirm SSH key upload."
			return 1
		fi

		case "${answer,,}" in
			y|yes)
				return 0
				;;
			n|no|"")
				log_warn "Please add both keys first, then confirm with 'y'."
				;;
			*)
				log_warn "Please answer yes or no."
				;;
		esac
	done
}

main() {
	setup_colors
	log_phase "SSH Key Setup"

	require_command ssh-keygen || exit 1
	require_command cat || exit 1

	ensure_ssh_dir
	regenerate_key "$GITHUB_KEY" "github"
	regenerate_key "$GITLAB_KEY" "gitlab"
	write_ssh_config
	show_public_keys || exit 1
	confirm_keys_added || exit 1

	log_success "GitHub/GitLab SSH setup complete."
}

main "$@"
