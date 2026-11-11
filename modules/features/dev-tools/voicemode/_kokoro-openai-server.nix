{
  lib,
  fetchurl,
  linkFarm,
  python3Packages,
  writers,
  writeShellApplication,
}:
let
  revision = "f3ff3571791e39611d31c381e3a41a3af07b4987";

  fetchModelFile =
    name: hash:
    fetchurl {
      url = "https://huggingface.co/hexgrad/Kokoro-82M/resolve/${revision}/${name}";
      inherit hash;
    };

  # Every American (a*) and British (b*) English voice; the server's language
  # dependencies cover English only.
  voiceHashes = {
    af_alloy = "sha256-bYdxSd2LNI+60S5YRbfkPZdTkOnztoqBHR2GFovvWqM=";
    af_aoede = "sha256-wDvRpMNxbC2Oqj1QAi9i1cMc+9bhWTOgCxf+/hOEHMQ=";
    af_bella = "sha256-jLZOAvzI3gMnqOE4F+ScdslF7PAFLOrJfTCBSA6OSNY=";
    af_heart = "sha256-CrVwm4/6sZv9hJzRHZj3W2CvdzMlOtDWexI4KhAstP8=";
    af_jessica = "sha256-zf3MuMyXWqNO5riWQpY7AGQjdnXeDkGjCuZMyVjdToc=";
    af_kore = "sha256-i/vFEjIcPbSd/5hKxnX6Wsfq7VqWzDEQTTqQgOF51p0=";
    af_nicole = "sha256-xVYYCLz1JQ/oxfXeMsry2U8n5X6Vvv2wmMXIWZHUxdo=";
    af_nova = "sha256-4CM2dt3CGQjDeh8QL2uIpZ5OXBvXZJg2Fuue2mKdvNI=";
    af_river = "sha256-4UlFm9nAhEFrdHVrm9NBglaouDkIirsH1GNzDDadq48=";
    af_sarah = "sha256-Sb02TqO+nrPpaF6PmhVEjEiDESp8D/erE5+kCIsIzvk=";
    af_sky = "sha256-x5lUiu0G4MsNZVqFoBtI5/EEhNcWY/mjBFpbk2LoUSw=";
    am_adam = "sha256-ztfihKuhJHKJG+HaOrNNuEzAXMArWIlTV5bb8tiwyzQ=";
    am_echo = "sha256-i8/chSvJhftFw5bFYeVx/7kYOTAHH5YvG1DfXJexYeg=";
    am_eric = "sha256-raZvDu//NOySGx10dNesi+wAzYY8Fw8cU0kW6bghKq4=";
    am_fenrir = "sha256-mOUH7KHbCCMK47YjLVnBCuyWMAItGazKxPXRL87Dw3o=";
    am_liam = "sha256-yCVQdX3bMTCLl/MAQN2owtYJqeLeYTWEjQqUg2gThRg=";
    am_michael = "sha256-mkQ7eaSyJImlsKt8ZRoLzRowvvZ1woMz8Glxq71HvTc=";
    am_onyx = "sha256-6EUr4WzQ9tp7RXnq97HkUG6SUkiCBT2G1yuWuaf+1YQ=";
    am_puck = "sha256-3R2Jc/TOS32K5AfHekNfSF2rwFIIG4DqdcTzC4TzYiM=";
    am_santa = "sha256-fy91gvorHxYOkKr+bQtEKmhedzYItmZ+VF10Owc+l6c=";
    bf_alice = "sha256-0pJlG2r2wNgXBcJYDctEY/zMD/e41hikcdu05FZVs/M=";
    bf_emma = "sha256-0KQj3qv0pStPSTGMUXQsVOIbuJu76aEhQed1jdtdpwE=";
    bf_isabella = "sha256-zdTDcAOAUQTR0I+x4FhVyPssaN4kym5x8mSjCqpZ7v0=";
    bf_lily = "sha256-bgnC5IHi1TAE1+WufToyU2nhMKb0XDWmAC3nUIS+koU=";
    bm_daniel = "sha256-/D/OTpwS7U28j6loDP5R7hkKlkRM58OtZHVJowgj/F0=";
    bm_fable = "sha256-1Ek18xNSV6kGTfmfAH/BNC/xqnZ1UrSk+kw7Lm5ZB5w=";
    bm_george = "sha256-8byBIhPcWXdHaeXIAASxPut5vXgTCxGy1/k0VC2rgRs=";
    bm_lewis = "sha256-tSBHUNy6AQKdKsnOwXrsOyCm1kBzxXnWlKI8tA7/vQ4=";
  };

  modelDir = linkFarm "kokoro-82m" (
    [
      {
        name = "config.json";
        path = fetchModelFile "config.json" "sha256-WrsB4kA7ByvwPQT94WBEPiCdeg2tSaQjvhUZa5tDwX8=";
      }
      {
        name = "kokoro-v1_0.pth";
        path = fetchModelFile "kokoro-v1_0.pth" "sha256-SW26EY0aWPXz2y78iNvcIW4Eg/yJ/m5H7h8sU/GK0eQ=";
      }
    ]
    ++ lib.mapAttrsToList (voice: hash: {
      name = "voices/${voice}.pt";
      path = fetchModelFile "voices/${voice}.pt" hash;
    }) voiceHashes
  );

  server = writers.writePython3 "kokoro-openai-server-unwrapped" {
    libraries = with python3Packages; [
      kokoro
      numpy
      spacy-models.en_core_web_sm
    ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./_kokoro-openai-server.py);
in
writeShellApplication {
  name = "kokoro-openai-server";
  text = ''
    export HF_HUB_OFFLINE=1
    exec ${server} --model-dir ${modelDir} "$@"
  '';
}
