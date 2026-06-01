# Encryption Keys (CSEK) — GCS Customer-Supplied Encryption

Customer-Supplied Encryption Keys (CSEK) allow you to provide your own AES-256 encryption key for GCS objects, rather than relying on Google-managed keys. Google uses your key to encrypt/decrypt data but never stores it.

## How It Works

1. You generate a 256-bit AES key
2. You pass the key via the `.boto` config or `gsutil` flags for each operation
3. Google uses your key but **never stores it** — you must provide it for every read/write

---

## Step 1: Generate a CSEK

```bash
python3 generate-csek.py
```

This outputs a base64-encoded 256-bit key. Save it securely — if lost, the encrypted data cannot be recovered.

---

## Step 2: Create an Encrypted Bucket

```bash
gsutil mb gs://$DEVSHELL_PROJECT_ID-csek
```

---

## Step 3: Upload a File with CSEK

Replace `YOUR_OWN_ENCRYPTION_KEY` with the base64 key from Step 1:

```bash
gsutil -o 'GSUtil:encryption_key=YOUR_OWN_ENCRYPTION_KEY' \
    cp csek.txt gs://$DEVSHELL_PROJECT_ID-csek/csek.txt
```

---

## Step 4: Read the Encrypted File

```bash
gsutil -o 'GSUtil:decryption_key1=YOUR_OWN_ENCRYPTION_KEY' \
    cat gs://$DEVSHELL_PROJECT_ID-csek/csek.txt
```

---

## Step 5: Configure via .boto File (Optional)

Instead of passing the key inline every time, you can configure it in `.boto`:

```bash
gsutil config -n  # creates ~/.boto
```

Then add to `~/.boto`:

```ini
[GSUtil]
encryption_key = YOUR_OWN_ENCRYPTION_KEY
decryption_key1 = YOUR_OWN_ENCRYPTION_KEY
```

---

## Important Notes

- ⚠️ **Key loss = data loss**: There is no recovery path if you lose your CSEK.
- Google validates the key on every operation — wrong key returns a 400 error.
- CSEK works at the object level, not the bucket level.
- For a managed alternative, use **Cloud KMS** (`--kms-key` flag) which lets Google manage key storage while you control access.
