_: {
  flake.modules.homeManager.voicemode-client =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.den.voicemode.client;

      authorizationHeader = pkgs.writeShellScript "voicemode-authorization-header" ''
        ${lib.getExe pkgs.jq} -n --rawfile token ${lib.escapeShellArg cfg.tokenFile} \
          '{ Authorization: ("Bearer " + ($token | rtrimstr("\n"))) }'
      '';
    in
    {
      key = "den:homeManager.voicemode-client";

      options.den.voicemode.client.tokenFile = lib.mkOption {
        type = lib.types.str;
        description = ''
          File holding the bearer token `voicemode serve` was started with.
          Read when Claude Code connects, so it never enters the Nix store.
        '';
      };

      config.programs.claude-code.mcpServers.voicemode = {
        type = "http";
        url = "http://127.0.0.1:8765/mcp";
        headersHelper = "${authorizationHeader}";
      };
    };
}
