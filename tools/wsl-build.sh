#!/bin/bash
# ---------------------------------------------------------------------------
# wsl-build.sh -- drive a MiniOS build from a Windows checkout under WSL.
#
# Why this exists
# ---------------
# The Windows working tree is checked out with core.autocrlf=true and
# core.symlinks=false.  Two consequences make a direct /mnt/c build impossible:
#
#   * every shell script carries CRLF, so `#!/bin/bash\r` fails to exec;
#   * the environment links in linux-live/environments/ are stored in git as
#     mode 120000 but materialise on Windows as small text files holding the
#     link target, so the builder cannot find its modules.
#
# On top of that, DrvFs cannot represent the ownership, permissions and device
# nodes a debootstrap chroot needs.  So this script exports the repository into
# the WSL ext4 filesystem -- where git restores LF endings and real symlinks --
# and runs the build there.
#
# Usage
# -----
#   wsl -d Debian -- bash /mnt/c/.../tools/wsl-build.sh setup
#   wsl -d Debian -- bash /mnt/c/.../tools/wsl-build.sh build -
#   wsl -d Debian -- bash /mnt/c/.../tools/wsl-build.sh build - build-chroot
#   wsl -d Debian -- bash /mnt/c/.../tools/wsl-build.sh fetch-iso
#
# Environment overrides:
#   WORKDIR   where the build tree lives inside WSL   (default /root/minios-build)
#   OUTDIR    where fetch-iso drops the ISO on Windows (default alongside the repo)
# ---------------------------------------------------------------------------

set -euo pipefail

SELF="$(readlink -f "$0")"
SRC="$(cd "$(dirname "$SELF")/.." && pwd)"
: "${WORKDIR:=/root/minios-build}"
WORK="${WORKDIR}/minios-live"
: "${OUTDIR:=${SRC}/build-output}"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

need_root() { [ "$(id -u)" -eq 0 ] || die "run this as root (wsl -d Debian -u root ...)"; }

# --- preflight ------------------------------------------------------------
check_env() {
    grep -qi microsoft /proc/version 2>/dev/null || warn "this does not look like WSL"
    [ -d "$SRC/linux-live" ] || die "cannot locate the repository root (looked at $SRC)"
    command -v git >/dev/null 2>&1 || die "git is not installed -- run '$0 setup' first"
    # The Windows checkout is owned by a different uid as far as Linux git is
    # concerned; without this every git call refuses to touch it.
    git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$SRC" \
        || git config --global --add safe.directory "$SRC"
}

# --- setup ----------------------------------------------------------------
cmd_setup() {
    need_root
    say "installing build prerequisites"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    # minios-live's own list, plus what the builder and this script assume.
    local pkgs=(
        sudo binutils debootstrap squashfs-tools xorriso mtools rsync
        grub-common gpg gpgv curl openssl sbsigntool
        git ca-certificates xz-utils zstd cpio file dosfstools fdisk
        syslinux syslinux-common isolinux grub-pc-bin grub-efi-amd64-bin
        python3 gettext
        # The WSL2 kernel has no CONFIG_SQUASHFS_ZSTD, so the builder cannot
        # mount its own zstd modules; minioslib falls back to squashfuse.
        squashfuse fuse3
    )
    apt-get install -y --no-install-recommends "${pkgs[@]}"
    say "host is ready"
}

# Is this file binary?  `file --mime-encoding` reports "binary" for anything
# that is not decodable text, and needs no escape sequences to express -- an
# earlier version used a NUL pattern, which bash cannot hold in a string, so
# the test silently matched every file and pushed text through the binary
# path with its CRLF endings intact.
is_binary() {
    [ "$(file -b --mime-encoding -- "$1" 2>/dev/null)" = binary ]
}

