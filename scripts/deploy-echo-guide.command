#!/bin/zsh -l
# Double-click to redeploy Echo's guide backend to Supabase.
cd "$(dirname "$0")/.."
echo "Deploying echo-guide to Supabase…"
supabase functions deploy echo-guide --no-verify-jwt --use-api --project-ref itjoqbgcwhcancpdfqzu 2>&1 | tee scripts/deploy-echo-guide.log
echo "exit: ${pipestatus[1]}" >> scripts/deploy-echo-guide.log
echo
echo "Done — you can close this window."
