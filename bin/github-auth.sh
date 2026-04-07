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

read_secret_from_tty() {
	local prompt="$1"
	local out_var="$2"
	local input=""

	if [[ ! -r /dev/tty ]]; then
		log_error "Interactive input is required for passphrase entry."
		return 1
	fi

	printf "%s" "$prompt" >/dev/tty
	stty -echo </dev/tty
	if ! IFS= read -r input </dev/tty; then
		stty echo </dev/tty
		printf "\n" >/dev/tty
		return 1
	fi
	stty echo </dev/tty
	printf "\n" >/dev/tty

	printf -v "$out_var" '%s' "$input"
	return 0
}

prompt_yes_no() {
	local prompt="$1"
	local default_yes="$2"
	local answer

	while true; do
		if ! read_from_tty "$prompt" answer; then
			log_error "Interactive input is required."
			return 1
		fi

		case "${answer,,}" in
			y|yes)
				return 0
				;;
			n|no)
				return 1
				;;
			"")
				if [[ "$default_yes" == "true" ]]; then
					return 0
				fi
				return 1
				;;
			*)
				log_warn "Please answer yes or no."
				;;
		esac
	done
}

key_exists() {
	local key_path="$1"
	[[ -f "$key_path" ]]
}

prompt_generation_passphrase() {
	local key_label="$1"
	local out_var="$2"
	local passphrase=""
	local confirm=""

	while true; do
		if ! read_secret_from_tty "Enter passphrase for ${key_label} key (required): " passphrase; then
			return 1
		fi

		if [[ -z "$passphrase" ]]; then
			log_warn "Passphrase cannot be empty for new key generation."
			continue
		fi

		if ! read_secret_from_tty "Confirm passphrase for ${key_label} key: " confirm; then
			return 1
		fi

		if [[ "$passphrase" != "$confirm" ]]; then
			log_warn "Passphrase mismatch. Please try again."
			continue
		fi

		printf -v "$out_var" '%s' "$passphrase"
		return 0
	done
}

generate_key_if_missing() {
	local key_path="$1"
	local comment="$2"
	local key_label="$3"
	local passphrase=""

	if key_exists "$key_path"; then
		log_info "${key_label} key already exists at ${key_path}; keeping existing key."
		return 0
	fi

	log_phase "Generate ${key_label} Key"
	log_info "No existing key found. Generating encrypted key at ${key_path}."

	if ! prompt_generation_passphrase "$key_label" passphrase; then
		return 1
	fi

	ssh-keygen -q -t ed25519 -C "$comment" -f "$key_path" -N "$passphrase"
	log_success "Generated encrypted ${key_label} key."
}

verify_key_passphrase() {
	local key_path="$1"
	local passphrase="$2"

	ssh-keygen -y -P "$passphrase" -f "$key_path" >/dev/null 2>&1
}

prompt_existing_key_passphrase() {
	local key_label="$1"
	local out_var="$2"
	local passphrase=""

	if ! read_secret_from_tty "Enter passphrase for existing ${key_label} key (leave empty if none): " passphrase; then
		return 1
	fi

	printf -v "$out_var" '%s' "$passphrase"
	return 0
}

ensure_public_key_file() {
	local key_path="$1"
	local passphrase="$2"

	if [[ -f "${key_path}.pub" ]]; then
		return 0
	fi

	if ! ssh-keygen -y -P "$passphrase" -f "$key_path" >"${key_path}.pub"; then
		return 1
	fi

	chmod 644 "${key_path}.pub"
}

print_key_block() {
	local title="$1"
	local pub_path="$2"

	log_phase "$title"
	echo "----- BEGIN ${title^^} -----"
	cat "$pub_path"
	echo "----- END ${title^^} -----"
}

show_public_keys_if_requested() {
	if ! prompt_yes_no "Print SSH public keys now? [y/N]: " false; then
		log_info "Skipping public key output by user choice."
		return 10
	fi

	local github_passphrase=""
	local gitlab_passphrase=""

	if ! prompt_existing_key_passphrase "GitHub" github_passphrase; then
		return 2
	fi
	if ! verify_key_passphrase "$GITHUB_KEY" "$github_passphrase"; then
		log_error "GitHub key passphrase validation failed."
		return 2
	fi

	if ! prompt_existing_key_passphrase "GitLab" gitlab_passphrase; then
		return 2
	fi
	if ! verify_key_passphrase "$GITLAB_KEY" "$gitlab_passphrase"; then
		log_error "GitLab key passphrase validation failed."
		return 2
	fi

	if ! ensure_public_key_file "$GITHUB_KEY" "$github_passphrase"; then
		log_error "Unable to generate/read GitHub public key file."
		return 2
	fi

	if ! ensure_public_key_file "$GITLAB_KEY" "$gitlab_passphrase"; then
		log_error "Unable to generate/read GitLab public key file."
		return 2
	fi

	print_key_block "GitHub Public Key" "${GITHUB_KEY}.pub"
	print_key_block "GitLab Public Key" "${GITLAB_KEY}.pub"
	echo ""

	return 0
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
	generate_key_if_missing "$GITHUB_KEY" "github" "GitHub" || exit 1
	generate_key_if_missing "$GITLAB_KEY" "gitlab" "GitLab" || exit 1
	write_ssh_config

	show_public_keys_if_requested
	case "$?" in
		0)
			confirm_keys_added || exit 1
			;;
		10)
			;;
		*)
			exit 1
			;;
	esac

	log_success "GitHub/GitLab SSH setup complete."
}

main "$@"