# --- sync -----------------------------------------------------------------
# Two passes:
#
#  1. `git checkout-index` with autocrlf disabled and symlinks enabled writes
#     every tracked file's blob verbatim (so LF, not CRLF) and recreates mode
#     120000 entries as real symlinks.  This is what makes the environment
#     links under linux-live/environments/ work.
#
#  2. That first pass reads the *index*, so a tracked file edited but not yet
#     staged would silently export at its stale staged content.  The second
#     pass therefore overlays the working-tree copy of anything git reports as
#     modified or untracked, converting CRLF to LF for text files.  Symlink
#     entries are skipped: on Windows those are placeholder text files holding
#     the link target, and pass 1 already materialised them correctly.
cmd_sync() {
    need_root
    check_env
    say "exporting $SRC -> $WORK"
    rm -rf "$WORK"
    mkdir -p "$WORK"

    git -C "$SRC" -c core.autocrlf=false -c core.symlinks=true         checkout-index --all --force --prefix="$WORK/"

    # Paths stored as symlinks, so pass 2 leaves them alone.
    # `git ls-files -s -z` prints: <mode> <sha> <stage><TAB><path><NUL>
    declare -A IS_LINK=()
    local entry
    while IFS= read -r -d '' entry; do
        case "$entry" in
        120000\ *) IS_LINK["${entry#*$'	'}"]=1 ;;
        esac
    done < <(git -C "$SRC" ls-files -s -z)

    local copied=0 f
    while IFS= read -r -d '' f; do
        [ -n "${IS_LINK[$f]:-}" ] && continue
        [ -f "$SRC/$f" ] || continue
        mkdir -p "$WORK/$(dirname "$f")"
        if is_binary "$SRC/$f"; then
            cp "$SRC/$f" "$WORK/$f"                      # binary: byte-for-byte
        else
            sed 's/\r$//' "$SRC/$f" > "$WORK/$f"         # text: CRLF -> LF
            [ "$(head -c 2 "$WORK/$f")" = '#!' ] && chmod +x "$WORK/$f"
        fi
        copied=$((copied + 1))
    done < <(git -C "$SRC" ls-files -z --modified --others --exclude-standard)
    say "overlaid $copied working-tree file(s)"

    # Sanity: the environment links must be real, resolvable symlinks now.
    local broken=0 l
    for l in "$WORK"/linux-live/environments/*/*; do
        [ -L "$l" ] || { warn "not a symlink: $l"; broken=1; }
        [ -e "$l" ] || { warn "dangling module link: $l"; broken=1; }
    done
    [ "$broken" -eq 0 ] || die "environment links did not survive the export"

    say "export complete"
}

# --- build ----------------------------------------------------------------
# The build tree is kept OUTSIDE the exported source tree, at $WORKDIR/build,
# so that re-syncing after an edit does not throw away a completed bootstrap.
# minios-live honours BUILD_DIR for exactly this.
cmd_build() {
    need_root
    cmd_sync
    export BUILD_DIR="${WORKDIR}/build"
    mkdir -p "$BUILD_DIR"
    say "building: ./minios-live ${*:-<none>}   (BUILD_DIR=$BUILD_DIR)"
    cd "$WORK"
    ./minios-live "$@"
}

cmd_shell()  { need_root; check_env; cd "$WORK" 2>/dev/null || die "no build tree; run '$0 sync'"; exec bash -i; }
cmd_clean()  { need_root; say "removing $WORKDIR"; rm -rf "$WORKDIR"; }

cmd_fetch_iso() {
    local iso
    iso="$(find "${WORKDIR}/build" -maxdepth 3 -name '*.iso' -printf '%T@ %p\n' 2>/dev/null \
           | sort -rn | head -1 | cut -d' ' -f2-)"
    [ -n "$iso" ] || die "no ISO found under ${WORKDIR}/build"
    mkdir -p "$OUTDIR"
    say "copying $(basename "$iso") -> $OUTDIR"
    cp -f "$iso" "$OUTDIR/"
    say "done: $OUTDIR/$(basename "$iso")"
}

usage() {
    sed -n '2,32p' "$SELF" | sed 's/^# \?//'
    exit "${1:-0}"
}

case "${1:-}" in
    setup)      shift; cmd_setup "$@" ;;
    sync)       shift; cmd_sync "$@" ;;
    build)      shift; cmd_build "$@" ;;
    shell)      shift; cmd_shell "$@" ;;
    clean)      shift; cmd_clean "$@" ;;
    fetch-iso)  shift; cmd_fetch_iso "$@" ;;
    -h|--help|help|"") usage 0 ;;
    *) die "unknown command: $1 (try --help)" ;;
esac
