# Before Usage

1. create global variables (e.g. in your .bashrc file)
```sh
# --- CREDENTIALS ---
export ZONE_USERNAME="some_username"
export ZONE_HOST="xxx.xxx.xxx.xxx"
```

2. set `mcptt_local_path` variable right inside `zone_worker.sh` script

# Usage

run `help` command to see aviable options

Suggested Flow:

1. Commit git changes
2. Run `./zone_worker.sh build`
3. *(Optional) Run `./zone_worker.sh new` if you have NOT configured NGINX previously for this*
4. Run `./zone_worker.sh publish`
