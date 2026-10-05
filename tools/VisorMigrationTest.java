import java.io.*;
import java.nio.file.*;
import java.util.*;
import pojlib.install.*;
import pojlib.util.json.MinecraftInstances;
import android.app.Activity;
public class VisorMigrationTest {
    static int checks;
    static void check(boolean value) { if (!value) throw new AssertionError(); checks++; }
    static Map<String,String> snapshot(Path directory) throws Exception {
        Map<String,String> files = new TreeMap<>();
        if (Files.exists(directory)) try (java.util.stream.Stream<Path> paths = Files.walk(directory)) {
            for (Iterator<Path> i = paths.iterator(); i.hasNext();) {
                Path path = i.next(); if (Files.isRegularFile(path)) files.put(directory.relativize(path).toString(), CustomVisor.digest(path.toFile()));
            }
        }
        return files;
    }
    static long backupCount(Path root) throws Exception { return snapshot(root.resolve("visor-backups")).size(); }
    public static void main(String[] args) throws Exception {
        File root = new File(args[0]);
        Activity activity = new Activity(new File(root, "sources/Pojlib/src/main/assets"));
        Path game = Files.createTempDirectory("visor-real-installer-");
        MinecraftInstances.Instance instance = new MinecraftInstances.Instance();
        instance.gameDir = game.toString(); instance.modLoader = "Forge"; instance.versionName = "1.20.1";
        // Null fields exercise the actual legacy-default getter.
        check("visor-0.5".equals(instance.getVisorRuntime()));
        Installer.installVisor(activity, instance);
        Path mods = game.resolve("mods");
        String oldHash = CustomVisor.digest(mods.resolve(VisorRuntime.FORGE_05).toFile());
        check(snapshot(mods).size() == 2);
        check(Files.exists(mods.resolve("Visor-Android-Bridge-0.1.1.jar")));
        instance.setVisorRuntime("visor-0.6"); Installer.installVisor(activity, instance);
        check(snapshot(mods).size() == 1);
        check(Files.exists(mods.resolve(VisorRuntime.FORGE_06)));
        check(!Files.exists(mods.resolve("Visor-Android-Bridge-0.1.1.jar")));
        check(backupCount(game) == 2);
        check(snapshot(game.resolve("visor-backups")).containsValue(oldHash));
        instance.setVisorRuntime("visor-0.5"); Installer.installVisor(activity, instance);
        check(snapshot(mods).size() == 2);
        check(CustomVisor.digest(mods.resolve(VisorRuntime.FORGE_05).toFile()).equals(oldHash));
        check(backupCount(game) == 3);
        Map<String,String> unchanged = snapshot(game);
        Installer.installVisor(activity, instance);
        check(snapshot(game).equals(unchanged)); // No repeated replacement/backup.
        instance.setVisorRuntime("unmanaged"); Installer.installVisor(activity, instance);
        check(snapshot(game).equals(unchanged)); // No runtime or backup mutation.
        // A malformed pinned custom JAR must fail before retiring any active runtime.
        Path cache = game.resolve("visor-downloads"); Files.createDirectories(cache);
        Path malformed = cache.resolve("malformed"); Files.write(malformed, new byte[]{1,2,3});
        String hash = CustomVisor.digest(malformed.toFile());
        Files.move(malformed, cache.resolve(hash + ".jar"));
        instance.setVisorRuntime("custom"); instance.visorUrl = "https://invalid.invalid/unused.jar"; instance.visorSha256 = hash;
        Map<String,String> oldMods = snapshot(mods); Map<String,String> oldBackups = snapshot(game.resolve("visor-backups"));
        try { Installer.installVisor(activity, instance); throw new AssertionError("Malformed custom JAR accepted"); }
        catch (IOException expected) { checks++; }
        check(snapshot(mods).equals(oldMods)); check(snapshot(game.resolve("visor-backups")).equals(oldBackups));
        // Missing companion asset fails during staging, preserving core/bridge.
        instance.setVisorRuntime("visor-0.6"); Installer.installVisor(activity, instance);
        Map<String,String> monoMods = snapshot(mods); Map<String,String> monoBackups = snapshot(game.resolve("visor-backups"));
        Path incompleteAssets = Files.createTempDirectory("visor-incomplete-assets-");
        Path coreAsset = incompleteAssets.resolve("mods/forge/" + VisorRuntime.FORGE_05);
        Files.createDirectories(coreAsset.getParent());
        Files.copy(new File(root, "sources/Pojlib/src/main/assets/mods/forge/" + VisorRuntime.FORGE_05).toPath(), coreAsset);
        instance.setVisorRuntime("visor-0.5");
        try { Installer.installVisor(new Activity(incompleteAssets.toFile()), instance); throw new AssertionError("Missing companion accepted"); }
        catch (IOException expected) { checks++; }
        check(CustomVisor.digest(mods.resolve(VisorRuntime.FORGE_06).toFile()).equals(monoMods.get(VisorRuntime.FORGE_06)));
        check(snapshot(game.resolve("visor-backups")).equals(monoBackups));
        System.out.println("PASS: " + checks + " real Installer migration, preservation, idempotence and failure checks");
    }
}
