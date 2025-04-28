from PIL import Image
import os

# Lista svih potrebnih ikonica (ime fajla, širina, visina)
ICONS = [
    ("Icon-1024.png", 1024, 1024),
    ("Icon-60@2x.png", 120, 120),
    ("Icon-60@3x.png", 180, 180),
    ("Icon-76@2x.png", 152, 152),
    ("Icon-Small-40@2x.png", 80, 80),
    ("Icon-Small-40@3x.png", 120, 120),
    ("Icon-Small@2x.png", 58, 58),
    ("Icon-Small@3x.png", 87, 87),
    ("Icon-20@2x.png", 40, 40),
    ("Icon-20@3x.png", 60, 60),
    ("Icon-29@2x.png", 58, 58),
    ("Icon-29@3x.png", 87, 87),
    ("Icon-40@2x.png", 80, 80),
    ("Icon-40@3x.png", 120, 120),
    ("Icon-76@2x.png", 152, 152),
    ("Icon-83.5@2x.png", 167, 167),
    ("Icon-1024.png", 1024, 1024)
]

def generate_icons(input_path, output_dir):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    img = Image.open(input_path)
    for name, w, h in ICONS:
        icon = img.resize((w, h), Image.LANCZOS)
        icon.save(os.path.join(output_dir, name))
        print(f"Sačuvana ikonica: {name} ({w}x{h})")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        print("Upotreba: python generate_ios_icons.py <putanja_do_slike> <output_folder>")
        sys.exit(1)
    generate_icons(sys.argv[1], sys.argv[2]) 