from PIL import Image
import os
import shutil

# Source icon
icon_path = r'd:\repo\mobile\mqtt_iot\assets\icons\app_icon.png'
project_root = r'd:\repo\mobile\mqtt_iot'

# Android icon sizes (size, folder)
android_sizes = [
    (48, 'mipmap-mdpi'),
    (72, 'mipmap-hdpi'),
    (96, 'mipmap-xhdpi'),
    (144, 'mipmap-xxhdpi'),
    (192, 'mipmap-xxxhdpi'),
]

# iOS icon sizes
ios_sizes = [
    (20, '20x20@1x'),
    (40, '20x20@2x'),
    (60, '20x20@3x'),
    (29, '29x29@1x'),
    (58, '29x29@2x'),
    (87, '29x29@3x'),
    (40, '40x40@1x'),
    (80, '40x40@2x'),
    (120, '40x40@3x'),
    (120, '60x60@2x'),
    (180, '60x60@3x'),
    (1024, '1024x1024@1x'),
]

# Load original image
img = Image.open(icon_path).convert('RGBA')
print(f"Loaded icon: {img.size}")

# Process Android icons
print("\nProcessing Android icons...")
for size, folder in android_sizes:
    resized = img.resize((size, size), Image.Resampling.LANCZOS)
    folder_path = os.path.join(project_root, 'android', 'app', 'src', 'main', 'res', folder)
    
    # Ensure folder exists
    os.makedirs(folder_path, exist_ok=True)
    
    output_path = os.path.join(folder_path, 'ic_launcher.png')
    resized.save(output_path, 'PNG')
    print(f"  ✓ {size}x{size} -> {folder}/ic_launcher.png")

# Process iOS icons
print("\nProcessing iOS icons...")
ios_folder = os.path.join(project_root, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
os.makedirs(ios_folder, exist_ok=True)

for size, name in ios_sizes:
    resized = img.resize((size, size), Image.Resampling.LANCZOS)
    output_path = os.path.join(ios_folder, f'Icon-{name}.png')
    resized.save(output_path, 'PNG')
    print(f"  ✓ {size}x{size} -> Icon-{name}.png")

print("\n✅ All icons processed successfully!")
