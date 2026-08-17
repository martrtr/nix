{ config, lib, pkgs, ... }:
let
  appId = "io.github.clash-verge-rev.clash-verge-rev";
  appDir = "${config.xdg.dataHome}/${appId}";

  sshRuProfile = pkgs.writeText "clash-verge-ssh-ru.yaml" ''
    mode: rule
    log-level: info
    ipv6: false

    tun:
      enable: true
      stack: mixed
      auto-route: true
      auto-redirect: true
      auto-detect-interface: true
      strict-route: true
      route-exclude-address:
        - 194.87.97.119/32
      dns-hijack:
        - any:53
        - tcp://any:53

    dns:
      enable: true
      ipv6: false
      enhanced-mode: fake-ip
      fake-ip-range: 198.18.0.1/16
      fake-ip-filter:
        - "*.lan"
        - "*.local"
        - localhost
      default-nameserver:
        - 1.1.1.1
        - 8.8.8.8
      nameserver:
        - https://1.1.1.1/dns-query#PROXY
        - https://8.8.8.8/dns-query#PROXY

    sniffer:
      enable: true
      force-dns-mapping: true
      parse-pure-ip: true
      sniff:
        HTTP:
          ports: [80, 8080-8880]
          override-destination: true
        TLS:
          ports: [443, 8443]
          override-destination: true
        QUIC:
          ports: [443, 8443]

    proxies:
      - name: SSH-DE
        type: ssh
        server: 194.87.97.119
        port: 22
        username: root
        private-key: /home/mart/.ssh/id_ed25519

    proxy-groups:
      - name: PROXY
        type: select
        proxies:
          - SSH-DE
          - DIRECT

      - name: RU
        type: select
        proxies:
          - DIRECT
          - SSH-DE

    rule-providers:
      ru-blocked:
        type: http
        behavior: domain
        format: mrs
        url: https://raw.githubusercontent.com/legiz-ru/mihomo-rule-sets/main/ru-bundle/rule.mrs
        path: ./rules/ru-blocked.mrs
        interval: 86400
        proxy: PROXY

      rkn-asn-block:
        type: http
        behavior: ipcidr
        format: mrs
        url: https://raw.githubusercontent.com/legiz-ru/mihomo-rule-sets/main/ru-bundle/rknasnblock.mrs
        path: ./rules/rkn-asn-block.mrs
        interval: 86400
        proxy: PROXY

    rules:
      # Never tunnel local networks or the SSH server itself.
      - IP-CIDR,194.87.97.119/32,DIRECT,no-resolve
      - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
      - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
      - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
      - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
      - IP-CIDR,169.254.0.0/16,DIRECT,no-resolve
      - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve

      # Russian blocklists win before the general RU-direct rules.
      - RULE-SET,ru-blocked,PROXY
      - RULE-SET,rkn-asn-block,PROXY

      # Russian resources stay direct when they are not explicitly blocked.
      - GEOSITE,category-ru,RU
      - GEOIP,RU,RU,no-resolve

      # Mihomo's SSH outbound is TCP-only. Reject QUIC so browsers retry HTTPS
      # over TCP; leave other UDP direct until a UDP-capable outbound is added.
      - AND,((NETWORK,udp),(DST-PORT,443)),REJECT
      - NETWORK,udp,DIRECT

      # Everything else uses the SSH VPS.
      - MATCH,PROXY
  '';

  profiles = pkgs.writeText "clash-verge-profiles.yaml" ''
    current: Lsshru
    items:
      - uid: Lsshru
        type: local
        name: SSH RU
        desc: Russia direct, blocked and foreign TCP through root@194.87.97.119
        file: Lsshru.yaml
  '';

  verge = pkgs.writeText "clash-verge-verge.yaml" ''
    theme_mode: dark
    enable_tun_mode: true
    enable_system_proxy: false
    enable_auto_launch: false
    enable_silent_start: false
    auto_close_connection: true
  '';
in
{
  # Clash Verge owns these files after first launch. Home Manager only seeds a
  # useful first profile and never replaces later edits made through the GUI.
  home.activation.seedClashVerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    app_dir=${lib.escapeShellArg appDir}
    profiles_dir="$app_dir/profiles"

    ${pkgs.coreutils}/bin/mkdir -p "$profiles_dir"

    if [ ! -e "$profiles_dir/Lsshru.yaml" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${sshRuProfile} "$profiles_dir/Lsshru.yaml"
    fi

    if [ ! -e "$app_dir/profiles.yaml" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${profiles} "$app_dir/profiles.yaml"
    fi

    if [ ! -e "$app_dir/verge.yaml" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${verge} "$app_dir/verge.yaml"
    fi
  '';
}
