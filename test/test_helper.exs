:ok = LocalCluster.start()

Application.ensure_all_started(:otp_es)
ExUnit.start()
