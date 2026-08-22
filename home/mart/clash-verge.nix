{ config, lib, pkgs, ... }:
let
  appId = "io.github.clash-verge-rev.clash-verge-rev";
  appDir = "${config.xdg.dataHome}/${appId}";

  profile = pkgs.writeText "clash-verge-profile.yaml" ''
    mode: rule
    log-level: info
    ipv6: false
    find-process-mode: always

    tun:
      enable: true
      stack: system
      auto-route: true
      auto-redirect: true
      auto-detect-interface: true
      strict-route: false
      endpoint-independent-nat: true
      udp-timeout: 300
      mtu: 1500
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
      proxy-server-nameserver:
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
          override-destination: true

    proxy-providers:
      BlancVPN:
        type: file
        path: ./providers/blancvpn.yaml
        filter: "🇩🇪|🇦🇹|🇨🇿|🇳🇱|🇵🇱|🇫🇮|🇸🇪"
        health-check:
          enable: true
          url: https://cp.cloudflare.com
          interval: 300
          timeout: 5000
          lazy: false
          expected-status: 204
        override:
          ip-version: ipv4

      Personal:
        type: file
        path: ./providers/personal.yaml
        override:
          ip-version: ipv4

    proxy-groups:
      - name: PAID
        type: select
        use: [BlancVPN]

      - name: PERSONAL
        type: select
        use: [Personal]

      - name: PROXY
        type: select
        proxies: [PAID, PERSONAL, DIRECT]
        default-selected: PAID

      - name: RU
        type: select
        proxies: [DIRECT, PAID, PERSONAL]

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
      - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
      - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
      - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
      - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
      - IP-CIDR,169.254.0.0/16,DIRECT,no-resolve
      - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve
      - RULE-SET,ru-blocked,PROXY
      - RULE-SET,rkn-asn-block,PROXY
      - GEOSITE,category-ru,RU
      - GEOIP,RU,RU,no-resolve
      - DOMAIN-SUFFIX,ru,RU
      - DOMAIN-SUFFIX,su,RU
      - NETWORK,udp,PROXY
      - MATCH,PROXY
  '';

  emptyProvider = pkgs.writeText "clash-verge-empty-provider.yaml" ''
    proxies: []
  '';

  globalScript = pkgs.writeText "clash-verge-global-script.js" ''
    function main(config, profileName) {
      if (!config || typeof config !== "object" || Array.isArray(config)) {
        return {};
      }

      config.ipv6 = false;

      config.tun =
        config.tun && typeof config.tun === "object" && !Array.isArray(config.tun)
          ? config.tun
          : {};
      config.tun.stack = "system";
      config.tun.mtu = 1500;
      config.tun["dns-hijack"] = ["any:53", "tcp://any:53"];

      config.dns =
        config.dns && typeof config.dns === "object" && !Array.isArray(config.dns)
          ? config.dns
          : {};
      config.dns.ipv6 = false;
      config.dns["default-nameserver"] = ["1.1.1.1", "8.8.8.8"];
      config.dns["proxy-server-nameserver"] = ["1.1.1.1", "8.8.8.8"];
      config.dns.nameserver = [
        "https://1.1.1.1/dns-query#PROXY",
        "https://8.8.8.8/dns-query#PROXY",
      ];
      delete config.dns["fake-ip-range6"];

      return config;
    }
  '';

  mergeConfig = pkgs.writeText "clash-verge-merge.yaml" ''
    profile:
      store-selected: true

    ipv6: false
  '';

  profiles = pkgs.writeText "clash-verge-profiles.yaml" ''
    current: Local
    items:
      - uid: Local
        type: local
        name: Local routing
        desc: Paid and personal proxy providers with Russian resources routed directly
        file: Local.yaml
  '';

  coreConfig = pkgs.writeText "clash-verge-core.yaml" ''
    redir-port: 7895
    tproxy-port: 7896
    mixed-port: 7897
    socks-port: 7898
    port: 7899
    log-level: info
    allow-lan: false
    ipv6: false
    mode: rule
    tun:
      enable: false
      stack: system
      auto-route: true
      strict-route: false
      auto-detect-interface: true
      dns-hijack:
        - any:53
        - tcp://any:53
  '';

  dnsConfig = pkgs.writeText "clash-verge-dns.yaml" ''
    dns:
      enable: true
      ipv6: false
      enhanced-mode: fake-ip
      fake-ip-range: 198.18.0.1/16
      fake-ip-filter:
        - "*.lan"
        - "*.local"
        - "*.arpa"
        - localhost
      default-nameserver:
        - system
        - 1.1.1.1
        - 8.8.8.8
      nameserver:
        - https://1.1.1.1/dns-query
        - https://8.8.8.8/dns-query
      proxy-server-nameserver:
        - https://1.1.1.1/dns-query
        - https://8.8.8.8/dns-query
      use-hosts: false
      use-system-hosts: false
  '';

  verge = pkgs.writeText "clash-verge-verge.yaml" ''
    theme_mode: dark
    enable_tun_mode: true
    enable_system_proxy: false
    enable_auto_launch: false
    enable_silent_start: false
    auto_close_connection: true
  '';

  applyRuntimeSettings = pkgs.writeShellScript "clash-verge-runtime-settings" ''
    socket="$XDG_RUNTIME_DIR/clash-verge-rev/verge-mihomo.sock"

    for attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
      if ${pkgs.curl}/bin/curl \
        --silent \
        --show-error \
        --fail \
        --unix-socket "$socket" \
        -X PATCH \
        -H 'Content-Type: application/json' \
        --data '{"ipv6":false}' \
        http://localhost/configs
      then
        exit 0
      fi

      ${pkgs.coreutils}/bin/sleep 1
    done

    exit 0
  '';
in
{
  home.activation.seedClashVerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    app_dir=${lib.escapeShellArg appDir}
    profiles_dir="$app_dir/profiles"
    providers_dir="$app_dir/providers"

    ${pkgs.coreutils}/bin/mkdir -p "$profiles_dir" "$providers_dir"

    if [ ! -e "$profiles_dir/Local.yaml" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${profile} "$profiles_dir/Local.yaml"
    fi

    if [ ! -e "$profiles_dir/Script.js" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${globalScript} "$profiles_dir/Script.js"
    fi

    if [ ! -e "$profiles_dir/Merge.yaml" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${mergeConfig} "$profiles_dir/Merge.yaml"
    fi

    for provider in blancvpn personal; do
      if [ ! -e "$providers_dir/$provider.yaml" ]; then
        ${pkgs.coreutils}/bin/install -m 600 ${emptyProvider} "$providers_dir/$provider.yaml"
      fi
    done

    if [ ! -e "$app_dir/profiles.yaml" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${profiles} "$app_dir/profiles.yaml"
    fi

    if [ ! -e "$app_dir/config.yaml" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${coreConfig} "$app_dir/config.yaml"
    fi

    if [ ! -e "$app_dir/dns_config.yaml" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${dnsConfig} "$app_dir/dns_config.yaml"
    fi

    if [ ! -e "$app_dir/verge.yaml" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${verge} "$app_dir/verge.yaml"
    fi
  '';

  systemd.user.services.clash-verge-runtime-settings = {
    Unit = {
      Description = "Apply Clash Verge runtime network settings";
      After = [ "app-Clash\\x20Verge@autostart.service" ];
      PartOf = [ "app-Clash\\x20Verge@autostart.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = applyRuntimeSettings;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
