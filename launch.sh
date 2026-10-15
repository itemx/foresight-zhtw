#!/bin/zsh
# Launches Foresight with the Chinese transcription shim. Restarts it if it is already running.
# launch.sh [zh|ja|en|ko|yue]  -> pin SenseVoice's language (default: ~/tools/foresight-zh/language, else auto)
# FORESIGHT_ZH_TRACE=1 launch.sh  -> log every ODML call and transcript result to ~/Library/Logs/foresight-zh/shim.log
SHIM="$HOME/tools/foresight-zh/shim/libforesight_zh.dylib"
FORESIGHT_ZH_LANG=${1:-$FORESIGHT_ZH_LANG}
if pgrep -x Foresight >/dev/null; then
  osascript -e 'tell application "Foresight" to quit' >/dev/null 2>&1
  for _ in {1..20}; do pgrep -x Foresight >/dev/null || break; sleep 0.5; done
  pkill -x Foresight 2>/dev/null; sleep 1
fi
env_args=(--env "DYLD_INSERT_LIBRARIES=$SHIM")
[[ -n "$FORESIGHT_ZH_TRACE" ]] && env_args+=(--env "FORESIGHT_ZH_TRACE=$FORESIGHT_ZH_TRACE")
[[ -n "$FORESIGHT_ZH_LANG" ]] && env_args+=(--env "FORESIGHT_ZH_LANG=$FORESIGHT_ZH_LANG")
exec open "${env_args[@]}" -a Foresight
