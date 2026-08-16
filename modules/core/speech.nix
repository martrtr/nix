{ pkgs, ... }:
let
  fetchVoice = path: hash:
    pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/${path}";
      inherit hash;
    };

  piperVoices = pkgs.runCommand "piper-voices" { } ''
    mkdir -p "$out"

    ln -s ${fetchVoice "ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx" "sha256-j/OCEtI9owC743BcZF5uW5R18L/eAVWOsXgT4irKqqo="} "$out/ru_RU-irina-medium.onnx"
    ln -s ${fetchVoice "ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx.json" "sha256-wuwouzjitZ6TuVmz5ANIwa/rvScvMP7V1BIF0I6Yqdc="} "$out/ru_RU-irina-medium.onnx.json"
    ln -s ${fetchVoice "en/en_US/lessac/medium/en_US-lessac-medium.onnx" "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8="} "$out/en_US-lessac-medium.onnx"
    ln -s ${fetchVoice "en/en_US/lessac/medium/en_US-lessac-medium.onnx.json" "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA="} "$out/en_US-lessac-medium.onnx.json"
    ln -s ${fetchVoice "de/de_DE/thorsten/medium/de_DE-thorsten-medium.onnx" "sha256-fmR2LY5RGLtXjy7qYgfho1qODDBZUBC2ZvmD/Ie7eBk="} "$out/de_DE-thorsten-medium.onnx"
    ln -s ${fetchVoice "de/de_DE/thorsten/medium/de_DE-thorsten-medium.onnx.json" "sha256-l0re55BTOtsnOhrIj0kCfSobjw8s9JBZVKR5HnkmToU="} "$out/de_DE-thorsten-medium.onnx.json"
  '';

  piperSpeech = pkgs.writeShellApplication {
    name = "piper-speech";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.piper-tts
      pkgs.pipewire
    ];
    text = ''
      set -euo pipefail

      language="$1"
      voice="$2"
      rate="$3"
      text="$(${pkgs.coreutils}/bin/cat)"

      case "$voice" in
        irina) model="${piperVoices}/ru_RU-irina-medium.onnx" ;;
        lessac) model="${piperVoices}/en_US-lessac-medium.onnx" ;;
        thorsten) model="${piperVoices}/de_DE-thorsten-medium.onnx" ;;
        *)
          case "$language" in
            ru*) model="${piperVoices}/ru_RU-irina-medium.onnx" ;;
            de*) model="${piperVoices}/de_DE-thorsten-medium.onnx" ;;
            *) model="${piperVoices}/en_US-lessac-medium.onnx" ;;
          esac
          ;;
      esac

      length_scale="$(${pkgs.gawk}/bin/awk -v rate="$rate" 'BEGIN { printf "%.2f", 1 - rate / 200 }')"
      temporary_directory="$(${pkgs.coreutils}/bin/mktemp --directory)"
      audio_file="$temporary_directory/speech.wav"
      trap '${pkgs.coreutils}/bin/rm -rf "$temporary_directory"' EXIT

      printf '%s' "$text" | ${pkgs.piper-tts}/bin/piper \
        --model "$model" \
        --length-scale "$length_scale" \
        --output-file "$audio_file"
      ${pkgs.pipewire}/bin/pw-play "$audio_file"
    '';
  };
in
{
  services.speechd = {
    enable = true;
    config = ''
      CommunicationMethod "unix_socket"
      LogLevel 3
      DefaultVolume 100
      DefaultVoiceType "FEMALE1"
      SymbolsPreproc "none"
      AudioOutputMethod "libao"

      AddModule "piper" "sd_generic" "piper.conf"
      DefaultModule "piper"
      LanguageDefaultModule "ru" "piper"
      LanguageDefaultModule "en" "piper"
      LanguageDefaultModule "de" "piper"
    '';
    modules.piper = ''
      GenericDefaultCharset "utf-8"
      GenericLanguage "ru" "ru" "utf-8"
      GenericLanguage "en" "en" "utf-8"
      GenericLanguage "de" "de" "utf-8"

      GenericExecuteSynth "printf %s \'$DATA\' | ${piperSpeech}/bin/piper-speech '$LANGUAGE' '$VOICE' '$RATE'"

      AddVoice "ru" "FEMALE1" "irina"
      AddVoice "ru" "MALE1" "irina"
      AddVoice "en" "FEMALE1" "lessac"
      AddVoice "en" "MALE1" "lessac"
      AddVoice "de" "FEMALE1" "thorsten"
      AddVoice "de" "MALE1" "thorsten"
    '';
  };
}
