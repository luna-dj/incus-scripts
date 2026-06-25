# Matrix bridge appservice wiring for ess-helm (element-hq/ess-helm)
# This file documents the per-bridge config snippet you paste into your
# values.yaml override. Works with matrix-stack chart (ess-helm main).
#
# Usage: pick the bridge(s) you deployed, paste the matching block under
# `matrix-stack:` (or whatever your top-level chart key is). Adjust the
# bridge IPs to match your incus container IPs.
#
# Assumptions:
#   - Bridges are deployed via incus-scripts on the same network as
#     the kubernetes cluster (so k8s pods can reach incus IPs)
#   - Each bridge exposes a tiny static HTTP server on port 9876 serving
#     its registration.yaml (started via the bridge's systemd unit)
#
# The init-container fetches the registration.yaml from the bridge
# container over the LAN on first pod startup. Synapse reads it from
# /data/ and registers the appservice.

# ═══════════════════════════════════════════════════════════════════════
# ONE-TIME SETUP (do this once per bridge container after incus deploy)
# ═══════════════════════════════════════════════════════════════════════
#
# 1. Enable the bridge's HTTP-serve systemd unit (in the bridge container):
#
#    incus exec <bridge> -- bash -c '
#      cat > /etc/systemd/system/<bridge>-serve.service <<EOF
# [Unit]
# Description=<bridge> registration.yaml HTTP server
# After=network-online.target
#
# [Service]
# Type=simple
# ExecStartPre=/usr/bin/apt-get install -y -qq busybox-static
# ExecStart=/bin/busybox httpd -f -p 9876 -h /etc/<bridge>
# Restart=on-failure
#
# [Install]
# WantedBy=multi-user.target
# EOF
#      systemctl daemon-reload
#      systemctl enable --now <bridge>-serve.service
#    '
#
# 2. Verify it's serving:
#    incus exec <bridge> -- curl http://localhost:9876/registration.yaml
#
# 3. Note the bridge's IP from `incus list` (e.g. 192.168.100.52).
#    Replace <BRIDGE_IP> in the snippet below.

# ═══════════════════════════════════════════════════════════════════════
# values.yaml snippet (paste under matrix-stack:)
# ═══════════════════════════════════════════════════════════════════════

matrix-stack:
  synapse:
    # Existing config...
    config:
      homeserver.yaml:
        additional:
          # ... your existing homeserver.yaml additions ...

          # Register all appservices at once. Each bridge ships its
          # own registration.yaml via init-container (below).
          app_service_config_files:
            - /data/mautrix-telegram-registration.yaml
            - /data/mautrix-whatsapp-registration.yaml
            - /data/mautrix-signal-registration.yaml
            - /data/mautrix-discord-registration.yaml
            - /data/mautrix-slack-registration.yaml
            - /data/mautrix-googlechat-registration.yaml
            - /data/mautrix-meta-registration.yaml
            - /data/heisenbridge-registration.yaml
            - /data/bifrost-registration.yaml
            - /data/appservice-irc-registration.yaml
            - /data/matrix-appservice-email-registration.yaml
            - /data/mx-puppet-slack-registration.yaml
            - /data/matrix-appservice-kakaotalk-registration.yaml

    # Init containers fetch each registration.yaml from its bridge
    # container on every pod start. Failures are tolerated (continue
    # means the pod starts even if a bridge is down — bridges can be
    # added later without redeploying synapse).
    initContainers:
      - name: fetch-bridge-registrations
        image: curlimages/curl:8.8.0
        command: ['sh', '-c']
        args:
          - |
            set +e
            for pair in \
              "mautrix-telegram|http://192.168.100.XX:9876/registration.yaml" \
              "mautrix-whatsapp|http://192.168.100.XX:9876/registration.yaml" \
              "mautrix-signal|http://192.168.100.XX:9876/registration.yaml" \
              "mautrix-discord|http://192.168.100.XX:9876/registration.yaml" \
              "mautrix-slack|http://192.168.100.XX:9876/registration.yaml" \
              "mautrix-googlechat|http://192.168.100.XX:9876/registration.yaml" \
              "mautrix-meta|http://192.168.100.XX:9876/registration.yaml" \
              "heisenbridge|http://192.168.100.XX:9876/registration.yaml" \
              "bifrost|http://192.168.100.XX:9876/registration.yaml" \
              "appservice-irc|http://192.168.100.XX:9876/registration.yaml" \
              "matrix-appservice-email|http://192.168.100.XX:9876/registration.yaml" \
              "mx-puppet-slack|http://192.168.100.XX:9876/registration.yaml" \
              "matrix-appservice-kakaotalk|http://192.168.100.XX:9876/registration.yaml"
            do
              name="${pair%%|*}"
              url="${pair#*|}"
              echo "Fetching $name from $url"
              curl -fsSL --max-time 10 "$url" \
                -o "/data/${name}-registration.yaml" \
                && echo "  OK: /data/${name}-registration.yaml" \
                || echo "  WARN: failed to fetch $name (bridge may be down)"
            done
            exit 0
        volumeMounts:
          - name: synapse-data
            mountPath: /data

    # If synapse-data isn't already a named volume you can mount, add:
    extraVolumes: []
    extraVolumeMounts: []

