"""Check actual DEX class definitions, not descriptor strings/references or assets."""
import argparse
import struct
import zipfile

REQUIRED = (
    'pojlib/API', 'com/google/gson/Gson', 'com/google/gson/GsonBuilder',
    'com/google/gson/reflect/TypeToken', 'com/google/common/collect/ImmutableList',
    'org/apache/commons/io/FileUtils', 'org/apache/commons/codec/binary/Base64',
    'org/apache/commons/math3/geometry/euclidean/threed/Vector3D',
    'androidx/core/math/MathUtils', 'com/microsoft/aad/msal4j/PublicClientApplication',
)

def definitions(data):
    if not data.startswith(b'dex\n'):
        raise ValueError('Not a standard DEX file')
    def u32(offset):
        return struct.unpack_from('<I', data, offset)[0]
    string_count, strings = u32(56), u32(60)
    type_count, types = u32(64), u32(68)
    count, classes = u32(96), u32(100)
    for index in range(count):
        type_index = u32(classes + 32 * index)
        if type_index >= type_count:
            raise ValueError('Invalid DEX class index')
        string_index = u32(types + 4 * type_index)
        if string_index >= string_count:
            raise ValueError('Invalid DEX descriptor index')
        offset = u32(strings + 4 * string_index)
        while data[offset] & 128:
            offset += 1
        offset += 1
        end = data.index(0, offset)
        yield data[offset:end].decode('utf-8')

def inspect(path):
    classes = set()
    with zipfile.ZipFile(path) as apk:
        for name in apk.namelist():
            if '/' not in name and name.startswith('classes') and name.endswith('.dex'):
                classes.update(definitions(apk.read(name)))
    missing = [name for name in REQUIRED if f'L{name};' not in classes]
    for name in REQUIRED:
        print(('MISSING ' if name in missing else 'OK ') + name)
    if missing:
        raise SystemExit(f'{path}: {len(missing)} required launcher classes missing')
    print(f'PASS {path}: {len(REQUIRED)} launcher runtime class definitions')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('apk')
    inspect(parser.parse_args().apk)
