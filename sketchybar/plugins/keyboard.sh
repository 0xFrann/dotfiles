#!/bin/sh

SOURCE_ID=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null \
    | grep "KeyboardLayout Name" \
    | head -1 \
    | awk -F'= ' '{gsub(/[";[:space:]]/, "", $2); print $2}')

if [ -z "$SOURCE_ID" ]; then
    SOURCE_ID=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null \
        | grep "Input Mode" \
        | head -1 \
        | awk -F'= ' '{gsub(/[";[:space:]]/, "", $2); print $2}' \
        | awk -F. '{print $NF}')
fi

case "$SOURCE_ID" in
    U.S.|US|ABC|"Australian"|"British"|USInternational*) LANG_LABEL="EN" ;;
    Hebrew|Hebrew-QWERTY)                                LANG_LABEL="HE" ;;
    Spanish|Spanish-ISO)                                 LANG_LABEL="ES" ;;
    French)                                              LANG_LABEL="FR" ;;
    German)                                              LANG_LABEL="DE" ;;
    Italian)                                             LANG_LABEL="IT" ;;
    Portuguese)                                          LANG_LABEL="PT" ;;
    Russian)                                             LANG_LABEL="RU" ;;
    Arabic|ArabicPC)                                     LANG_LABEL="AR" ;;
    Japanese|Hiragana)                                   LANG_LABEL="JA" ;;
    Korean)                                              LANG_LABEL="KO" ;;
    "Simplified Chinese"|"Traditional Chinese")          LANG_LABEL="ZH" ;;
    *)                                                   LANG_LABEL="$SOURCE_ID" ;;
esac

sketchybar --set "$NAME" label="$LANG_LABEL"
