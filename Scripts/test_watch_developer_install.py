import io
import plistlib
import struct
import unittest
import zipfile

from watch_developer_install import developer_stream


def local_records(data):
    records = []
    offset = 0
    while data[offset:offset + 4] == b"PK\x03\x04":
        fields = struct.unpack_from("<IHHHHHIIIHH", data, offset)
        _, _, flags, method, _, _, _, size, original, name_length, extra_length = fields
        if flags & 8 or method != 0 or size != original:
            raise AssertionError("Conduit requires stored records without data descriptors")
        name = data[offset + 30:offset + 30 + name_length].decode()
        start = offset + 30 + name_length + extra_length
        records.append((name, data[start:start + size]))
        offset = start + size
    if data[offset:] != b"PK\x01\x02":
        raise AssertionError("Conduit stream must end with only the central-directory marker")
    return records


class WatchDeveloperStreamTests(unittest.TestCase):
    def package(self):
        payload = io.BytesIO()
        with zipfile.ZipFile(payload, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("Payload/Example.app/Info.plist", b"example plist")
            archive.writestr("Payload/Example.app/_CodeSignature/CodeResources", b"sealed resources")
            archive.writestr("Payload/Example.app/Example", bytes(range(256)))
        return payload.getvalue()

    def testMetadataPrecedesAppAndCountsAllRecords(self):
        records = local_records(developer_stream(self.package()))
        self.assertEqual(records[0][0], "META-INF/")
        self.assertEqual(records[1][0], "META-INF/com.apple.ZipMetadata.plist")
        metadata = plistlib.loads(records[1][1])
        self.assertEqual(metadata["RecordCount"], len(records))
        self.assertEqual(metadata["TotalUncompressedBytes"], sum(len(value) for _, value in records[2:]))

    def testTransferPreservesEverySignedByte(self):
        package = self.package()
        records = dict(local_records(developer_stream(package)))
        with zipfile.ZipFile(io.BytesIO(package)) as original:
            for name in original.namelist():
                self.assertEqual(original.read(name), records[name])

    def testMissingDirectoryEntriesAreCreatedBeforeChildren(self):
        names = [name for name, _ in local_records(developer_stream(self.package()))]
        for parent, child in (("Payload/", "Payload/Example.app/"),
                              ("Payload/Example.app/_CodeSignature/", "Payload/Example.app/_CodeSignature/CodeResources")):
            self.assertLess(names.index(parent), names.index(child))


if __name__ == "__main__":
    unittest.main()
