# Before Usage

1. create global variables (e.g. in your .bashrc file)
```sh
# --- CREDENTIALS ---
export ZONE_USERNAME="some_username"
export ZONE_HOST="xxx.xxx.xxx.xxx"
```

2. set `mcptt_local_path` variable right inside `zone_worker.sh` script

# Usage

Suggested Flow:

1. Commit git changes
2. Run `./zone_worker.sh build`
3. *(Optional) Run `./zone_worker.sh new` if you have NOT configured NGINX previously for this*
4. Run `./zone_worker.sh publish`

run `help` command to see aviable options
or look up the table
| Command | Description                                                                                                                     |
|---------|---------------------------------------------------------------------------------------------------------------------------------|
| build   | just run \`./scripts/build.sh\` script                                                                                          |
| publish | take `packages/app/mcptt/build/distribution/` <br/> and send it to `WEB-TO-<branch_index>` on remote server |
| new     | create nginx config files for new port <br/> link these files to main nginx config <br/> ***does not publish builds to server***        |
| help    | show help                                                                                                                       |
