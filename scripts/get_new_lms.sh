# Fetch latest LMS x86-64 releases
amd64_URL=$(curl -sL "https://lyrion.org/downloads/" \
  | grep -oE 'https?://[^"]*lyrionmusicserver_[0-9]+\.[0-9]+\.[0-9]+~[0-9]+_amd64\.deb' \
  | tail -n 1)

if [ -z "$amd64_URL" ]; then
  echo "未找到 ARM deb，请检查页面" >&2
  exit 1
else
  echo "$amd64_URL"
fi



# Fetch latest LMS arm/arm64 releases
arm_URL=$(curl -sL "https://lyrion.org/downloads/" \
  | grep -oE 'https?://[^"]*lyrionmusicserver_[0-9]+\.[0-9]+\.[0-9]+~[0-9]+_arm\.deb' \
  | tail -n 1)

if [ -z "$arm_URL" ]; then
  echo "未找到 ARM deb，请检查页面" >&2
  exit 1
else
  echo "$arm_URL"
fi
  