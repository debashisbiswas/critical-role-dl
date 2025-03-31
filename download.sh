#!/usr/bin/env bash

set -euo pipefail

PLAYLIST_URL="https://www.youtube.com/playlist?list=PL1tiwbzkOjQxD0jjAE7PsWoaCrs0EkBH2"
SHOW_NAME="Critical Role"
SEASON_NUM="02"
BASE_DIR="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir)
      BASE_DIR="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [-d|--dir <download-directory>]"
      exit 1
      ;;
  esac
done

SHOW_DIR="$BASE_DIR/$SHOW_NAME"
SEASON_DIR="$SHOW_DIR/Season $SEASON_NUM"
SPECIALS_DIR="$SHOW_DIR/Season 00"
mkdir -p "$SEASON_DIR" "$SPECIALS_DIR"

playlist_data=$(gum spin --spinner "line" --title "Getting videos..." -- \
  yt-dlp -j --flat-playlist "$PLAYLIST_URL")

mapfile -t playlist_entries < <(
  echo "$playlist_data" |
  jq -r '[.id, .title] | @tsv' |
  nl -w3 -s$'\t'
)

declare -A playlist_index_to_episode
for entry in "${playlist_entries[@]}"; do
  index=$(echo "$entry" | cut -f1)
  title=$(echo "$entry" | cut -f3-)
  ep=$(echo "$title" | grep -oP 'Episode \K\d+' || true)
  if [[ -n "$ep" ]]; then
    playlist_index_to_episode["$index"]=$ep
  fi
done

selected=$(gum choose --no-limit "${playlist_entries[@]}")

if [[ -z "$selected" ]]; then
  echo "No episodes selected."
  exit 0
fi

echo "Downloading selected episodes..."

while IFS=$'\t' read -r index video_id title; do
  episode_num=$(echo "$title" | grep -oP 'Episode \K\d+' || true)

  if [[ -n "$episode_num" ]]; then
    filename="$SEASON_DIR/$SHOW_NAME S${SEASON_NUM}E$(printf "%02d" "$episode_num").%(ext)s"
  else
    safe_title=$(echo "$title" | tr '/:*?"<>|' _)
    filename="$SPECIALS_DIR/$safe_title.%(ext)s"

    airs_before=""
    for ((i=index + 1; i <= ${#playlist_entries[@]}; i++)); do
      if [[ -n "${playlist_index_to_episode[$i]:-}" ]]; then
        airs_before="${playlist_index_to_episode[$i]}"
        break
      fi
    done
    airs_before="${airs_before:-999}"

    nfo_path="${filename%.*}.nfo"
    cat > "$nfo_path" <<EOF
<episodedetails>
  <title>${title}</title>
  <plot>Auto-downloaded from Critical Role Season 2 playlist</plot>
  <airsbeforeseason>${SEASON_NUM}</airsbeforeseason>
  <airsbeforeepisode>${airs_before}</airsbeforeepisode>
</episodedetails>
EOF
  fi

  yt-dlp \
    --sponsorblock-mark all \
    --add-metadata \
    --merge-output-format mp4 \
    -o "$filename" \
    "https://www.youtube.com/watch?v=$video_id"
done <<< "$selected"
