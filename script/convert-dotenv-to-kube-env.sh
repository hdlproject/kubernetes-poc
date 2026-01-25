#!/bin/sh

ENV_FILE="$1"
DEPLOY_FILE="$2"
PLACEHOLDER="envhere"

TMP_ENV_BLOCK="$(mktemp)"

# Build the env block from .env
{
  IFS=$'\n'
  CONTENT=$(grep -v '^#' "$ENV_FILE")

  if [ ${#CONTENT} -gt 0 ]
  then
    echo "          env:"
  fi

  for line in $CONTENT; do
    key=$(echo "$line" | cut -d '=' -f 1)
    value=$(echo "$line" | cut -d '=' -f 2-)
    echo "            - name: $key"
    echo "              value: $value"
  done

  unset IFS
} > "$TMP_ENV_BLOCK"

# Replace placeholder with env block
if grep -q "$PLACEHOLDER" "$DEPLOY_FILE"; then
  # Use sed to replace the placeholder line with the generated block
  # macOS sed requires backup suffix; we remove it afterwards.
  sed -i '.bak' -e "/$PLACEHOLDER/{
    r $TMP_ENV_BLOCK
    d
  }" "$DEPLOY_FILE"
  rm -f "$DEPLOY_FILE.bak"
else
  echo "Placeholder not found: $PLACEHOLDER" >&2
  rm -f "$TMP_ENV_BLOCK"
  exit 1
fi

rm -f "$TMP_ENV_BLOCK"
echo "Injected env block into '$DEPLOY_FILE' at placeholder."
