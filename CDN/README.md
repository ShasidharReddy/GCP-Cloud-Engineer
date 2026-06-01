# CDN

Purpose: scripts and instructions to configure Cloud CDN backed by GCS or Compute backends.

Files:
- steps.md — human-readable step-by-step guide
- cdn-setup-script.sh, 1-cdn-setup.sh — automated setup scripts
- delete-cdn-script.sh — cleanup

Quick flow:
1. Prepare origin (GCS bucket or backend service)
2. Run cdn-setup-script.sh after reviewing variables
3. Verify cache behaviour and headers
4. Use delete-cdn-script.sh to tear down

Safety:
- Review scripts and replace placeholder PROJECT_ID / BUCKET names before running.
- Expect changes to DNS and HTTP behaviour when enabling CDN.
