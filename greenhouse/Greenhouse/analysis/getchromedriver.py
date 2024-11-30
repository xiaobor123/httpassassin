import requests,subprocess,os
chorme_driver_json_url = "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json"
response = requests.get(chorme_driver_json_url).json()
chrome_version = subprocess.check_output("google-chrome --version",shell=True).decode("utf-8").split(" ")[2]
chrome_driver_linux64_url = None
for driver in response["versions"]:
    if driver["version"] == chrome_version:
        for chromedriver in driver['downloads']['chromedriver']:
            if chromedriver['platform'] == 'linux64':
                chrome_driver_linux64_url = chromedriver['url']
                break
        break

# Downloading the ChromeDriver
if chrome_driver_linux64_url:
    response = requests.get(chrome_driver_linux64_url, stream=True)
    chrome_driver_path = os.path.join(os.path.dirname(__file__), "chromedriver-linux64.zip")
    with open(chrome_driver_path, 'wb') as file:
        for chunk in response.iter_content(chunk_size=8192):
            file.write(chunk)
    print(f"ChromeDriver has been downloaded and saved to {chrome_driver_path}")
else:
    print("Could not find the ChromeDriver download link for linux64.")