

export GCP_CREDENTIALS=$(cat /home/ask/git/.secrets/askapps-7b6e83304aa0.json)
#export BUCKET=otp_est_test
export BUCKET=stadler_no_test
mix compile --force
#iex -S mix

mix test
