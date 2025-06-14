#!/bin/bash

set -e

PROJECT_DIR="/Users/perrypark24/Desktop/Aptos_Project"
MOVE_FILE="$PROJECT_DIR/sources/Aptos_meme_coin.move"
TOML_FILE="$PROJECT_DIR/Move.toml"
ADMIN_PROFILE="adminparkerp"
USER_PREFIX="userparkerp"
USER_PROFILE1="userparkerp1"
USER_PROFILE2="userparkerp2"
USER_PROFILE3="userparkerp3"
NUM_USERS=3

# -------------- Dependency Check --------------
echo "🔍 Checking for required dependencies..."
for cmd in jq yq; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ $cmd is required but not installed. Install it with 'brew install $cmd'"
    exit 1
  else
    echo "✅ $cmd is already installed."
  fi
done

# -------------- Delete Old Profiles --------------
echo -e "\n🧹 Deleting old CLI profiles..."
if aptos config show-profiles | grep -q "$ADMIN_PROFILE"; then
  aptos config delete-profile --profile "$ADMIN_PROFILE" || true
else
  echo "ℹ️  Profile $ADMIN_PROFILE does not exist, skipping."
fi

for i in $(seq 1 $NUM_USERS); do
  PROFILE="$USER_PREFIX$i"
  if aptos config show-profiles | grep -q "$PROFILE"; then
    aptos config delete-profile --profile "$PROFILE" || true
  else
    echo "ℹ️  Profile $PROFILE does not exist, skipping."
  fi
done

# -------------- Init Profiles --------------
echo -e "\n🔧 Creating Aptos CLI profiles..."
echo "Configuring for profile $ADMIN_PROFILE"
RETRIES=5
until aptos init --profile $ADMIN_PROFILE --network local --assume-yes; do
  echo "⏳ Faucet rate limited for $ADMIN_PROFILE. Retrying in 5s..."
  sleep 5
  RETRIES=$((RETRIES - 1))
  if [ $RETRIES -eq 0 ]; then
    echo "❌ Failed to create profile $ADMIN_PROFILE after retries."
    exit 1
  fi
done

for i in $(seq 1 $NUM_USERS); do
  PROFILE="$USER_PREFIX$i"
  echo "Configuring for profile $PROFILE"
  RETRIES=5
  until aptos init --profile $PROFILE --network local --assume-yes; do
    echo "⏳ Faucet rate limited for $PROFILE. Retrying in 5s..."
    sleep 5
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -eq 0 ]; then
      echo "❌ Failed to create profile $PROFILE after retries."
      exit 1
    fi
  done
done

# -------------- Get Addresses --------------
echo -e "\n📬 Extracting account addresses..."
ADMIN_ADDR=$(aptos account lookup-address --profile $ADMIN_PROFILE | jq -r '.Result')
echo "📬 Admin address:  $ADMIN_ADDR"

USER_ADDRS=()
for i in $(seq 1 $NUM_USERS); do
  PROFILE="$USER_PREFIX$i"
  ADDR=$(aptos account lookup-address --profile $PROFILE | jq -r '.Result')
  USER_ADDRS+=("$ADDR")
  echo "📬 $PROFILE address: $ADDR"
done

# -------------- Update Move and TOML Files --------------
echo -e "\n✍️ Updating Move and TOML files..."
sed -i '' "s|your_address = \".*\"|your_address = \"0x$ADMIN_ADDR\"|" "$TOML_FILE"
sed -i '' "s|0xDEADBEEF|0x$ADMIN_ADDR|g" "$MOVE_FILE"

if grep -qE "module 0x[a-f0-9]{64}::meme_coin" "$MOVE_FILE"; then
  sed -i '' "s/module 0x[a-f0-9]\{64\}::meme_coin/module 0x$ADMIN_ADDR::meme_coin/" "$MOVE_FILE"
fi

if grep -qE "coin::balance<0x[a-f0-9]{64}::meme_coin::CoinInfo>" "$MOVE_FILE"; then
  sed -i '' "s|coin::balance<0x[a-f0-9]\{64\}::meme_coin::CoinInfo>|coin::balance<0x$ADMIN_ADDR::meme_coin::CoinInfo>|" "$MOVE_FILE"
fi

echo "✅ Source files updated."

# -------------- Clean Build Artifacts --------------
echo -e "\n🧹 Cleaning old build artifacts..."
rm -rf "$PROJECT_DIR/build"

# -------------- Publish --------------
echo -e "\n🚀 Publishing Move module..."
aptos move publish --profile $ADMIN_PROFILE --assume-yes

# -------------- Initialize Contract --------------
echo -e "\n⚙️ Initializing contract..."
aptos move run \
  --function-id "0x$ADMIN_ADDR::meme_coin::initialize" \
  --profile $ADMIN_PROFILE \
  --assume-yes

# -------------- Whitelist All Users --------------
echo -e "\n✅ Whitelisting users..."
for ADDR in "${USER_ADDRS[@]}"; do
  aptos move run \
    --function-id "0x$ADMIN_ADDR::meme_coin::add_to_whitelist" \
    --args address:$ADDR \
    --profile $ADMIN_PROFILE \
    --assume-yes
done

# -------------- Register + Claim for Each User --------------
echo -e "\n🎁 Registering and claiming for each user..."
for i in $(seq 1 $NUM_USERS); do
  PROFILE="$USER_PREFIX$i"
  ADDR="${USER_ADDRS[$((i-1))]}"

  echo -e "\n👤 $PROFILE ($ADDR)"

  aptos move run \
    --function-id "0x1::managed_coin::register" \
    --type-args "0x$ADMIN_ADDR::meme_coin::CoinInfo" \
    --profile $PROFILE \
    --assume-yes

  aptos move run \
    --function-id "0x$ADMIN_ADDR::meme_coin::claim" \
    --args address:$ADDR \
    --profile $ADMIN_PROFILE \
    --assume-yes

  aptos move view \
    --function-id "0x$ADMIN_ADDR::meme_coin::get_igc_balance" \
    --args address:$ADDR \
    --profile $ADMIN_PROFILE
done

# -------------- Test Repeat Claim for First User --------------
echo -e "\n🧪 Attempting double claim test for ${USER_ADDRS[0]}..."
PROFILE="$USER_PROFILE1"
ADDR="${USER_ADDRS[0]}"

set +e
CLAIM_OUTPUT=$(aptos move run \
  --function-id "0x$ADMIN_ADDR::meme_coin::claim" \
  --args address:$ADDR \
  --profile $ADMIN_PROFILE \
  --assume-yes 2>&1)
EXIT_CODE=$?
set -e

echo "$CLAIM_OUTPUT"

if [[ $EXIT_CODE -ne 0 ]]; then
  if echo "$CLAIM_OUTPUT" | grep -q "0x6507"; then
    echo -e "\n✅ Claim blocked: 🛑 Already claimed or not whitelisted (abort code 0x6507)"
  elif echo "$CLAIM_OUTPUT" | grep -q "0x1"; then
    echo -e "\n✅ Claim blocked: ⏰ Claim window expired (abort code 0x1)"
  else
    echo -e "\n⚠️ Unknown claim rejection reason."
  fi
else
  echo -e "\n❌ Claim unexpectedly succeeded."
fi