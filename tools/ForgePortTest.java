import com.google.gson.*;
import pojlib.install.ForgeMods;
import pojlib.install.ForgeProfile;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.jar.*;

public class ForgePortTest {
    private static int checks;
    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("forge-port-test-");
        try {
            JsonObject profile;
            try (JarFile installer = new JarFile(args[0]); Reader reader = new InputStreamReader(
                    installer.getInputStream(installer.getJarEntry("version.json")), StandardCharsets.UTF_8)) {
                profile = JsonParser.parseReader(reader).getAsJsonObject();
            }
            // Tiny fixtures test the parser, not Forge installation or runtime compatibility.
            for (JsonElement entry : profile.getAsJsonArray("libraries")) {
                String path = entry.getAsJsonObject().getAsJsonObject("downloads").getAsJsonObject("artifact").get("path").getAsString();
                file(root.resolve("libraries").resolve(path), "fixture");
            }
            Path patched = root.resolve("libraries/net/minecraftforge/forge/" + ForgeProfile.VERSION + "/forge-" + ForgeProfile.VERSION + "-client.jar");
            file(patched, "fixture");
            Path json = root.resolve("profile.json");
            file(json, profile.toString());
            ForgeProfile loaded = ForgeProfile.load(root.toFile());
            File oldRoot = root.resolve("old-forge").toFile();
            String oldLibrary = new File(oldRoot, "libraries/old.jar").getPath();
            String sibling = new File(oldRoot, "libraries-extra/keep.jar").getPath();
            String migrated = ForgeProfile.migrateClasspath("client.jar" + File.pathSeparator + oldLibrary + File.pathSeparator + sibling, oldRoot, loaded.classpath);
            check(!Arrays.asList(migrated.split(java.util.regex.Pattern.quote(File.pathSeparator))).contains(oldLibrary));
            check(migrated.startsWith("client.jar" + File.pathSeparator + sibling + File.pathSeparator));
            check(migrated.endsWith(loaded.classpath));
            check(ForgeProfile.uniqueClasspath("client" + File.pathSeparator + "glfw" + File.pathSeparator + "client" + File.pathSeparator).equals("client" + File.pathSeparator + "glfw"));
            check(loaded.mainClass.equals("cpw.mods.bootstraplauncher.BootstrapLauncher"));
            check(loaded.jvmArguments("testcp").stream().noneMatch(a -> a.contains("${")));
            check(loaded.jvmArguments("testcp").contains("-DlibraryDirectory=" + root.resolve("libraries").toFile().getCanonicalPath()));
            check(loaded.gameArguments("testcp").contains("forgeclient"));
            check(loaded.jvmArguments("testcp").stream().anyMatch(a -> a.startsWith("-DignoreList=") && a.endsWith(",client.jar")));
            Files.delete(patched);
            fails(() -> ForgeProfile.load(root.toFile()), "processor");
            file(patched, "fixture");
            profile.addProperty("inheritsFrom", "1.21.1");
            file(json, profile.toString());
            fails(() -> ForgeProfile.load(root.toFile()), "1.20.1");
            profile.addProperty("inheritsFrom", "1.20.1");
            profile.getAsJsonObject("arguments").getAsJsonArray("jvm").add("${unknown}");
            file(json, profile.toString());
            fails(() -> ForgeProfile.load(root.toFile()).jvmArguments("testcp"), "Unresolved");
            profile.getAsJsonArray("libraries").get(0).getAsJsonObject()
                    .getAsJsonObject("downloads").getAsJsonObject("artifact").addProperty("path", "../../outside.jar");
            file(json, profile.toString());
            fails(() -> ForgeProfile.load(root.toFile()), "invalid Forge library");
        } finally {
            // Files in this dedicated temporary directory only.
            try (java.util.stream.Stream<Path> paths = Files.walk(root)) {
                paths.sorted(Comparator.reverseOrder()).forEach(p -> { try { Files.delete(p); } catch (IOException e) { throw new UncheckedIOException(e); } });
            }
        }
        Path mods = Files.createTempDirectory("forge-mods-test-");
        try {
            fails(() -> ForgeMods.validate(mods.toFile()), "exactly one");
            jar(mods.resolve("visor.jar"), "META-INF/mods.toml", "[[mods]]\nmodId = \"visor\"\nversion = \"0.5.0\"\n");
            ForgeMods.validate(mods.toFile()); checks++;
            jar(mods.resolve("addon.jar"), "META-INF/mods.toml", "[[mods]]\nmodId='addon'\n[[dependencies.addon]]\nmodId='visor'\n[[dependencies.addon]]\nmodId='vivecraft'\n");
            ForgeMods.validate(mods.toFile()); checks++;
            jar(mods.resolve("another.jar"), "META-INF/mods.toml", "[[mods]]\nmodId='visor'\n");
            fails(() -> ForgeMods.validate(mods.toFile()), "found 2");
            Files.delete(mods.resolve("another.jar"));
            jar(mods.resolve("renamed.jar"), "META-INF/mods.toml", "[[mods]]\nmodId='vivecraft'\n");
            fails(() -> ForgeMods.validate(mods.toFile()), "Vivecraft");
            Files.delete(mods.resolve("renamed.jar"));
            jar(mods.resolve("fabric-only.jar"), "fabric.mod.json", "{}");
            fails(() -> ForgeMods.validate(mods.toFile()), "Fabric-only");
            check(ForgeMods.isVivecraft("https://example.com/Vivecraft.jar"));
        } finally {
            try (java.util.stream.Stream<Path> paths = Files.walk(mods)) {
                paths.sorted(Comparator.reverseOrder()).forEach(p -> { try { Files.delete(p); } catch (IOException e) { throw new UncheckedIOException(e); } });
            }
        }
        System.out.println("Passed " + checks + " Forge parser/mod preflight checks");
    }
    interface Action { void run() throws Exception; }
    static void fails(Action action, String part) throws Exception {
        try { action.run(); } catch (IOException e) { check(e.getMessage().contains(part)); return; }
        throw new AssertionError("Expected failure containing: " + part);
    }
    static void check(boolean condition) { if (!condition) throw new AssertionError(); checks++; }
    static void file(Path path, String text) throws IOException {
        Files.createDirectories(path.getParent()); Files.write(path, text.getBytes(StandardCharsets.UTF_8));
    }
    static void jar(Path path, String name, String text) throws IOException {
        try (JarOutputStream jar = new JarOutputStream(Files.newOutputStream(path))) {
            jar.putNextEntry(new JarEntry(name)); jar.write(text.getBytes(StandardCharsets.UTF_8)); jar.closeEntry();
        }
    }
}

