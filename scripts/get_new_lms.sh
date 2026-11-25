# Fetch latest LMS x86-64 releases
arm_IMG_URL=$(curl -sL "https://lyrion.org/downloads/" \
  | grep -oE 'https?://[^"]*lyrionmusicserver_[0-9]+\.[0-9]+\.[0-9]+~[0-9]+_amd64\.deb' \
  | tail -n 1)  
echo $arm_IMG_URL

# Fetch latest LMS arm/arm64 releases
arm_IMG_URL=$(curl -sL "https://lyrion.org/downloads/" \
  | grep -oE 'https?://[^"]*lyrionmusicserver_[0-9]+\.[0-9]+\.[0-9]+~[0-9]+_arm\.deb' \
  | tail -n 1)
  
echo $arm_IMG_URL