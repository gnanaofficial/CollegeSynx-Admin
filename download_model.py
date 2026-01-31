import os
import urllib.request
import urllib.error

urls = [
    "https://raw.githubusercontent.com/shubham0204/Face-Recognition-Flutter/main/assets/mobilefacenet.tflite",
    "https://raw.githubusercontent.com/PiyushMaheswari/Face-Recognition-Flutter/main/assets/mobilefacenet.tflite",
    "https://raw.githubusercontent.com/Rajat-2005/Face-Recognition-Flutter/main/assets/mobilefacenet.tflite"
]

output_dir = "assets/models"
output_file = os.path.join(output_dir, "mobilefacenet.tflite")

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

for url in urls:
    print(f"Trying {url}...")
    try:
        urllib.request.urlretrieve(url, output_file)
        if os.path.getsize(output_file) > 1000: # Check if it's not a tiny 404 page
            print(f"Success! Downloaded to {output_file}")
            print(f"Size: {os.path.getsize(output_file)} bytes")
            exit(0)
        else:
            print("File too small, likely invalid.")
    except Exception as e:
        print(f"Failed: {e}")

print("All downloads failed.")
exit(1)
