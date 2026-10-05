import java.io.IOException;
import java.lang.module.*;
import java.net.URI;
import java.util.*;
import java.util.jar.JarFile;

/** Resolve automatic modules using the real JAR package sets, as Forge exports mod packages. */
public class BridgeModuleTest {
    static ModuleReference module(String name, Set<String> packages) {
        return new ModuleReference(ModuleDescriptor.newAutomaticModule(name).packages(packages).build(), URI.create("test:/" + name)) {
            public ModuleReader open() throws IOException { throw new IOException("Resolution test does not load classes"); }
        };
    }
    static Set<String> packages(String jarPath) throws IOException {
        Set<String> result = new HashSet<>();
        try (JarFile jar = new JarFile(jarPath)) {
            jar.stream().map(e -> e.getName()).filter(n -> n.endsWith(".class") && !n.startsWith("META-INF/") && n.contains("/"))
                .forEach(n -> result.add(n.substring(0, n.lastIndexOf('/')).replace('/', '.')));
        }
        return result;
    }
    public static void main(String[] args) throws Exception {
        Map<String, ModuleReference> modules = Map.of(
            "visor", module("visor", packages(args[0])),
            "visor_android_bridge", module("visor_android_bridge", packages(args[1])),
            "minecraft", module("minecraft", Set.of("net.minecraft")));
        ModuleFinder finder = new ModuleFinder() {
            public Optional<ModuleReference> find(String name) { return Optional.ofNullable(modules.get(name)); }
            public Set<ModuleReference> findAll() { return Set.copyOf(modules.values()); }
        };
        boolean expectConflict = args.length > 2 && args[2].equals("expect-conflict");
        try {
            ModuleLayer.boot().configuration().resolveAndBind(finder, ModuleFinder.of(), modules.keySet());
            if (expectConflict) throw new AssertionError("Old companion must reproduce split-package failure");
            System.out.println("PASS module resolution with disjoint Visor/bridge packages");
        } catch (ResolutionException error) {
            if (!expectConflict || !error.getMessage().contains("org.vmstudio.visor.core.client.provider.openxr")) throw error;
            System.out.println("PASS negative control: old companion reproduces reported split-package failure");
        }
    }
}
