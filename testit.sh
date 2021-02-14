

export GCP_CREDENTIALS=$(cat /home/ask/.secrets/askapps-8714096322c0.json)
#export BUCKET=otp_est_test
export BUCKET=otp_est_test
mix compile --force
#iex -S mix

mix test
