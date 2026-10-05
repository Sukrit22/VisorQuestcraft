import java.io.*;
import java.nio.file.*;
import java.util.jar.*;
import java.nio.charset.StandardCharsets;
import pojlib.install.*;
import pojlib.util.json.MinecraftInstances;
public class VisorRuntimeTest {
    static int checks;
    interface Checked { void run() throws Exception; }
    static void check(boolean value) { if (!value) throw new AssertionError(); checks++; }
    static void rejected(Checked action) throws Exception { try { action.run(); } catch (IOException | IllegalArgumentException expected) { checks++; return; } throw new AssertionError("Expected rejection"); }
    static File variant(File original, Path target, String replaceEntry, String from, String to, String addEntry) throws Exception {
        try (JarFile source = new JarFile(original); JarOutputStream out = new JarOutputStream(Files.newOutputStream(target))) {
            java.util.Enumeration<JarEntry> entries = source.entries();
            while (entries.hasMoreElements()) {
                JarEntry item = entries.nextElement(); out.putNextEntry(new JarEntry(item.getName()));
                try (InputStream input = source.getInputStream(item)) {
                    ByteArrayOutputStream bytes = new ByteArrayOutputStream(); byte[] buffer = new byte[8192]; int count;
                    while ((count = input.read(buffer)) != -1) bytes.write(buffer, 0, count);
                    byte[] value = bytes.toByteArray();
                    if (item.getName().equals(replaceEntry)) value = new String(value, StandardCharsets.UTF_8).replace(from, to).getBytes(StandardCharsets.UTF_8);
                    out.write(value);
                }
                out.closeEntry();
            }
            if (addEntry != null) { out.putNextEntry(new JarEntry(addEntry)); out.write(new byte[]{1,2,3}); out.closeEntry(); }
        }
        return target.toFile();
    }
    public static void main(String[] args) throws Exception {
        File root = new File(args[0]);
        File forge = new File(root, "outputs/Visor-0.5.0-android-forge.1+mc1.20.1.jar");
        File fabric = new File(root, "outputs/Visor-0.5.0-android-fabric.1+mc1.20.1.jar");
        File mono = new File(root, "outputs/Visor-0.6.0-alpha.2-android.1+mc1.20.1-forge.jar");
        check(CustomVisor.needsBridge(forge, "Forge"));
        check(CustomVisor.needsBridge(fabric, "Fabric"));
        check(!CustomVisor.needsBridge(mono, "Forge"));
        rejected(() -> CustomVisor.needsBridge(forge, "Fabric"));
        rejected(() -> CustomVisor.needsBridge(fabric, "Forge"));
        rejected(() -> CustomVisor.needsBridge(mono, "Fabric"));
        rejected(() -> VisorRuntime.validate("visor-0.6", "Fabric"));
        rejected(() -> VisorRuntime.validate("unknown", "Forge"));
        check(VisorRuntime.core("unmanaged", "Forge") == null);
        check(VisorRuntime.core("visor-0.5", "Forge").equals(VisorRuntime.FORGE_05));
        CustomVisor.validateSelection("https://example.com/custom.jar", null); checks++;
        rejected(() -> CustomVisor.validateSelection("http://example.com/custom.jar", null));
        rejected(() -> CustomVisor.validateSelection("https://user:secret@example.com/custom.jar", null));
        rejected(() -> CustomVisor.validateSelection("https://example.com/custom.jar", "bad"));
        Path temp = Files.createTempDirectory("visor-runtime-tests");
        File wrongForgeMc = variant(forge, temp.resolve("forge-wrong-mc.jar"), "META-INF/mods.toml", "[1.20,1.20.1]", "[1.20.10]", null);
        rejected(() -> CustomVisor.needsBridge(wrongForgeMc, "Forge"));
        File wrongFabricMc = variant(fabric, temp.resolve("fabric-wrong-mc.jar"), "fabric.mod.json", "1.20.1", "1.20.10", null);
        rejected(() -> CustomVisor.needsBridge(wrongFabricMc, "Fabric"));
        File duplicateBridge = variant(forge, temp.resolve("duplicate-bridge.jar"), null, "", "", "org/vmstudio/visor/android/QuestVLoader.class");
        rejected(() -> CustomVisor.needsBridge(duplicateBridge, "Forge"));
        File desktopNative = variant(forge, temp.resolve("desktop-native.jar"), null, "", "", "native/test.dll");
        rejected(() -> CustomVisor.needsBridge(desktopNative, "Forge"));
        File invalid = temp.resolve("invalid.jar").toFile(); Files.write(invalid.toPath(), new byte[]{1,2,3});
        rejected(() -> CustomVisor.needsBridge(invalid, "Forge"));
        MinecraftInstances.Instance instance = new MinecraftInstances.Instance();
        instance.gameDir = temp.toString(); instance.modLoader = "Forge";
        instance.visorUrl = "https://invalid.invalid/no-network-needed.jar";
        instance.visorSha256 = CustomVisor.digest(mono);
        Path cache = temp.resolve("visor-downloads"); Files.createDirectories(cache);
        Path pinned = cache.resolve(instance.visorSha256 + ".jar"); Files.copy(mono.toPath(), pinned);
        check(CustomVisor.prepare(instance).toPath().equals(pinned));
        rejected(() -> CustomVisor.verifyDownloaded(mono, "0000000000000000000000000000000000000000000000000000000000000000", "Forge"));
        check(CustomVisor.verifyDownloaded(mono, instance.visorSha256, "Forge").equals(instance.visorSha256));
        check(CustomVisor.digest(mono).matches("[0-9a-f]{64}"));
        System.out.println("PASS: " + checks + " runtime selection, Android architecture, URL/hash and offline cache checks");
    }
}
