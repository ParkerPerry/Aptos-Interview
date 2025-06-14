# Your Meme Coin Claim Contract

This project is a Move module for Aptos that enables an administrator to manage a whitelisted token claim for a custom fungible asset called Intergalactic Creatures (IGC).

Whitelisted users are allowed to claim exactly 100 IGC tokens — but only if they:

* Are on the whitelist
* Claim before a specified `end_time`

After a successful claim, the user is automatically removed from the whitelist to prevent multiple claims.

---

## ✅ QUICK START: Run the Full Script

The easiest way to run the entire claim flow is to use the included Bash script:

### 1. Set the Project Path

Inside `test_meme_coin.sh`, set the following:

```bash
PROJECT_DIR="/Users/perrypark24/Desktop/Aptos_Project"
```

Make sure this path matches the full path to your local project directory.

### 2. Run the Script

Then from your terminal:

```bash
bash test_meme_coin.sh
```

This will:

* Create Aptos profiles
* Publish the Move module
* Initialize the IGC coin
* Whitelist users
* Register accounts for the coin
* Mint 100 IGC to each whitelisted user
* Run a double-claim rejection test
* Print balances

---

## 🔄 How Address Substitution & Automation Works

When you run the script, it dynamically generates all the required addresses (admin + users) using `aptos init` and automatically extracts them using:

```bash
aptos account lookup-address --profile <profile_name>
```

Once retrieved, these addresses are:

* Inserted into `Move.toml` under `your_address = "0x..."`
* Replaced in `sources/Aptos_meme_coin.move` wherever a hardcoded address was used

This means you **don’t have to manually update** any address in the code — the script ensures that your deployed module and type signatures use the live admin address, and all CLI commands reference correct user addresses.

You’ll see all substitutions printed in the console as the script runs.

---

## ⭮️ END-TO-END FLOW (Who Does What)

### 1. Admin Profile Setup & Module Deployment

* The script creates the `adminparkerp` Aptos profile.
* Publishes the `meme_coin.move` module to chain.
* Calls the `initialize` function:

  * Creates the IGC coin.
  * Stores a whitelist table.
  * Sets the claim `end_time` to `now + 86400` seconds (1 day).

✅ Admin is the only one who can initialize, whitelist, and mint.

### 2. User Profiles Setup

* Creates 3 user profiles: `userparkerp1`, `userparkerp2`, `userparkerp3`.
* Retrieves and prints their addresses.

### 3. Whitelist Each User

* Admin uses `add_to_whitelist` to insert each user’s address.
* Whitelist is a dynamic on-chain `table::Table<address, bool>`.

### 4. User Registers for the Coin

Each user registers to receive the coin:

```bash
aptos move run \
  --function-id "0x1::managed_coin::register" \
  --type-args "0x<admin_address>::meme_coin::CoinInfo"
```

This is required to hold or receive the IGC coin.

### 5. Admin Claims Tokens for Each User

Admin executes the claim for each whitelisted user:

```bash
aptos move run \
  --function-id "0x<admin_address>::meme_coin::claim" \
  --args address:0x<user_address> \
  --profile adminparkerp
```

Inside `claim`:

* Confirms claim is within the time window
* Removes the user from the whitelist
* Mints 100 IGC tokens to that user

### 6. Balance Verification

Queries the token balance for each user via:

```bash
aptos move view \
  --function-id "0x<admin_address>::meme_coin::get_igc_balance" \
  --args address:0x<user_address>
```

### 7. Double Claim Rejection Test

* Attempts a second claim for user1.
* Fails with abort code `0x6507` due to whitelist removal.
* Script detects and logs the expected rejection.

---

## 🧠 WHY THIS DESIGN WORKS

* ✅ Users cannot claim twice — whitelist entry is removed.
* ✅ Admin-only execution ensures controlled minting.
* ✅ Expiration logic enforces a strict claim deadline.
* ✅ Uses `managed_coin` for safe minting.
* ✅ Uses `table` for flexible, on-chain whitelisting.

---

## 🔒 SAFETY & FINALITY

* Users cannot self-claim or spoof.
* All minting is admin-initiated and timestamp-controlled.
* Only pre-approved addresses can receive the airdrop.

---

## 📁 File Structure

* `Move.toml` – Project manifest
* `sources/meme_coin.move` – Core Move module
* `test_meme_coin.sh` – Full test automation script
* `README.md` – This documentation

---

## 🙌 Done!

You now have a fully functional, testable, and secure whitelisted token claim contract on Aptos.