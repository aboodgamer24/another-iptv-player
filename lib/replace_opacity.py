import os
import re

def replace_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Regex to find .withOpacity(value) and replace with .withValues(alpha: value)
    # This regex is simple and might need refinement if there are nested parentheses
    # But for most Flutter code it should work.
    new_content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True
    return False

def main():
    lib_dir = r'c:\Users\abdua\kzjqa-lhkhp\BotsProject\iptv\another-iptv-player\lib'
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if replace_in_file(filepath):
                    print(f'Updated: {filepath}')

if __name__ == '__main__':
    main()
