# Encryption Keys — Customer-Supplied Encryption Keys (CSEK)

Demonstrates using Customer-Supplied Encryption Keys (CSEK) with Google Cloud Storage buckets.

## Files

| File | Description |
|------|-------------|
| [`generate-csek.py`](./generate-csek.py) | Python script to generate a CSEK key |
| [`bucket.sh`](./bucket.sh) | Shell script for GCS bucket operations with CSEK |
| [`steps.md`](./steps.md) | Step-by-step guide for CSEK usage |

## Quick Start

```bash
# Generate a CSEK key
python3 generate-csek.py

# Follow the steps in steps.md for bucket operations
```

## References

- [Customer-Supplied Encryption Keys](https://cloud.google.com/storage/docs/encryption/customer-supplied-keys)
- [CSEK with gsutil](https://cloud.google.com/storage/docs/gsutil/addlhelp/SupplyingYourOwnEncryptionKeys)
