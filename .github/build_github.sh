# move lc to working folder
mv "$archive_path.xcarchive/Products/Applications" Payload

# package
zip -r "$scheme.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
