# Fetch latest LMS x86-64 releases
arm_IMG_URL=$(curl -sL "https://lyrion.org/downloads/#v920-development-build" \
  | jq -r '.[] 
	| select(.tag_name | test("lyrionmusicserver_9.2.0"; "i")) 
	| .assets[] 
	| select(.name | test("lyrionmusicserver_9.2.0~*_amd64.deb\\.img\\.gz$")) 
	| .browser_download_url' \
  | head -n 1)
  
echo $arm_IMG_URL

# Fetch latest LMS arm/arm64 releases
arm_IMG_URL=$(curl -sL "https://lyrion.org/downloads/#v920-development-build" \
  | jq -r '.[] 
	| select(.tag_name | test("lyrionmusicserver_9.2.0"; "i")) 
	| .assets[] 
	| select(.name | test("lyrionmusicserver_9.2.0~*_arm.deb\\.img\\.gz$")) 
	| .browser_download_url' \
  | head -n 1)
  
echo $arm_IMG_URL