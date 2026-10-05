package pojlib.install;
import java.io.*;
import java.nio.file.*;
import java.util.*;
import com.google.gson.Gson;
import pojlib.util.json.MinecraftInstances;
public class FabricLoaderProfileTest {
    static int checks;
    interface Checked { void run() throws Exception; }
    static void check(boolean value) { if (!value) throw new AssertionError("Check " + (checks + 1)); checks++; }
    static void rejected(Checked operation) throws Exception { try { operation.run(); } catch (IOException | IllegalArgumentException expected) { checks++; return; } throw new AssertionError("Expected rejection"); }
    static VersionInfo fixture(Path root, String version) throws Exception {
        return new Gson().fromJson(new String(Files.readAllBytes(root.resolve("tools/fixtures/fabric-1.20.1-" + version + "-profile.json")), "UTF-8"), VersionInfo.class);
    }
    static String libraries(VersionInfo profile, String home) {
        List<String> files = new ArrayList<>();
        for (VersionInfo.Library library : profile.libraries) files.add(home + "/libraries/" + FabricLoaderProfile.libraryPath(library.name));
        return String.join(File.pathSeparator, files);
    }
    public static void main(String[] args) throws Exception {
        Path root = Paths.get(args[0]);
        VersionInfo oldProfile = fixture(root, "0.16.14"), newProfile = fixture(root, "0.17.2");
        FabricLoaderProfile.validateProfile(oldProfile, "1.20.1", "0.16.14"); checks++;
        FabricLoaderProfile.validateProfile(newProfile, "1.20.1", "0.17.2"); checks++;
        rejected(() -> FabricLoaderProfile.validateVersion("latest"));
        rejected(() -> FabricLoaderProfile.validateVersion("0.17.2/../../"));
        rejected(() -> FabricLoaderProfile.validateVersion("00.17.2"));
        rejected(() -> FabricLoaderProfile.validateProfile(newProfile, "1.20.2", "0.17.2"));
        rejected(() -> FabricLoaderProfile.validateProfile(oldProfile, "1.20.1", "0.17.2"));
        String home = "C:/unchanged-game";
        String oldLibraries = libraries(oldProfile, home), newLibraries = libraries(newProfile, home);
        String vanilla = home + "/libraries/com/google/guava/guava/31.1-jre/guava-31.1-jre.jar";
        String client = home + "/versions/1.20.1/client.jar", lwjgl = home + "/lwjgl3/lwjgl-glfw-classes.jar", hack = home + "/hacks/ResConfHack.jar";
        String oldClasspath = String.join(File.pathSeparator, client, vanilla, oldLibraries, lwjgl, hack);
        String updated = FabricLoaderProfile.migrateClasspath(oldClasspath, FabricLoaderProfile.libraryNames(oldProfile), FabricLoaderProfile.libraryNames(newProfile), newLibraries);
        check(updated.equals(String.join(File.pathSeparator, client, vanilla, newLibraries, lwjgl, hack)));
        check(!updated.contains("fabric-loader/0.16.14/"));
        check(updated.contains("fabric-loader/0.17.2/"));
        check(updated.contains("asm/9.8/"));
        String[] upgradedEntries = updated.split(java.util.regex.Pattern.quote(File.pathSeparator));
        check(Arrays.stream(upgradedEntries).filter(value -> value.contains("/intermediary/")).count() == 1);
        check(Arrays.stream(upgradedEntries).filter(value -> value.contains("/sponge-mixin/")).count() == 1);
        check(FabricLoaderProfile.migrateClasspath(updated, FabricLoaderProfile.libraryNames(newProfile), FabricLoaderProfile.libraryNames(oldProfile), oldLibraries).equals(oldClasspath));
        // Shared vanilla ASM and repeated Loader are replaced by Maven identity, not filename substring.
        String duplicate = String.join(File.pathSeparator, client, home + "/libraries/org/ow2/asm/asm/9.6/asm-9.6.jar", vanilla, oldLibraries, oldLibraries, lwjgl, hack);
        String unique = FabricLoaderProfile.migrateClasspath(duplicate, FabricLoaderProfile.libraryNames(oldProfile), FabricLoaderProfile.libraryNames(newProfile), newLibraries);
        check(!unique.contains("/asm/9.6/"));
        check(Arrays.stream(unique.split(java.util.regex.Pattern.quote(File.pathSeparator))).filter(value -> value.contains("/fabric-loader/")).count() == 1);
        check(unique.indexOf(client) < unique.indexOf(vanilla) && unique.indexOf(vanilla) < unique.indexOf(lwjgl) && unique.indexOf(lwjgl) < unique.indexOf(hack));
        check(FabricLoaderProfile.inferVersion(oldClasspath).equals("0.16.14"));
        check(FabricLoaderProfile.inferVersion(updated.replace('/', '\\')).equals("0.17.2"));
        MinecraftInstances.Instance instance = new MinecraftInstances.Instance(); instance.classpath = oldClasspath; instance.modLoader = "Fabric"; instance.versionName = "1.20.1"; instance.mainClass = oldProfile.mainClass;
        check(instance.getSelectedFabricLoaderVersion().equals("0.16.14"));
        instance.fabricLoaderVersion = "0.17.2";
        check(instance.getInstalledFabricLoaderVersion().equals("0.16.14"));
        MinecraftInstances instances = new MinecraftInstances(); instances.instances = new MinecraftInstances.Instance[]{instance};
        Path temporary = Files.createTempDirectory("fabric-profile-commit-"); File registry = temporary.resolve("instances.json").toFile();
        FabricLoaderProfile.saveRegistry(instances, registry);
        FabricLoaderProfile.commitPrepared(instance, instances, newProfile, "0.17.2", "0.16.14", updated, registry);
        check(instance.classpath.equals(updated)); check(instance.getInstalledFabricLoaderVersion().equals("0.17.2"));
        check(instance.fabricJvmArguments.length == 1 && instance.fabricJvmArguments[0].startsWith("-DFabricMcEmu="));
        MinecraftInstances saved = new Gson().fromJson(new String(Files.readAllBytes(registry.toPath()), "UTF-8"), MinecraftInstances.class);
        check(saved.instances[0].classpath.equals(updated));
        try (java.util.stream.Stream<Path> paths = Files.list(temporary)) { check(paths.filter(path -> path.getFileName().toString().startsWith("instances-before-fabric-")).count() == 1); }
        // A directory at the destination makes atomic persistence fail after in-memory assignment.
        File blocked = temporary.resolve("blocked.json").toFile(); Files.createDirectory(blocked.toPath()); Files.write(blocked.toPath().resolve("keep"), new byte[]{1});
        instance.fabricLoaderVersion = "0.16.14";
        rejected(() -> FabricLoaderProfile.commitPrepared(instance, instances, oldProfile, "0.16.14", "0.17.2", oldClasspath, blocked));
        check(instance.classpath.equals(updated)); check(instance.getInstalledFabricLoaderVersion().equals("0.17.2"));
        check(instance.mainClass.equals(newProfile.mainClass)); check(instance.fabricJvmArguments.length == 1);
        check(Files.exists(blocked.toPath().resolve("keep")));
        // Legacy instances with no requested setting do not fetch or silently upgrade.
        MinecraftInstances.Instance legacy = new MinecraftInstances.Instance(); legacy.classpath = oldClasspath; legacy.modLoader = "Fabric"; legacy.versionName = "1.20.1";
        FabricLoaderProfile.applyRequested(legacy, instances, temporary.toFile(), registry); check(legacy.classpath.equals(oldClasspath));
        System.out.println("PASS: " + checks + " real Fabric profile migration, version inference and commit rollback checks");
        if (args.length > 1 && "--live".equals(args[1])) {
            VersionInfo live = FabricLoaderProfile.fetch("1.20.1", "0.17.2");
            String installed = FabricLoaderProfile.installLibraries(live, root.resolve("build/fabric-loader-live").toFile());
            String[] paths = installed.split(java.util.regex.Pattern.quote(File.pathSeparator));
            if (paths.length != live.libraries.length) throw new AssertionError("Missing live library");
            for (String path : paths) if (!new File(path).isFile()) throw new AssertionError("Missing downloaded jar");
            System.out.println("PASS: live official Fabric 0.17.2 profile and all " + paths.length + " verified Maven libraries installed");
        }
    }
}