# ═══════════════════════════════════════════════════════════════════════
# Per-bridge templating (recommended: factor this with helm/templating)
# ═══════════════════════════════════════════════════════════════════════
#
# If you have many bridges, turn the above into a list-driven template
# in your own chart overlay (not in ess-helm itself):
#
#   bridges:
#     - name: mautrix-telegram
#       ip: 192.168.100.52
#     - name: mautrix-whatsapp
#       ip: 192.168.100.53
#     # ...
#
# Then in templates/synapse-bridges.yaml:
#
#   {{- range .values.bridges }}
#   - name: fetch-{{ .name }}-registration
#     image: curlimages/curl:8.8.0
#     command: ['sh', '-c']
#     args:
#       - |
#         curl -fsSL --max-time 10 \
#           "http://{{ .ip }}:9876/registration.yaml" \
#           -o "/data/{{ .name }}-registration.yaml"
#     volumeMounts:
#       - name: synapse-data
#         mountPath: /data
#   {{- end }}
#
#   {{- range .values.bridges }}
#   - /data/{{ .name }}-registration.yaml
#   {{- end }}
#
# This keeps the values.yaml clean and lets you add/remove bridges
# without editing the synapse block.

# ═══════════════════════════════════════════════════════════════════════
# Verification (after helmfile apply)
# ═══════════════════════════════════════════════════════════════════════
#
# kubectl -n <ns> logs <synapse-pod> -c synapse | grep -i appservice
#   # Should print: "Registered appservice: mautrix-telegram" etc.
#
# kubectl -n <ns> logs <synapse-pod> -c fetch-bridge-registrations
#   # Should show OK: /data/mautrix-telegram-registration.yaml
#
# ls /data/  # inside the synapse pod:
#   # Should list all 13 registration.yaml files

# ═══════════════════════════════════════════════════════════════════════
# Pitfalls
# ═══════════════════════════════════════════════════════════════════════
#
# 1. The init container runs BEFORE synapse starts. If a bridge IP is
#    unreachable, the curl fails — but we use `set +e` and `|| true` so
#    the pod still starts. Bridge registration just won't happen that
#    time. Restart synapse after fixing the bridge.
#
# 2. busybox httpd is single-threaded and drops connections on slow
#    networks. If you see "Failed to connect" errors in init container
#    logs, switch to `darkhttpd` (multithreaded):
#      apt-get install -y darkhttpd
#      darkhttpd /etc/<bridge> --port 9876 --foreground
#
# 3. The `url:` field in registration.yaml must point to a URL synapse
#    can reach (used for appservice→HS push). The bridge-common.sh
#    script sets it to HS_URL ($HS_URL) — so it's https://matrix.femdev.nl
#    if you set that env var at deploy time. Verify:
#
#      incus exec <bridge> -- grep ^url: /etc/<bridge>/registration.yaml
#      # url: "https://matrix.femdev.nl"
#
# 4. If you change the HS_URL after deploy, you must regenerate
#    registration.yaml (the tokens stay the same — just edit the `url:`
#    line and restart the bridge).
#
# 5. macOS host: mautrix-imessage can't run on Linux incus — deploy
#    it on the Mac with `brew install mautrix-imessage` and serve its
#    registration.yaml over the LAN on port 9876 same as the others.